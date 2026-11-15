import 'dart:typed_data';

class RemoteSnapshot {
  const RemoteSnapshot({required this.bytes, required this.etag});
  final Uint8List bytes;
  final String? etag;
}

class RemoteEntry {
  const RemoteEntry({
    required this.key,
    required this.size,
    required this.modifiedAt,
    this.etag,
  });
  final String key;
  final int size;
  final DateTime? modifiedAt;
  final String? etag;
}

class RemoteStoreException implements Exception {
  const RemoteStoreException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class RemoteConflictException extends RemoteStoreException {
  const RemoteConflictException(super.message) : super(statusCode: 412);
}

class RemoteAuthException extends RemoteStoreException {
  const RemoteAuthException(super.message) : super(statusCode: 401);
}

/// Small storage abstraction shared by WebDAV and S3-compatible providers.
abstract class RemoteObjectStore {
  String get displayName;
  Future<void> testConnection();
  Future<RemoteSnapshot?> read(String key);
  Future<String?> write(Uint8List bytes, String key, {String? expectedEtag});
  Future<void> delete(String key);
  Future<List<RemoteEntry>> list({String prefix = '', int max = 200});
}

