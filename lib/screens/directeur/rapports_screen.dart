import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/calcul_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Rapport annuel, mode inspection, statistiques comparatives de l'ecole.
class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  String periode = 'Annee';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports et inspection')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DropdownButtonFormField<String>(
              value: periode,
              decoration: const InputDecoration(labelText: 'Periode', isDense: true),
              items: [...Evaluations.all, ...Evaluations.trimestres, 'Annee']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => periode = v!),
            ),
          ),
        ),
        SectionCard(titre: 'Statistiques comparatives des classes', icone: Icons.compare_arrows, children: [
          ...s.salles.map((c) => ListTile(
                dense: true,
                title: Text(c),
                subtitle: Text('Effectif ${s.elevesDe(c).length} - '
                    'Reussite ${CalculService.tauxReussite(s, c, periode).toStringAsFixed(0)}%'),
                trailing: Text('${CalculService.moyenneClasse(s, c, periode).toStringAsFixed(2)}/10',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
              )),
        ]),
        SectionCard(titre: 'Rapport annuel automatique', icone: Icons.description, children: [
          PdfActions(
              builder: () => PdfService.rapportAnnuel(s),
              nom: 'rapport_annuel_${s.annee}.pdf',
              label: 'Generer le rapport annuel'),
        ]),
        SectionCard(titre: 'Mode Inspection scolaire', icone: Icons.policy, children: [
          const Text(
              'Genere en un clic un dossier complet : listes, registres, fiches de calcul, '
              'deliberations, statistiques, tableau d\'honneur et rapport annuel.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          PdfActions(
              builder: () => PdfService.dossierInspection(s, periode),
              nom: 'dossier_inspection_${s.annee}.pdf',
              label: "Generer le dossier d'inspection",
              icone: Icons.folder_special),
        ]),
      ]),
    );
  }
}
