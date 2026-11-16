import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/sync_failure.dart';

void main() {
  test('同步失败分类覆盖认证、限流、损坏与网络', () {
    expect(SyncFailure.classify('401 Unauthorized', operation: '上传').kind,
        SyncFailureKind.auth);
    expect(SyncFailure.classify('429 Too Many Requests', operation: '上传').kind,
        SyncFailureKind.rateLimit);
    expect(SyncFailure.classify('云端文件哈希不匹配', operation: '下载').kind,
        SyncFailureKind.corrupt);
    expect(SyncFailure.classify('SocketException: network unreachable', operation: '同步').kind,
        SyncFailureKind.network);
    final failure = SyncFailure.classify('timeout', operation: '同步', object: '《书》');
    expect(failure.summary, contains('网络超时'));
    expect(failure.suggestion.isNotEmpty, isTrue);
  });
}
