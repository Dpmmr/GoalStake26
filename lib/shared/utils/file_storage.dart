import 'file_storage_stub.dart'
    if (dart.library.io) 'file_storage_mobile.dart'
    if (dart.library.html) 'file_storage_web.dart';

abstract class FileStorage {
  factory FileStorage() => getFileStorage();

  Future<void> saveAndShareCsv(String csvContent, String filename);
  Future<void> writeCache(String key, String content);
  Future<String?> readCache(String key);
}
