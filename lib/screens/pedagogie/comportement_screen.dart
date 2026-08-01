import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ComportementScreen extends StatelessWidget {
  final String classe;
  const ComportementScreen({super.key, required this.classe});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eleves = s.elevesDe(classe);

    return Scaffold(
      appBar: AppBar(title: Text('Carnet de comportement - $classe')),
      body: eleves.isEmpty
          ? const EmptyState(message: 'Aucun eleve.')
          : ListView.builder(
              itemCount: eleves.length,
              itemBuilder: (_, i) {
                final e = eleves[i];
                final obs = s.comportements.where((c) => c.eleveId == e.id).toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                return Card(
                  child: ExpansionTile(
                    leading: imageBase64(e.photoBase64, size: 40),
                    title: Text(e.nomComplet),
                    subtitle: Text('${obs.length} observation(s)'),
                    children: [
                      ...obs.map((c) => ListTile(
                            dense: true,
                            leading: Icon(
                                c.type == 'Sanction'
                                    ? Icons.report
                                    : (c.type == 'Encouragement' ? Icons.star : Icons.note_alt),
                                color: c.type == 'Sanction' ? WA.danger : WA.green),
                            title: Text(c.description),
                            subtitle: Text(
                                '${DateFormat('dd/MM/yyyy').format(c.date)} - Discipline ${c.discipline}/10, Participation ${c.participation}/10'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: WA.danger),
                              onPressed: () async {
                                s.comportements.remove(c);
                                await s.save();
                              },
                            ),
                          )),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une observation'),
                        onPressed: () => _ajouter(context, s, e),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _ajouter(BuildContext context, AppState s, Eleve e) async {
    var type = 'Observation';
    var disc = 8.0, part = 8.0;
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(e.nomComplet),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type', isDense: true),
              items: const [
                DropdownMenuItem(value: 'Observation', child: Text('Observation')),
                DropdownMenuItem(value: 'Encouragement', child: Text('Encouragement')),
                DropdownMenuItem(value: 'Sanction', child: Text('Sanction')),
              ],
              onChanged: (v) => setSt(() => type = v!),
            ),
            const SizedBox(height: 8),
            TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            Text('Discipline : ${disc.round()}/10'),
            Slider(value: disc, min: 0, max: 10, divisions: 10, onChanged: (v) => setSt(() => disc = v)),
            Text('Participation : ${part.round()}/10'),
            Slider(value: part, min: 0, max: 10, divisions: 10, onChanged: (v) => setSt(() => part = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    s.comportements.add(Comportement(
      eleveId: e.id, type: type, description: desc.text.trim(),
      discipline: disc.round(), participation: part.round(), anneeScolaire: s.annee,
    ));
    s.log('COMPORTEMENT', cible: e.nomComplet, apres: type);
    await s.save();
  }
}
