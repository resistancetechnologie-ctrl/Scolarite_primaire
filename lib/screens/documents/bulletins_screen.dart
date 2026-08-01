import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../services/calcul_service.dart';
import '../../services/controle_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class BulletinsScreen extends StatefulWidget {
  final String classe;
  const BulletinsScreen({super.key, required this.classe});

  @override
  State<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends State<BulletinsScreen> {
  String periode = 'Trimestre 1';
  final Set<String> selection = {};

  List<String> get periodes => [...Evaluations.all, ...Evaluations.trimestres, 'Annee'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final res = CalculService.resultatsClasse(s, widget.classe, periode);

    return Scaffold(
      appBar: AppBar(title: Text('Bulletins - ${widget.classe}')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: DropdownButtonFormField<String>(
            value: periode,
            decoration: const InputDecoration(labelText: 'Periode', isDense: true),
            items: periodes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => periode = v!),
          ),
        ),
        Expanded(
          child: res.isEmpty
              ? const EmptyState(message: 'Aucun resultat pour cette periode.')
              : ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (_, i) {
                    final r = res[i];
                    return Card(
                      child: CheckboxListTile(
                        value: selection.contains(r.eleve.id),
                        onChanged: (v) => setState(() =>
                            v == true ? selection.add(r.eleve.id) : selection.remove(r.eleve.id)),
                        secondary: CircleAvatar(
                          backgroundColor: WA.bubble,
                          child: Text('${r.rang}', style: const TextStyle(color: WA.teal, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(r.eleve.nomComplet),
                        subtitle: Text(
                            'Moyenne ${r.moyenne.toStringAsFixed(2)}/10 - ${r.mention} - ${r.absences} abs.'),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: const Text('Assistant de controle avant generation'),
              onPressed: () => _controle(context, s),
            ),
            const SizedBox(height: 8),
            PdfActions(
              builder: () => PdfService.bulletins(s, widget.classe, periode,
                  eleveIds: selection.isEmpty ? null : selection.toList()),
              nom: 'bulletins_${widget.classe}_$periode.pdf',
              label: selection.isEmpty
                  ? 'Imprimer TOUS les bulletins'
                  : 'Imprimer ${selection.length} bulletin(s)',
            ),
          ]),
        ),
      ]),
    );
  }

  void _controle(BuildContext context, AppState s) {
    final anomalies = ControleService.controler(s, widget.classe, periode);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Controle avant generation'),
        content: SizedBox(
          width: 420,
          child: anomalies.isEmpty
              ? const Text('Aucune anomalie detectee. Vous pouvez generer les bulletins.')
              : ListView(
                  shrinkWrap: true,
                  children: anomalies
                      .map((a) => ListTile(
                            dense: true,
                            leading: Icon(a.gravite == 'bloquant' ? Icons.error : Icons.warning,
                                color: a.gravite == 'bloquant' ? WA.danger : WA.warn),
                            title: Text(a.message, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
