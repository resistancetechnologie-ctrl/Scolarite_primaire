import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class FraisScreen extends StatefulWidget {
  const FraisScreen({super.key});

  @override
  State<FraisScreen> createState() => _FraisScreenState();
}

class _FraisScreenState extends State<FraisScreen> {
  String? classe;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    classe ??= s.salles.isEmpty ? '' : s.salles.first;
    if (classe!.isNotEmpty && !s.salles.contains(classe)) classe = s.salles.first;
    final classeSel = classe!;
    final eleves = s.elevesDe(classeSel);

    return Scaffold(
      appBar: AppBar(title: const Text('Frais scolaires')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: ClassePicker(
              valeur: classeSel, classes: s.salles, onChanged: (c) => setState(() => classe = c)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: eleves.length,
            itemBuilder: (_, i) {
              final e = eleves[i];
              final p = s.paiements.where((x) => x.eleveId == e.id && x.anneeScolaire == s.annee).toList();
              final du = p.fold<double>(0, (a, b) => a + b.montantDu);
              final paye = p.fold<double>(0, (a, b) => a + b.montantPaye);
              final enRegle = du > 0 && paye >= du;
              return Card(
                child: ExpansionTile(
                  leading: Icon(enRegle ? Icons.check_circle : Icons.warning,
                      color: enRegle ? WA.lightGreen : WA.warn),
                  title: Text(e.nomComplet),
                  subtitle: Text('Du : ${du.toStringAsFixed(0)} | Paye : ${paye.toStringAsFixed(0)} | '
                      'Reste : ${(du - paye).clamp(0, double.infinity).toStringAsFixed(0)}'),
                  children: [
                    ...p.map((x) => ListTile(
                          dense: true,
                          title: Text(x.libelle),
                          subtitle: Text('${DateFormat('dd/MM/yyyy').format(x.date)} - Recu ${x.recu}'),
                          trailing: Text('${x.montantPaye.toStringAsFixed(0)}/${x.montantDu.toStringAsFixed(0)}'),
                        )),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un paiement'),
                      onPressed: () => _ajouter(context, s, e),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: PdfActions(
              builder: () => PdfService.etatFrais(s),
              nom: 'etat_frais.pdf',
              label: 'Etat des frais scolaires (PDF)'),
        ),
      ]),
    );
  }

  Future<void> _ajouter(BuildContext context, AppState s, Eleve e) async {
    final libelle = TextEditingController(text: 'Mensualite');
    final du = TextEditingController(text: '0');
    final paye = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Paiement - ${e.nomComplet}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Libelle')),
          TextField(controller: du, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant du')),
          TextField(controller: paye, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant paye')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    s.paiements.add(Paiement(
      eleveId: e.id, libelle: libelle.text.trim(),
      montantDu: double.tryParse(du.text) ?? 0,
      montantPaye: double.tryParse(paye.text) ?? 0,
      anneeScolaire: s.annee,
    ));
    s.log('PAIEMENT', cible: e.nomComplet, apres: paye.text);
    await s.save();
  }
}
