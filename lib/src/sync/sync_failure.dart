enum SyncFailureKind {
  auth,
  timeout,
  rateLimit,
  storageFull,
  conflict,
  corrupt,
  network,
  cancelled,
  unknown,
}

/// Converts low-level sync errors into an auditable failure record with a
/// stable type and an actionable next step. Never includes secrets.
class SyncFailure {
  const SyncFailure({
    required this.kind,
    required this.operation,
    required this.object,
    required this.message,
    required this.suggestion,
    required this.occurredAt,
  });

  final SyncFailureKind kind;
  final String operation;
  final String object;
  final String message;
  final String suggestion;
  final DateTime occurredAt;

  String get label => switch (kind) {
        SyncFailureKind.auth => '认证失败',
        SyncFailureKind.timeout => '网络超时',
        SyncFailureKind.rateLimit => '服务器限流',
        SyncFailureKind.storageFull => '存储不足',
        SyncFailureKind.conflict => '数据冲突',
        SyncFailureKind.corrupt => '文件或数据损坏',
        SyncFailureKind.network => '网络不可用',
        SyncFailureKind.cancelled => '用户取消',
        SyncFailureKind.unknown => '未知错误',
      };

  String get summary =>
      '$label · $operation · $object · ${occurredAt.toIso8601String()} · $message';

  static SyncFailure classify(
    Object error, {
    required String operation,
    String object = '同步任务',
    DateTime? now,
  }) {
    final text = '$error';
    final lower = text.toLowerCase();
    SyncFailureKind kind;
    String suggestion;
    if (lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('认证') ||
        lower.contains('密码错误') ||
        lower.contains('forbidden')) {
      kind = SyncFailureKind.auth;
      suggestion = '检查账号、应用密码或同步密码后重新保存凭据';
    } else if (lower.contains('429') || lower.contains('rate limit')) {
      kind = SyncFailureKind.rateLimit;
      suggestion = '等待服务器限流窗口结束，稍后使用手动重试';
    } else if (lower.contains('timeout') || lower.contains('timed out')) {
      kind = SyncFailureKind.timeout;
      suggestion = '检查网络与服务器地址，恢复网络后从队列继续';
    } else if (lower.contains('空间') ||
        lower.contains('storage') ||
        lower.contains('quota') ||
        lower.contains('507')) {
      kind = SyncFailureKind.storageFull;
      suggestion = '清理云端空间或降低同步文件范围后重试';
    } else if (lower.contains('412') ||
        lower.contains('409') ||
        lower.contains('conflict') ||
        lower.contains('冲突')) {
      kind = SyncFailureKind.conflict;
      suggestion = '重新读取云端最新版本并合并，避免覆盖他人修改';
    } else if (lower.contains('sha-256') ||
        lower.contains('哈希') ||
        lower.contains('篡改') ||
        lower.contains('损坏') ||
        lower.contains('format')) {
      kind = SyncFailureKind.corrupt;
      suggestion = '拒绝导入损坏数据，保留本机副本并重新上传';
    } else if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('网络')) {
      kind = SyncFailureKind.network;
      suggestion = '联网后自动重试；仅 Wi-Fi 限制下不会消耗移动流量';
    } else if (lower.contains('cancel')) {
      kind = SyncFailureKind.cancelled;
      suggestion = '未写入任何一方，可稍后手动继续';
    } else {
      kind = SyncFailureKind.unknown;
      suggestion = '保留任务，查看同步历史并在恢复后手动重试';
    }
    return SyncFailure(
      kind: kind,
      operation: operation,
      object: object,
      message: text.length > 300 ? text.substring(0, 300) : text,
      suggestion: suggestion,
      occurredAt: now ?? DateTime.now(),
    );
  }
}
