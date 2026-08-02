import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<FileSystemEntity> sauvegardes = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final s = context.read<AppState>();
    final l = await s.store.backups();
    if (mounted) setState(() => sauvegardes = l);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et restauration')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        SectionCard(titre: 'Sauvegarde complete', icone: Icons.backup, children: [
          const Text(
              'Exporte toutes les donnees de l\'ecole dans un fichier JSON unique '
              '(eleves, notes, presences, bulletins, parametres, archives).',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt),
            label: const Text('Exporter la sauvegarde'),
            onPressed: () async {
              final paquet = SyncService.exporterEcole(s);
              final nom = 'SAUVEGARDE_ECOLE_${s.annee}_${DateTime.now().toIso8601String().substring(0, 10)}.json';
              final f = await s.store.writeExportString(
                  nom, const JsonEncoder.withIndent('  ').convert(paquet));
              if (!context.mounted) return;
              await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: nom));
              if (context.mounted) showOk(context, 'Sauvegarde creee : $nom');
            },
          ),
        ]),
        SectionCard(titre: 'Restauration', icone: Icons.restore, children: [
          const Text('Restaurez toutes les donnees a partir d\'un fichier de sauvegarde JSON.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Restaurer depuis un fichier'),
            onPressed: () async {
              final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
              if (res == null || res.files.single.path == null) return;
              if (!context.mounted) return;
              if (!await confirmer(context, 'Restaurer',
                  'Toutes les donnees actuelles seront remplacees (une sauvegarde automatique sera creee).')) {
                return;
              }
              try {
                final map = Map<String, dynamic>.from(
                    jsonDecode(await File(res.files.single.path!).readAsString()));
                final msg = await SyncService.restaurerEcole(s, map);
                if (context.mounted) showOk(context, msg);
                _charger();
              } catch (e) {
                if (context.mounted) showError(context, 'Erreur : $e');
              }
            },
          ),
        ]),
        SectionCard(titre: 'Sauvegardes automatiques locales', icone: Icons.history, children: [
          if (sauvegardes.isEmpty) const Text('Aucune sauvegarde automatique.'),
          ...sauvegardes.map((f) => ListTile(
                dense: true,
                leading: const Icon(Icons.insert_drive_file, color: WA.green),
                title: Text(f.path.split(Platform.pathSeparator).last,
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.restore, color: WA.teal),
                  onPressed: () async {
                    if (!await confirmer(context, 'Restaurer', 'Restaurer cette sauvegarde ?')) return;
                    final map = Map<String, dynamic>.from(
                        jsonDecode(await File(f.path).readAsString()));
                    await s.remplacerParJson(map);
                    if (context.mounted) showOk(context, 'Restauration effectuee.');
                  },
                ),
              )),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Creer une sauvegarde maintenant'),
            onPressed: () async {
              await s.save(backup: true, tag: 'manuelle');
              _charger();
              if (context.mounted) showOk(context, 'Sauvegarde locale creee.');
            },
          ),
        ]),
      ]),
    );
  }
}
