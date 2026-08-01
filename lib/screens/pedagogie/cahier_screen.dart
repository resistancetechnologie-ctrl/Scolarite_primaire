import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class CahierScreen extends StatelessWidget {
  final String classe;
  const CahierScreen({super.key, required this.classe});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.cahier.where((c) => c.classe == classe && c.anneeScolaire == s.annee).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text('Cahier de textes - $classe')),
      body: Column(children: [
        Expanded(
          child: l.isEmpty
              ? const EmptyState(message: 'Aucune seance enregistree.', icone: Icons.menu_book)
              : ListView.builder(
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final c = l[i];
                    return Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.book, color: WA.green),
                        title: Text('${DateFormat('dd/MM/yyyy').format(c.date)} - ${c.matiere}'),
                        subtitle: Text(c.lecon, maxLines: 1, overflow: TextOverflow.ellipsis),
                        children: [
                          ListTile(title: const Text('Resume'), subtitle: Text(c.resume)),
                          ListTile(title: const Text('Exercices'), subtitle: Text(c.exercices)),
                          ListTile(title: const Text('Devoirs'), subtitle: Text(c.devoirs)),
                          OverflowBar(children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                              onPressed: () => _form(context, s, classe, seance: c),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, color: WA.danger),
                              label: const Text('Supprimer', style: TextStyle(color: WA.danger)),
                              onPressed: () async {
                                s.cahier.remove(c);
                                await s.save();
                              },
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: PdfActions(
            builder: () => PdfService.cahierTextes(s, classe),
            nom: 'cahier_textes_$classe.pdf',
            label: 'Imprimer le cahier de textes',
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(context, s, classe),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _form(BuildContext context, AppState s, String classe, {SeanceCahier? seance}) async {
    final matieres = Matieres.nomsPourClasse(classe);
    var date = seance?.date ?? DateTime.now();
    var matiere = seance?.matiere ?? matieres.first;
    final lecon = TextEditingController(text: seance?.lecon ?? '');
    final resume = TextEditingController(text: seance?.resume ?? '');
    final ex = TextEditingController(text: seance?.exercices ?? '');
    final dev = TextEditingController(text: seance?.devoirs ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(seance == null ? 'Nouvelle seance' : 'Modifier la seance'),
          content: SizedBox(
            width: 420,
            child: ListView(shrinkWrap: true, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: WA.green),
                title: Text(DateFormat('dd/MM/yyyy').format(date)),
                onTap: () async {
                  final d = await showDatePicker(
                      context: ctx, initialDate: date,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setSt(() => date = d);
                },
              ),
              DropdownButtonFormField<String>(
                value: matiere,
                decoration: const InputDecoration(labelText: 'Matiere', isDense: true),
                items: matieres.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setSt(() => matiere = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: lecon, decoration: const InputDecoration(labelText: 'Lecon du jour')),
              const SizedBox(height: 8),
              TextField(controller: resume, maxLines: 3, decoration: const InputDecoration(labelText: 'Resume du cours')),
              const SizedBox(height: 8),
              TextField(controller: ex, maxLines: 2, decoration: const InputDecoration(labelText: 'Exercices donnes')),
              const SizedBox(height: 8),
              TextField(controller: dev, maxLines: 2, decoration: const InputDecoration(labelText: 'Devoirs a faire')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (seance == null) {
      s.cahier.add(SeanceCahier(
        classe: classe, date: date, matiere: matiere, lecon: lecon.text,
        resume: resume.text, exercices: ex.text, devoirs: dev.text, anneeScolaire: s.annee,
      ));
    } else {
      seance.date = date;
      seance.matiere = matiere;
      seance.lecon = lecon.text;
      seance.resume = resume.text;
      seance.exercices = ex.text;
      seance.devoirs = dev.text;
    }
    s.log('CAHIER_TEXTES', cible: '$classe ${DateFormat('dd/MM/yyyy').format(date)}');
    await s.save();
  }
}
