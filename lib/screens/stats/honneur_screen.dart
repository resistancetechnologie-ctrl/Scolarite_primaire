import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/calcul_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class HonneurScreen extends StatefulWidget {
  final List<String> classes;
  const HonneurScreen({super.key, required this.classes});

  @override
  State<HonneurScreen> createState() => _HonneurScreenState();
}

class _HonneurScreenState extends State<HonneurScreen> {
  String periode = 'Trimestre 1';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Tableau d'honneur")),
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
        for (final c in widget.classes)
          SectionCard(titre: 'Classe $c', icone: Icons.emoji_events, children: [
            ...() {
              final res = CalculService.resultatsClasse(s, c, periode).take(5).toList();
              if (res.isEmpty) return <Widget>[const Text('Aucune donnee.')];
              return res.map((r) => ListTile(
                    dense: true,
                    leading: Icon(Icons.emoji_events,
                        color: r.rang == 1
                            ? const Color(0xFFFFC107)
                            : (r.rang == 2 ? Colors.grey : const Color(0xFFCD7F32))),
                    title: Text('${r.rang}. ${r.eleve.nomComplet}'),
                    subtitle: Text(r.mention),
                    trailing: Text('${r.moyenne.toStringAsFixed(2)}/10',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
                  )).toList();
            }(),
          ]),
        Padding(
          padding: const EdgeInsets.all(8),
          child: PdfActions(
            builder: () => PdfService.tableauHonneur(s, periode),
            nom: 'tableau_honneur.pdf',
            label: "Imprimer le tableau d'honneur",
          ),
        ),
      ]),
    );
  }
}
