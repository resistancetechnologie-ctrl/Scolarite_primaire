import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Stockage local 100% offline : un fichier JSON principal + sauvegardes
/// automatiques horodatees dans le repertoire prive de l'application.
class LocalStore {
  static const fileName = 'ecole_data.json';
  static const backupDir = 'sauvegardes';

  Future<Directory> _dir() async => await getApplicationDocumentsDirectory();

  Future<File> _file() async => File('${(await _dir()).path}/$fileName');

  Future<Map<String, dynamic>?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      if (txt.trim().isEmpty) return null;
      return jsonDecode(txt) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(data), flush: true);
  }

  /// Sauvegarde automatique avant operation importante.
  Future<String> backup(Map<String, dynamic> data, {String tag = 'auto'}) async {
    final d = Directory('${(await _dir()).path}/$backupDir');
    if (!await d.exists()) await d.create(recursive: true);
    final ts = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final f = File('${d.path}/backup_${tag}_$ts.json');
    await f.writeAsString(jsonEncode(data), flush: true);
    await _rotate(d);
    return f.path;
  }

  Future<void> _rotate(Directory d, {int keep = 20}) async {
    final files = (await d.list().toList()).whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (var i = keep; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  Future<List<FileSystemEntity>> backups() async {
    final d = Directory('${(await _dir()).path}/$backupDir');
    if (!await d.exists()) return [];
    final l = (await d.list().toList())..sort((a, b) => b.path.compareTo(a.path));
    return l;
  }

  /// Ecrit un fichier exportable (JSON / PDF) dans le dossier documents.
  Future<File> writeExport(String name, List<int> bytes) async {
    final d = Directory('${(await _dir()).path}/exports');
    if (!await d.exists()) await d.create(recursive: true);
    final f = File('${d.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<File> writeExportString(String name, String content) =>
      writeExport(name, utf8.encode(content));
}
