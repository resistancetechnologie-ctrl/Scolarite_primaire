import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des modifications')),
      body: s.audit.isEmpty
          ? const EmptyState(message: 'Aucune modification enregistree.', icone: Icons.history)
          : ListView.builder(
              itemCount: s.audit.length,
              itemBuilder: (_, i) {
                final a = s.audit[i];
                return Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_edu, color: WA.green),
                    title: Text('${a.action} - ${a.cible}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                        '${DateFormat('dd/MM/yyyy HH:mm').format(a.date)} - ${a.utilisateur}'
                        '${a.ancienneValeur.isEmpty && a.nouvelleValeur.isEmpty ? '' : '\nAvant : ${a.ancienneValeur} | Apres : ${a.nouvelleValeur}'}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                );
              },
            ),
    );
  }
}
