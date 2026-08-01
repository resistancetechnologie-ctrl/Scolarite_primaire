import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/calcul_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class StatsClasseScreen extends StatefulWidget {
  final String classe;
  const StatsClasseScreen({super.key, required this.classe});

  @override
  State<StatsClasseScreen> createState() => _StatsClasseScreenState();
}

class _StatsClasseScreenState extends State<StatsClasseScreen> {
  String periode = 'Trimestre 1';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = widget.classe;
    final matieres = Matieres.nomsPourClasse(c);
    final evo = CalculService.evolutionClasse(s, c);

    return Scaffold(
      appBar: AppBar(title: Text('Statistiques - $c')),
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
        SectionCard(titre: 'Synthese', icone: Icons.summarize, children: [
          _l('Effectif', '${s.elevesDe(c).length}'),
          _l('Moyenne de classe', '${CalculService.moyenneClasse(s, c, periode).toStringAsFixed(2)}/10'),
          _l('Taux de reussite', '${CalculService.tauxReussite(s, c, periode).toStringAsFixed(1)}%'),
        ]),
        SectionCard(titre: 'Statistiques par matiere', icone: Icons.subject, children: [
          ...matieres.map((m) {
            final st = CalculService.statsMatiere(s, c, m, periode);
            return ListTile(
              dense: true,
              title: Text(m),
              subtitle: Text(
                  'Moy ${(st['moyenne'] as double).toStringAsFixed(2)} | Max ${(st['max'] as double).toStringAsFixed(2)} | '
                  'Min ${(st['min'] as double).toStringAsFixed(2)} | Reussite ${(st['reussite'] as double).toStringAsFixed(0)}%'),
              trailing: SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: ((st['moyenne'] as double) / 10).clamp(0, 1),
                  color: WA.green,
                  backgroundColor: WA.divider,
                ),
              ),
            );
          }),
        ]),
        SectionCard(titre: 'Comparaison des 9 evaluations', icone: Icons.show_chart, children: [
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              minY: 0, maxY: 10,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text('E${v.toInt() + 1}', style: const TextStyle(fontSize: 9)),
                    interval: 1,
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  color: WA.green,
                  belowBarData: BarAreaData(show: true, color: WA.bubble),
                  spots: [
                    for (var i = 0; i < Evaluations.all.length; i++)
                      FlSpot(i.toDouble(), evo[Evaluations.all[i]] ?? 0),
                  ],
                ),
              ],
            )),
          ),
        ]),
        SectionCard(titre: 'Classement', icone: Icons.leaderboard, children: [
          ...CalculService.resultatsClasse(s, c, periode).map((r) => ListTile(
                dense: true,
                leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: WA.bubble,
                    child: Text('${r.rang}', style: const TextStyle(fontSize: 11, color: WA.teal))),
                title: Text(r.eleve.nomComplet),
                trailing: Text('${r.moyenne.toStringAsFixed(2)} - ${r.mention}',
                    style: const TextStyle(fontSize: 12)),
              )),
        ]),
        Padding(
          padding: const EdgeInsets.all(8),
          child: PdfActions(
            builder: () => PdfService.statistiquesClasse(s, c, periode),
            nom: 'statistiques_$c.pdf',
            label: 'Exporter les statistiques en PDF',
          ),
        ),
      ]),
    );
  }

  Widget _l(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 160, child: Text(k, style: const TextStyle(color: WA.grey))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}
