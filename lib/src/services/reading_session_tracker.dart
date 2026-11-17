/// 一次阅读会话的真实增量。
class ReadingSessionDelta {
  const ReadingSessionDelta({
    required this.seconds,
    required this.newChars,
    required this.rereadChars,
  });

  final int seconds;

  /// 第一次读到的字符数（按最远位置推进计算）。
  final int newChars;

  /// 回看/重复阅读过的字符数，不并入「阅读字数」。
  final int rereadChars;

  bool get isEmpty => seconds == 0 && newChars == 0 && rereadChars == 0;

  ReadingSessionDelta operator +(ReadingSessionDelta other) =>
      ReadingSessionDelta(
        seconds: seconds + other.seconds,
        newChars: newChars + other.newChars,
        rereadChars: rereadChars + other.rereadChars,
      );
}

/// 纯逻辑的阅读会话统计。
///
/// 修复的核心问题：以前用 `(offset - lastOffset).abs()` 累加字数，
/// 往回翻页也会被算成“读了更多字”，统计虚高。现在：
/// - 只有推进到历史最远位置之后的部分才算新阅读内容；
/// - 在已读区间内前后移动只计为重复阅读；
/// - 长时间无操作（默认 2 分钟）或应用不在前台时不累计时长。
class ReadingSessionTracker {
  ReadingSessionTracker({
    this.idleLimit = const Duration(minutes: 2),
    DateTime? now,
  }) {
    if (now != null) {
      _lastTick = now;
      _lastActivity = now;
    }
  }

  final Duration idleLimit;

  int? _lastOffset;
  int _furthest = 0;
  int _newChars = 0;
  int _rereadChars = 0;
  int _seconds = 0;
  DateTime? _lastTick;
  DateTime? _lastActivity;

  int get furthestOffset => _furthest;
  int? get lastOffset => _lastOffset;

  /// 用户有任何交互（翻页、点击、滚动）时调用。
  void markActivity([DateTime? at]) {
    final DateTime now = at ?? DateTime.now();
    _lastActivity = now;
    // 从交互这一刻开始计时，避免把空闲期尾巴算进阅读时长。
    _lastTick = now;
  }

  /// 记录一个新的绝对字符位置。
  void recordPosition(int offset, {DateTime? at}) {
    if (offset < 0) return;
    markActivity(at);
    final int? last = _lastOffset;
    if (last == null) {
      _lastOffset = offset;
      _furthest = offset;
      return;
    }
    if (offset > last) {
      final int oldFurthest = _furthest;
      if (offset > oldFurthest) {
        // 只有越过历史最远位置的部分才是真正的新内容。
        final int start = last > oldFurthest ? last : oldFurthest;
        if (offset > start) _newChars += offset - start;
        _furthest = offset;
      }
      if (last < oldFurthest) {
        final int end = offset < oldFurthest ? offset : oldFurthest;
        final int overlap = end - last;
        if (overlap > 0) _rereadChars += overlap;
      }
    } else if (offset < last) {
      _rereadChars += last - offset;
    }
    _lastOffset = offset;
  }

  /// 目录跳转、进度条跳转、恢复历史位置：重置基线，不把跳过量算成阅读。
  void jumpTo(int offset, {DateTime? at}) {
    if (offset < 0) return;
    markActivity(at);
    _lastOffset = offset;
    if (offset > _furthest) _furthest = offset;
  }

  /// 定时器驱动。active=false（后台/菜单全屏遮挡）时不累计时长。
  void tick({required bool active, DateTime? at}) {
    final DateTime now = at ?? DateTime.now();
    final DateTime? last = _lastTick;
    _lastTick = now;
    if (!active || last == null) return;
    final DateTime? activity = _lastActivity;
    if (activity == null || now.difference(activity) > idleLimit) return;
    final Duration delta = now.difference(last);
    if (delta <= Duration.zero) return;
    // 系统休眠/时钟跳变会产生异常大的间隔，超过 1 分钟视为无效。
    if (delta > const Duration(minutes: 1)) return;
    _seconds += delta.inSeconds;
  }

  /// 取出并清空累计值（位置基线保留，用于下次继续计算增量）。
  ReadingSessionDelta drain() {
    final ReadingSessionDelta delta = ReadingSessionDelta(
      seconds: _seconds,
      newChars: _newChars,
      rereadChars: _rereadChars,
    );
    _seconds = 0;
    _newChars = 0;
    _rereadChars = 0;
    return delta;
  }

  void reset() {
    _lastOffset = null;
    _furthest = 0;
    _newChars = 0;
    _rereadChars = 0;
    _seconds = 0;
    _lastTick = null;
    _lastActivity = null;
  }
}
