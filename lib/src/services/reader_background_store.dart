import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Import background art without retaining an external content-provider URI.
class ReaderBackgroundStore {
  ReaderBackgroundStore._();
  static final ReaderBackgroundStore instance = ReaderBackgroundStore._();
  static const _maxBytes = 8 * 1024 * 1024;

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(root.path + Platform.pathSeparator + 'reader_backgrounds');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> importFromPicker() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (selection == null || selection.files.isEmpty) return null;
    final picked = selection.files.first;
    if (picked.size <= 0 || picked.size > _maxBytes) {
      throw const FormatException('背景图片不得超过 8MB');
    }
    final bytes = picked.bytes;
    if (bytes == null || bytes.length < 12 || bytes.length > _maxBytes) {
      throw const FormatException('无法读取背景图片');
    }
    final png = bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final webp = String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!png && !jpeg && !webp) {
      throw const FormatException('仅支持有效的 JPG、PNG 或 WebP 文件');
    }
    final dir = await _directory();
    // A new import never mutates an older saved theme, even if repeated.
    final file = File(dir.path + Platform.pathSeparator +
        DateTime.now().microsecondsSinceEpoch.toString() +
        (png ? '.png' : jpeg ? '.jpg' : '.webp'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<bool> isAppOwned(String path) async {
    if (path.isEmpty) return false;
    final root = await _directory();
    final prefix = root.absolute.path + Platform.pathSeparator;
    final file = File(path);
    return file.absolute.path.startsWith(prefix) &&
        await file.exists() &&
        await file.length() <= _maxBytes;
  }
}
