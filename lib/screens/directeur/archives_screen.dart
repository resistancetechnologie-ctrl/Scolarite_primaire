import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Archivage des annees scolaires + consultation des archives.
class ArchivesScreen extends StatelessWidget {
  const ArchivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Archives des annees scolaires')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        SectionCard(titre: 'Annee en cours', icone: Icons.event, children: [
          Text(s.annee, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: WA.teal)),
          Text('${s.elevesAnnee.length} eleve(s) inscrits'),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_clock),
            label: const Text("Cloturer l'annee et archiver"),
            onPressed: () => _cloturer(context, s),
          ),
        ]),
        SectionCard(titre: 'Annees archivees', icone: Icons.inventory_2, children: [
          if (s.archives.isEmpty) const Text('Aucune archive.'),
          ...s.archives.map((a) => ListTile(
                leading: const Icon(Icons.folder, color: WA.green),
                title: Text(a.anneeScolaire),
                subtitle: Text('Cloturee le ${DateFormat('dd/MM/yyyy').format(a.dateCloture)}'),
                trailing: const Icon(Icons.visibility, color: WA.grey),
                onTap: () => _consulter(context, a),
              )),
        ]),
      ]),
    );
  }

  Future<void> _cloturer(BuildContext context, AppState s) async {
    final parts = s.annee.split('-');
    final suggestion = parts.length == 2
        ? '${int.parse(parts[0]) + 1}-${int.parse(parts[1]) + 1}'
        : Ecole.defaultAnnee();
    final ctrl = TextEditingController(text: suggestion);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cloture de l'annee"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Les donnees de l'annee en cours seront archivees. Aucune donnee n'est supprimee."),
          const SizedBox(height: 10),
          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nouvelle annee scolaire')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cloturer')),
        ],
      ),
    );
    if (ok != true) return;
    await s.cloturerAnnee(ctrl.text.trim());
    if (context.mounted) showOk(context, 'Annee archivee. Nouvelle annee : ${s.annee}');
  }

  void _consulter(BuildContext context, ArchiveAnnee a) {
    final d = a.donnees;
    final eleves = (d['eleves'] as List?)?.length ?? 0;
    final notes = (d['notes'] as List?)?.length ?? 0;
    final presences = (d['presences'] as List?)?.length ?? 0;
    final bulletins = (d['bulletins'] as List?)?.length ?? 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Archive ${a.anneeScolaire}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Eleves : $eleves'),
          Text('Notes : $notes'),
          Text('Presences : $presences'),
          Text('Bulletins : $bulletins'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
