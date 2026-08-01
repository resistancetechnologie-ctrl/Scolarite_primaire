import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/promotion_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  List<DecisionFinale> decisions = [];

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    decisions = s.decisions.where((d) => d.anneeScolaire == s.annee).toList();
    if (decisions.isEmpty) decisions = PromotionService.proposer(s);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Promotion et decisions finales')),
      body: decisions.isEmpty
          ? const EmptyState(message: 'Aucun eleve a traiter.')
          : ListView.builder(
              itemCount: decisions.length,
              itemBuilder: (_, i) {
                final d = decisions[i];
                final e = s.eleveParId(d.eleveId);
                return Card(
                  child: ListTile(
                    leading: Icon(d.decision == 'ADMIS' ? Icons.arrow_upward : Icons.replay,
                        color: d.decision == 'ADMIS' ? WA.lightGreen : WA.warn),
                    title: Text(e?.nomComplet ?? '-'),
                    subtitle: Row(children: [
                      Text('${d.classeOrigine} -> '),
                      DropdownButton<String>(
                        value: s.salles.contains(d.classeDestination) ? d.classeDestination : null,
                        hint: Text(d.classeDestination, style: const TextStyle(fontSize: 13)),
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 13, color: WA.teal),
                        items: [
                          for (final salle in s.salles)
                            DropdownMenuItem(value: salle, child: Text(salle)),
                          if (d.decision == 'ADMIS')
                            const DropdownMenuItem(
                                value: 'SORTIE (fin de cycle)', child: Text('SORTIE (fin de cycle)')),
                        ],
                        onChanged: (v) => setState(() {
                          decisions[i] = DecisionFinale(
                            eleveId: d.eleveId, anneeScolaire: d.anneeScolaire,
                            classeOrigine: d.classeOrigine, decision: d.decision,
                            classeDestination: v!, manuelle: true,
                          );
                        }),
                      ),
                      if (d.manuelle)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('(decision manuelle)', style: TextStyle(fontSize: 11)),
                        ),
                    ]),
                    trailing: DropdownButton<String>(
                      value: d.decision,
                      items: const [
                        DropdownMenuItem(value: 'ADMIS', child: Text('Admis')),
                        DropdownMenuItem(value: 'REDOUBLE', child: Text('Redouble')),
                      ],
                      onChanged: (v) => setState(() {
                        decisions[i] = DecisionFinale(
                          eleveId: d.eleveId, anneeScolaire: d.anneeScolaire,
                          classeOrigine: d.classeOrigine, decision: v!,
                          classeDestination: v == 'ADMIS'
                              ? (Classes.next(d.classeOrigine) ?? 'SORTIE (fin de cycle)')
                              : d.classeOrigine,
                          manuelle: true,
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer les decisions'),
            onPressed: () async {
              await PromotionService.enregistrer(s, decisions);
              if (context.mounted) showOk(context, 'Decisions enregistrees.');
            },
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.school),
            label: const Text('Assistant de rentree : reinscrire les eleves'),
            onPressed: () async {
              final ctrl = TextEditingController(text: s.annee);
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Assistant de preparation de rentree'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Les eleves seront reinscrits dans leur nouvelle classe pour l\'annee indiquee.'),
                    const SizedBox(height: 8),
                    TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Annee scolaire cible')),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Appliquer')),
                  ],
                ),
              );
              if (ok != true) return;
              await PromotionService.enregistrer(s, decisions);
              final n = await PromotionService.appliquer(s, ctrl.text.trim());
              if (context.mounted) showOk(context, '$n eleve(s) reinscrit(s) pour ${ctrl.text.trim()}.');
            },
          ),
        ]),
      ),
    );
  }
}
