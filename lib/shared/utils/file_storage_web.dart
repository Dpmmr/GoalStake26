import 'dart:async';
import 'dart:html' as html;
import 'file_storage.dart';

class WebFileStorage implements FileStorage {
  @override
  Future<void> saveAndShareCsv(String csvContent, String filename) async {
    final bytes = Uri.encodeComponent(csvContent);
    final anchor = html.AnchorElement(href: 'data:text/csv;charset=utf-8,$bytes')
      ..setAttribute('download', '$filename.csv')
      ..click();
  }

  @override
  Future<void> writeCache(String key, String content) async {
    html.window.localStorage[key] = content;
  }

  @override
  Future<String?> readCache(String key) async {
    return html.window.localStorage[key];
  }
}

FileStorage getFileStorage() => WebFileStorage();
