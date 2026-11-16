import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/diagnostics_service.dart';

void main() {
  group('diagnostic upload safety', () {
    test('accepts explicit HTTPS receiver paths only', () {
      expect(
          DiagnosticsService.validEndpoint('https://example.com/ingest'), true);
      expect(
          DiagnosticsService.validEndpoint('https://example.com:8443/logs'), true);
      expect(
          DiagnosticsService.validEndpoint('http://example.com/logs'), false);
      expect(
          DiagnosticsService.validEndpoint('https://user:pass@example.com/logs'),
          false);
      expect(
          DiagnosticsService.validEndpoint('https://example.com/logs?token=abc'),
          false);
      expect(DiagnosticsService.validEndpoint(''), false);
    });

    test('only minimal operational events are permitted', () {
      expect(DiagnosticsService.allowedEvents.contains('app_start'), true);
      expect(
          DiagnosticsService.allowedEvents.contains('sync_failed'), true);
      expect(
          DiagnosticsService.allowedEvents.contains('book_content'), false);
      expect(
          DiagnosticsService.allowedEvents.contains('api_key'), false);
    });
  });
}
