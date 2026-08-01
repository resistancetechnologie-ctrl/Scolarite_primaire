import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class GroupesScreen extends StatelessWidget {
  final String classe;
  const GroupesScreen({super.key, required this.classe});

  static const groupes = ['Avance', 'Moyen', 'Difficulte'];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eleves = s.elevesDe(classe);
    return Scaffold(
      appBar: AppBar(title: Text('Groupes de niveau - $classe')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        for (final g in groupes)
          SectionCard(
            titre: '$g (${eleves.where((e) => e.groupeNiveau == g).length})',
            icone: g == 'Avance' ? Icons.trending_up : (g == 'Moyen' ? Icons.horizontal_rule : Icons.trending_down),
            children: [
              ...eleves.where((e) => e.groupeNiveau == g).map((e) => ListTile(
                    dense: true,
                    leading: imageBase64(e.photoBase64, size: 36),
                    title: Text(e.nomComplet),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.swap_horiz, color: WA.green),
                      itemBuilder: (_) => groupes
                          .map((x) => PopupMenuItem(value: x, child: Text('Deplacer vers $x')))
                          .toList(),
                      onSelected: (v) async {
                        e.groupeNiveau = v;
                        await s.majEleve(e);
                      },
                    ),
                  )),
            ],
          ),
      ]),
    );
  }
}
