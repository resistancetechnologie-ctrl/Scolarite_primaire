import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class EdtScreen extends StatelessWidget {
  final String classe;
  const EdtScreen({super.key, required this.classe});

  static const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final l = s.edt.where((c) => c.classe == classe).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));

    return Scaffold(
      appBar: AppBar(title: Text('Emploi du temps - $classe')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        for (final j in jours)
          SectionCard(titre: j, icone: Icons.schedule, children: [
            ...() {
              final creneaux = l.where((x) => x.jour == j).toList();
              if (creneaux.isEmpty) return <Widget>[const Text('Aucun creneau.')];
              return creneaux.map((c) => ListTile(
                    dense: true,
                    leading: Text('${c.debut}\n${c.fin}', style: const TextStyle(fontSize: 11)),
                    title: Text(c.matiere),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: WA.danger),
                      onPressed: () async {
                        s.edt.remove(c);
                        await s.save();
                      },
                    ),
                  )).toList();
            }(),
          ]),
        Padding(
          padding: const EdgeInsets.all(8),
          child: PdfActions(
            builder: () => PdfService.emploiDuTemps(s, classe),
            nom: 'edt_$classe.pdf',
            label: "Imprimer l'emploi du temps",
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _ajouter(context, s),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _ajouter(BuildContext context, AppState s) async {
    final options = [...Matieres.nomsPourClasse(classe), 'Recreation', 'Etude', 'Sport'];
    var jour = jours.first;
    var matiere = options.first;
    final debut = TextEditingController(text: '08:00');
    final fin = TextEditingController(text: '09:00');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nouveau creneau'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: jour,
              decoration: const InputDecoration(labelText: 'Jour', isDense: true),
              items: jours.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setSt(() => jour = v!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: matiere,
              decoration: const InputDecoration(labelText: 'Activite', isDense: true),
              items: options.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setSt(() => matiere = v!),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: debut, decoration: const InputDecoration(labelText: 'Debut'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: fin, decoration: const InputDecoration(labelText: 'Fin'))),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    s.edt.add(CreneauEDT(
      classe: classe, jour: jour, debut: debut.text, fin: fin.text,
      matiere: matiere, anneeScolaire: s.annee,
    ));
    await s.save();
  }
}
