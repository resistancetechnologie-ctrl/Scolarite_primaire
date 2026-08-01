import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../services/alerte_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AlertesScreen extends StatelessWidget {
  final String? classe; // null = toute l'ecole
  const AlertesScreen({super.key, this.classe});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final alertes = classe == null ? AlerteService.pourEcole(s) : AlerteService.pourClasse(s, classe!);
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes pedagogiques')),
      body: alertes.isEmpty
          ? const EmptyState(message: 'Aucune alerte. Tout va bien !', icone: Icons.verified)
          : ListView.builder(
              itemCount: alertes.length,
              itemBuilder: (_, i) {
                final a = alertes[i];
                final col = a.niveau == 'critique'
                    ? WA.danger
                    : (a.niveau == 'attention' ? WA.warn : WA.green);
                return Card(
                  child: ListTile(
                    leading: Icon(
                        a.niveau == 'critique'
                            ? Icons.error
                            : (a.niveau == 'attention' ? Icons.warning : Icons.info),
                        color: col),
                    title: Text(a.titre, style: TextStyle(fontWeight: FontWeight.bold, color: col)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.message),
                      const SizedBox(height: 4),
                      Text('Recommandation : ${a.recommandation}',
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
