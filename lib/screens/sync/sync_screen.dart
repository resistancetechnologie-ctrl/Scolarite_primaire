import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Synchronisation par fichiers JSON (100% hors ligne).
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  String periode = Periodes.MENSUELLE_DEFAULT;
  bool photos = true;
  String journalTexte = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final classes = s.classesAccessibles;

    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation JSON')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: WA.bubble, borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.wifi_off, color: WA.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Echange de donnees sans Internet : l\'enseignant exporte un fichier JSON, '
                  'le directeur l\'importe. Chaque fichier contient un controle d\'integrite.',
                  style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        SectionCard(titre: 'Exportation', icone: Icons.upload_file, children: [
          DropdownButtonFormField<String>(
            value: periode,
            decoration: const InputDecoration(labelText: 'Periode de synchronisation', isDense: true),
            items: Periodes.all.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => periode = v!),
          ),
          SwitchListTile(
            value: photos,
            title: const Text('Inclure les photos des eleves'),
            subtitle: const Text('Fichier plus volumineux'),
            onChanged: (v) => setState(() => photos = v),
          ),
          const Divider(),
          ...classes.map((c) => ListTile(
                dense: true,
                leading: const Icon(Icons.class_, color: WA.green),
                title: Text('Exporter la classe $c'),
                subtitle: Text('${s.elevesDe(c).length} eleve(s)'),
                trailing: const Icon(Icons.download),
                onTap: () => _exporterClasse(context, s, c),
              )),
        ]),
        SectionCard(titre: 'Importation (directeur)', icone: Icons.download_for_offline, children: [
          const Text(
              'Importez un ou plusieurs fichiers JSON transmis par les enseignants. '
              'Les doublons sont detectes et les donnees fusionnees sans perte.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('Choisir des fichiers JSON'),
            onPressed: s.estDirecteur ? () => _importer(context, s) : null,
          ),
          if (!s.estDirecteur)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Reserve au directeur.', style: TextStyle(fontSize: 11, color: WA.grey)),
            ),
          if (journalTexte.isNotEmpty) ...[
            const Divider(),
            Text(journalTexte, style: const TextStyle(fontSize: 12)),
          ],
        ]),
      ]),
    );
  }

  Future<void> _exporterClasse(BuildContext context, AppState s, String classe) async {
    try {
      final paquet = SyncService.exporterClasse(s, classe, periode: periode, inclurePhotos: photos);
      final txt = const JsonEncoder.withIndent('  ').convert(paquet);
      final nom = SyncService.nomFichierClasse(classe, s.annee, periode);
      final f = await s.store.writeExportString(nom, txt);
      s.log('EXPORT_JSON', cible: classe, apres: nom);
      await s.save();
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path)],
          text: 'Donnees de la classe $classe - ${s.annee} - $periode',
        ),
      );
      if (context.mounted) showOk(context, 'Fichier genere : $nom');
    } catch (e) {
      if (context.mounted) showError(context, 'Erreur export : $e');
    }
  }

  Future<void> _importer(BuildContext context, AppState s) async {
    final res = await FilePicker.pickFiles(
        allowMultiple: true, type: FileType.custom, allowedExtensions: ['json']);
    if (res == null) return;
    final rapport = StringBuffer();
    for (final f in res.files) {
      try {
        final path = f.path;
        final contenu = path != null
            ? await File(path).readAsString()
            : utf8.decode(f.bytes ?? []);
        final map = Map<String, dynamic>.from(jsonDecode(contenu));
        final entete = Map<String, dynamic>.from(map['entete'] ?? {});
        if (entete['type'] == 'SAUVEGARDE_ECOLE') {
          rapport.writeln(await SyncService.restaurerEcole(s, map));
        } else {
          rapport.writeln(await SyncService.importerClasse(s, map));
        }
        rapport.writeln('Recu le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');
        rapport.writeln('---');
      } catch (e) {
        rapport.writeln('Echec ${f.name} : $e');
        rapport.writeln('---');
      }
    }
    setState(() => journalTexte = rapport.toString());
    if (context.mounted) showOk(context, 'Importation terminee.');
  }
}
