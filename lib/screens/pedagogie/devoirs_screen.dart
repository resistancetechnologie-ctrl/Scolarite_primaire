import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DevoirsScreen extends StatelessWidget {
  final String classe;
  const DevoirsScreen({super.key, required this.classe});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.devoirs.where((d) => d.classe == classe && d.anneeScolaire == s.annee).toList()
      ..sort((a, b) => b.dateDonne.compareTo(a.dateDonne));
    final eleves = s.elevesDe(classe);

    return Scaffold(
      appBar: AppBar(title: Text('Devoirs - $classe')),
      body: l.isEmpty
          ? const EmptyState(message: 'Aucun devoir enregistre.', icone: Icons.assignment)
          : ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) {
                final d = l[i];
                final remis = d.notes.values.where((v) => v != null).length;
                final moy = remis == 0
                    ? 0.0
                    : d.notes.values.whereType<double>().reduce((a, b) => a + b) / remis;
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.assignment, color: WA.green),
                    title: Text('${d.titre} (${d.matiere})'),
                    subtitle: Text(
                        'Donne le ${DateFormat('dd/MM').format(d.dateDonne)} - remise le ${DateFormat('dd/MM').format(d.dateRemise)}\n'
                        'Remis : $remis/${eleves.length} - Moyenne : ${moy.toStringAsFixed(2)}'),
                    children: [
                      ...eleves.map((e) {
                        final ctrl = TextEditingController(
                            text: d.notes[e.id]?.toStringAsFixed(2) ?? '');
                        return ListTile(
                          dense: true,
                          title: Text(e.nomComplet),
                          subtitle: d.notes[e.id] == null
                              ? const Text('Non remis', style: TextStyle(color: WA.danger, fontSize: 11))
                              : null,
                          trailing: SizedBox(
                            width: 80,
                            child: TextField(
                              controller: ctrl,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '/10', isDense: true),
                              onSubmitted: (v) async {
                                d.notes[e.id] = double.tryParse(v.replaceAll(',', '.'));
                                await s.save();
                              },
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.delete, color: WA.danger),
                        label: const Text('Supprimer le devoir', style: TextStyle(color: WA.danger)),
                        onPressed: () async {
                          s.devoirs.remove(d);
                          await s.save();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _nouveau(context, s),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _nouveau(BuildContext context, AppState s) async {
    final matieres = Matieres.nomsPourClasse(classe);
    var matiere = matieres.first;
    var donne = DateTime.now();
    var remise = DateTime.now().add(const Duration(days: 7));
    final titre = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nouveau devoir'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titre, decoration: const InputDecoration(labelText: 'Titre du devoir')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: matiere,
              decoration: const InputDecoration(labelText: 'Matiere', isDense: true),
              items: matieres.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setSt(() => matiere = v!),
            ),
            ListTile(
              title: Text('Donne le ${DateFormat('dd/MM/yyyy').format(donne)}'),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: donne, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setSt(() => donne = d);
              },
            ),
            ListTile(
              title: Text('Remise le ${DateFormat('dd/MM/yyyy').format(remise)}'),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: remise, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setSt(() => remise = d);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Creer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    s.devoirs.add(Devoir(
      classe: classe, matiere: matiere, titre: titre.text.trim(),
      dateDonne: donne, dateRemise: remise, anneeScolaire: s.annee,
    ));
    s.log('NOUVEAU_DEVOIR', cible: '$classe ${titre.text}');
    await s.save();
  }
}
