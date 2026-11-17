import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/diagnostics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DiagnosticsService.instance.init();
    await DiagnosticsService.instance.resetForTesting();
  });

  test('敏感信息在写入前被脱敏', () {
    final String raw = 'GET https://user:pass@example.com/books '
        'password=hunter2 token: abc123 Authorization: Bearer eyJhbGciOi '
        'contact me@example.com';
    final String safe = DiagnosticsService.redact(raw);
    expect(safe.contains('hunter2'), isFalse);
    expect(safe.contains('abc123'), isFalse);
    expect(safe.contains('eyJhbGciOi'), isFalse);
    expect(safe.contains('user:pass'), isFalse);
    expect(safe.contains('me@example.com'), isFalse);
    expect(safe.contains('<redacted>'), isTrue);
    expect(safe.contains('<email>'), isTrue);
  });

  test('记录可持久化并按上限轮转', () async {
    final DiagnosticsService diagnostics = DiagnosticsService.instance;
    for (int i = 0; i < DiagnosticsService.maxEntries + 25; i++) {
      await diagnostics.record(kind: 'sync', message: '第 $i 条');
    }
    expect(diagnostics.count, DiagnosticsService.maxEntries);
    expect(diagnostics.entries.first.message, '第 25 条');

    // 重新初始化后仍然存在（本地持久化）。
    await diagnostics.init();
    expect(diagnostics.count, DiagnosticsService.maxEntries);
    expect(diagnostics.entries.last.message,
        '第 ${DiagnosticsService.maxEntries + 24} 条');
  });

  test('关闭开关后不再记录', () async {
    final DiagnosticsService diagnostics = DiagnosticsService.instance;
    await diagnostics.setEnabled(false);
    await diagnostics.record(kind: 'sync', message: '不应出现');
    expect(diagnostics.count, 0);

    await diagnostics.setEnabled(true);
    await diagnostics.record(kind: 'sync', message: '出现');
    expect(diagnostics.count, 1);
  });

  test('导出报告包含版本、条数与脱敏后的内容', () async {
    final DiagnosticsService diagnostics = DiagnosticsService.instance;
    await diagnostics.record(
      kind: 'reader',
      message: '打开书籍失败',
      detail: 'token=abcdef 解析错误',
    );
    final String report =
        diagnostics.exportReport(appVersion: 'v2.0.0 preview');
    expect(report.contains('v2.0.0 preview'), isTrue);
    expect(report.contains('记录条数：1'), isTrue);
    expect(report.contains('打开书籍失败'), isTrue);
    expect(report.contains('abcdef'), isFalse);
    expect(report.contains('未上传'), isTrue);
  });

  test('超长消息被截断，避免日志无限膨胀', () async {
    final DiagnosticsService diagnostics = DiagnosticsService.instance;
    await diagnostics.record(kind: 'app', message: 'x' * 5000);
    final String message = diagnostics.entries.single.message;
    expect(message.length, lessThanOrEqualTo(DiagnosticsService.maxMessageLength + 1));
  });
}
