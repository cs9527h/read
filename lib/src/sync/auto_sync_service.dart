import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../model/book.dart';
import '../services/library_store.dart';
import 'metadata_sync_service.dart';
import 'progress_conflict_store.dart';
import 'progress_sync_service.dart';
import 'sync_failure.dart';
import 'remote_store.dart';
import 'sync_config.dart';
import 'progress_history.dart';
import 'progress_models.dart';
import 'sync_history.dart';
import 'webdav_store.dart';

/// Coordinates automatic, debounced and lifecycle-driven sync. It never
/// prompts by itself and never overwrites a conflict silently: automatic runs
/// use the configured policy and the conflict remains visible in history.
class AutoSyncService extends ChangeNotifier with WidgetsBindingObserver {
  AutoSyncService._();
  static final AutoSyncService instance = AutoSyncService._();

  SyncConfig get config => SyncConfig.instance;
  LibraryStore get library => LibraryStore.instance;

  Book? _currentBook;
  Timer? _progressTimer;
  Timer? _metadataTimer;
  Timer? _intervalTimer;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _progressRunning = false;
  bool _metadataRunning = false;
  bool _initialized = false;
  bool _foreground = true;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    await SyncHistoryStore.instance.init();
    await SyncTaskQueue.instance.init();
    await ProgressHistoryStore.instance.init();
    await ProgressConflictStore.instance.init();
    library.addListener(_onLibraryChanged);
    _connectivity = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (config.syncOnNetwork && _networkAllowed(results)) {
          scheduleMetadata(immediate: true);
        }
      },
    );
    _retryTimer = Timer.periodic(const Duration(seconds: 20), (_) => _drainQueue());
    _restartInterval();
    if (config.syncOnStart) {
      scheduleMetadata(immediate: true);
    }
    notifyListeners();
  }

  bool _networkAllowed([List<ConnectivityResult>? results]) {
    if (!config.wifiOnly) return true;
    if (results == null) return true; // resolved again at request time
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  Future<bool> _canRunNetwork() async {
    if (!config.configured) return false;
    if (!config.wifiOnly) return true;
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  /// Progress is a tiny channel and may run on mobile data when the user
  /// allowed it; large book files still obey [wifiOnly].
  Future<bool> _canRunProgressNetwork() async {
    if (!config.configured) return false;
    if (config.progressOnMobile) return true;
    return _canRunNetwork();
  }

  void _restartInterval() {
    _intervalTimer?.cancel();
    if (config.intervalMinutes <= 0) return;
    final minutes = config.intervalMinutes.clamp(1, 24 * 60);
    _intervalTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      if (config.fullAuto) scheduleMetadata(immediate: true);
      if (config.progressAuto && _currentBook != null) scheduleProgress(_currentBook!);
    });
  }

  Future<void> applyConfigChanged() async {
    _restartInterval();
    if (config.syncOnStart) scheduleMetadata(immediate: true);
    notifyListeners();
  }

  void _onLibraryChanged() {
    if (config.fullAuto && _foreground) {
      scheduleMetadata();
    }
  }

  Future<ProgressSyncReport?> onBookOpened(Book book) async {
    _currentBook = book;
    ProgressSyncReport? report;
    if (config.progressAuto && config.syncOnBookOpen) {
      report = await runProgress(book, silent: true);
    }
    if (config.fullAuto && config.syncOnBookOpen) {
      scheduleMetadata(immediate: true);
    }
    return report;
  }

  /// Debounced quick channel: page turns schedule one progress upload after
  /// the user pauses, not one request per page.
  void scheduleProgress(Book book, {Duration? delay}) {
    _currentBook = book;
    if (!config.progressAuto) return;
    _progressTimer?.cancel();
    _progressTimer = Timer(
      delay ?? Duration(seconds: config.progressDebounceSeconds.clamp(1, 120)),
      () => unawaited(runProgress(book, silent: true)),
    );
  }

  void scheduleMetadata({bool immediate = false}) {
    if (!config.fullAuto) return;
    _metadataTimer?.cancel();
    _metadataTimer = Timer(
      immediate
          ? Duration.zero
          : Duration(minutes: config.fullDebounceMinutes.clamp(1, 120)),
      () => unawaited(runFull(silent: true)),
    );
  }

  void onBookClosed() {
    // Drop the debounce timer first: leaving the reader must not fire a
    // progress upload later against a disposed page.
    _progressTimer?.cancel();
    final book = _currentBook;
    if (book != null && config.progressAuto && config.syncOnBookClose) {
      unawaited(runProgress(book, silent: true));
    }
    _currentBook = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (wasForeground && !_foreground) {
      if (config.syncOnBookClose && _currentBook != null) {
        unawaited(runProgress(_currentBook!, silent: true));
      }
      if (config.fullAuto) scheduleMetadata(immediate: true);
    } else if (!wasForeground && _foreground) {
      if (config.syncOnStart) scheduleMetadata(immediate: true);
    }
  }

  Future<ProgressSyncReport?> runProgress(
    Book book, {
    bool silent = false,
    ProgressConflictResolver? resolver,
    bool enqueueOnFailure = false,
  }) async {
    if (_progressRunning) return null;
    if (!await _canRunProgressNetwork()) {
      if (!silent) throw const RemoteStoreException('当前不满足自动同步网络条件或未配置云端');
      return null;
    }
    _progressRunning = true;
    notifyListeners();
    final targetId = SyncBackendFactory.targetId(config);
    var bookHash = book.contentHash ?? '';
    try {
      bookHash = await library.ensureContentHash(book);
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(config, secrets);
      await _prepare(store);
      final service = ProgressSyncService(library);
      final report = await service.syncStore(
        store,
        secrets.encryptionPassword,
        targetId: targetId,
        onlyBook: book,
        resolveConflict: resolver ?? _policyResolver,
        continueOnUnresolved: resolver == null && config.conflictPolicy == 'ask',
      );
      if (resolver != null && report.conflicts > 0) {
        await ProgressConflictStore.instance.remove(
          '$targetId|${await library.ensureContentHash(book)}',
        );
      }
      await config.markProgress('阅读进度同步完成');
      await SyncHistoryStore.instance.add(SyncHistoryEntry(
        at: DateTime.now(),
        kind: 'progress',
        status: report.conflicts > 0 ? 'conflict' : 'success',
        message:
            '《${book.title}》本机 ${report.uploaded} 条，云端 ${report.downloaded} 条',
        uploaded: report.uploaded,
        downloaded: report.downloaded,
        conflicts: report.conflicts,
      ));
      return report;
    } catch (error) {
      final failure = SyncFailure.classify(
        error,
        operation: '同步阅读进度',
        object: '《${book.title}》',
      );
      await SyncHistoryStore.instance.add(SyncHistoryEntry(
        at: failure.occurredAt,
        kind: 'progress',
        status: 'failed',
        message: failure.message,
        errorType: failure.label,
        suggestion: failure.suggestion,
      ));
      await config.markProgress('阅读进度同步失败', error: failure.message);
      if (!silent) rethrow;
      if (enqueueOnFailure) {
        await SyncTaskQueue.instance.enqueue(
          'progress',
          bookHash: bookHash,
          targetId: targetId,
        );
      }
      return null;
    } finally {
      _progressRunning = false;
      notifyListeners();
    }
  }

  Future<MetadataSyncReport?> runFull({
    bool silent = false,
    bool downloadMissing = false,
    bool enqueueOnFailure = false,
  }) async {
    if (_metadataRunning) return null;
    if (!await _canRunNetwork()) {
      if (!silent) throw const RemoteStoreException('当前不满足自动同步网络条件或未配置云端');
      return null;
    }
    _metadataRunning = true;
    notifyListeners();
    try {
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(config, secrets);
      await _prepare(store);
      final report = await MetadataSyncService().sync(
        store: store,
        encryptionPassword: secrets.encryptionPassword,
        includeBookmarks: config.syncBookmarks,
        includeSettings: config.syncReaderSettings,
        includeStats: config.syncStats,
        includeBooks: config.syncBooks,
        includeFiles: config.syncFiles,
        downloadMissingFiles: downloadMissing,
        targetId: SyncBackendFactory.targetId(config),
        encryptFiles: config.encryptFiles,
        allowLegacyPlainFiles: config.allowLegacyPlainFiles,
      );
      await config.markSync(
        report.status == 'conflict' ? '同步完成（有冲突）' : '同步完成',
      );
      return report;
    } catch (error) {
      final failure = SyncFailure.classify(
        error,
        operation: '全量同步',
        object: '书架与云端目标',
      );
      await SyncHistoryStore.instance.add(SyncHistoryEntry(
        at: failure.occurredAt,
        kind: 'full',
        status: 'failed',
        message: failure.message,
        errorType: failure.label,
        suggestion: failure.suggestion,
      ));
      await config.markSync('同步失败', error: failure.message);
      if (!silent) rethrow;
      if (enqueueOnFailure) await SyncTaskQueue.instance.enqueue('full');
      return null;
    } finally {
      _metadataRunning = false;
      notifyListeners();
    }
  }

  Future<void> testConnection() async {
    final secrets = await SyncSecrets.load();
    final store = SyncBackendFactory.create(config, secrets);
    await _prepare(store);
    await store.testConnection();
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: DateTime.now(),
      kind: 'test',
      status: 'success',
      message: '${store.displayName} 连接正常',
    ));
  }

  Future<void> _prepare(RemoteObjectStore store) async {
    if (store is WebDavStore) await store.ensureDirectory();
  }

  Future<ProgressChoice?> _policyResolver(ProgressSyncConflict conflict) async {
    if (config.conflictPolicy == 'ask') {
      // Ask never silently picks a side: keep both records, stop writing this
      // book, and surface a durable pending conflict for the user.
      await ProgressConflictStore.instance.put(PendingProgressConflict(
        targetId: SyncBackendFactory.targetId(config),
        bookHash: conflict.local.hash,
        title: conflict.title,
        local: conflict.local,
        remote: conflict.remote,
        createdAt: DateTime.now(),
      ));
      await SyncHistoryStore.instance.add(SyncHistoryEntry(
        at: DateTime.now(),
        kind: 'progress',
        status: 'conflict',
        message: '《${conflict.title}》已保留为待解决冲突，未自动覆盖任何一方',
        conflicts: 1,
      ));
      return null;
    }
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: DateTime.now(),
      kind: 'progress',
      status: 'conflict',
      message: '《${conflict.title}》自动策略：${config.conflictPolicy}',
      conflicts: 1,
    ));
    return config.conflictPolicy == 'cloud'
        ? ProgressChoice.cloud
        : ProgressChoice.local;
  }

  Future<void> _drainQueue() async {
    if (!_foreground) return;
    final task = SyncTaskQueue.instance.nextDue(DateTime.now());
    if (task == null) return;
    try {
      if (task.kind == 'progress') {
        final currentTarget = SyncBackendFactory.targetId(config);
        if (task.targetId.isNotEmpty && task.targetId != currentTarget) {
          throw StateError('队列任务绑定的云端目标已变化，已暂停以避免写入错误位置');
        }
        final Book? book = task.bookHash.isNotEmpty
            ? library.bookByHash(task.bookHash)
            : _currentBook;
        if (book == null) {
          throw StateError(task.bookHash.isEmpty
              ? '旧版进度任务缺少书籍绑定，请打开目标书籍后重新同步'
              : '队列任务绑定的书籍不在本机，已保留任务等待恢复');
        }
        final report = await runProgress(book, silent: true);
        if (report == null) {
          throw StateError(config.lastError.isEmpty ? '进度同步未完成' : config.lastError);
        }
      } else {
        final report = await runFull(silent: true);
        if (report == null) {
          throw StateError(config.lastError.isEmpty ? '完整同步未完成' : config.lastError);
        }
      }
      await SyncTaskQueue.instance.complete(task);
    } catch (error) {
      await SyncTaskQueue.instance.fail(task, '$error');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _metadataTimer?.cancel();
    _intervalTimer?.cancel();
    _retryTimer?.cancel();
    _connectivity?.cancel();
    library.removeListener(_onLibraryChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
