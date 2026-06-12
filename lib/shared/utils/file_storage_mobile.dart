import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'file_storage.dart';

class MobileFileStorage implements FileStorage {
  @override
  Future<void> saveAndShareCsv(String csvContent, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename.csv');
    await file.writeAsString(csvContent);
    await Share.shareXFiles([XFile(file.path)], text: '$filename.csv');
  }

  @override
  Future<void> writeCache(String key, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$key');
    await file.writeAsString(content);
  }

  @override
  Future<String?> readCache(String key) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$key');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }
}

FileStorage getFileStorage() => MobileFileStorage();
