import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/pdf_service.dart';
import '../../widgets/common.dart';

/// Impression groupee : listes, registres, deliberation, statistiques.
class DocumentsScreen extends StatefulWidget {
  final String classe;
  const DocumentsScreen({super.key, required this.classe});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String periode = 'Trimestre 1';
  DateTime debut = DateTime.now().subtract(const Duration(days: 30));
  DateTime fin = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = widget.classe;
    return Scaffold(
      appBar: AppBar(title: Text('Documents - $c')),
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
        SectionCard(titre: 'Registres officiels', icone: Icons.menu_book, children: [
          PdfActions(
              builder: () => PdfService.registreNotes(s, c, periode),
              nom: 'registre_notes_$c.pdf',
              label: 'Registre de notes'),
          const SizedBox(height: 8),
          PdfActions(
              builder: () => PdfService.registreAppel(s, c, debut, fin),
              nom: 'registre_appel_$c.pdf',
              label: "Registre d'appel"),
        ]),
        SectionCard(titre: 'Listes', icone: Icons.list_alt, children: [
          PdfActions(
              builder: () => PdfService.listeEleves(s, c),
              nom: 'liste_eleves_$c.pdf',
              label: 'Liste des eleves'),
          const SizedBox(height: 8),
          PdfActions(
              builder: () => PdfService.listeEleves(s, c, emargement: true),
              nom: 'emargement_$c.pdf',
              label: "Liste d'emargement"),
        ]),
        SectionCard(titre: 'Deliberation et moyennes', icone: Icons.gavel, children: [
          PdfActions(
              builder: () => PdfService.ficheCalculMoyennes(s, c, periode),
              nom: 'calcul_moyennes_$c.pdf',
              label: 'Fiche de calcul des moyennes'),
          const SizedBox(height: 8),
          PdfActions(
              builder: () => PdfService.ficheDeliberation(s, c, periode),
              nom: 'deliberation_$c.pdf',
              label: 'Fiche de deliberation'),
        ]),
        SectionCard(titre: 'Statistiques et suivi', icone: Icons.insert_chart, children: [
          PdfActions(
              builder: () => PdfService.statistiquesClasse(s, c, periode),
              nom: 'statistiques_$c.pdf',
              label: 'Statistiques de la classe'),
          const SizedBox(height: 8),
          PdfActions(
              builder: () => PdfService.cahierTextes(s, c),
              nom: 'cahier_textes_$c.pdf',
              label: 'Cahier de textes'),
          const SizedBox(height: 8),
          PdfActions(
              builder: () => PdfService.emploiDuTemps(s, c),
              nom: 'edt_$c.pdf',
              label: 'Emploi du temps'),
        ]),
      ]),
    );
  }
}
