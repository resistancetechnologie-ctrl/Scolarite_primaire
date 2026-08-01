import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  static const types = ['Reunion', 'Decision', 'Evenement', 'Inspection', 'Observation'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.journal.toList()..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Journal de bord du directeur')),
      body: l.isEmpty
          ? const EmptyState(message: 'Aucune note.', icone: Icons.edit_note)
          : ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) => Card(
                child: ListTile(
                  leading: const Icon(Icons.sticky_note_2, color: WA.green),
                  title: Text(l[i].titre),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(l[i].date)} - ${l[i].type}\n${l[i].contenu}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: WA.danger),
                    onPressed: () async {
                      s.journal.remove(l[i]);
                      await s.save();
                    },
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ajouter(context, s),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _ajouter(BuildContext context, AppState s) async {
    var type = types.first;
    final titre = TextEditingController();
    final contenu = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nouvelle note'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type', isDense: true),
              items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setSt(() => type = v!),
            ),
            const SizedBox(height: 8),
            TextField(controller: titre, decoration: const InputDecoration(labelText: 'Titre')),
            const SizedBox(height: 8),
            TextField(controller: contenu, maxLines: 4, decoration: const InputDecoration(labelText: 'Contenu')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    s.journal.add(JournalEntry(type: type, titre: titre.text.trim(), contenu: contenu.text.trim()));
    await s.save();
  }
}
