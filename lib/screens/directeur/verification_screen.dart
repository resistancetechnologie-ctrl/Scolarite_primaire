import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/app_state.dart';
import '../../services/calcul_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Authentification des bulletins par numero unique / QR Code.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ctrl = TextEditingController();
  String? resultat;
  String? qrData;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Authentification des bulletins')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        SectionCard(titre: 'Verifier un bulletin', icone: Icons.verified_user, children: [
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Numero d\'authentification (BUL-...)'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Verifier'),
            onPressed: () {
              final num = ctrl.text.trim().toUpperCase();
              final b = s.bulletins.where((x) => x.numeroAuthentification == num).toList();
              if (b.isEmpty) {
                setState(() {
                  resultat = 'Aucun bulletin ne correspond a ce numero. Document non authentifie.';
                  qrData = null;
                });
                return;
              }
              final m = b.first;
              final e = s.eleveParId(m.eleveId);
              final moy = e == null ? 0.0 : CalculService.calculer(s, e, m.periode).$2;
              setState(() {
                resultat = 'BULLETIN AUTHENTIQUE\n\n'
                    'Eleve : ${e?.nomComplet ?? '-'}\n'
                    'Matricule : ${e?.matricule ?? '-'}\n'
                    'Classe : ${e?.classe ?? '-'}\n'
                    'Periode : ${m.periode}\n'
                    'Annee : ${m.anneeScolaire}\n'
                    'Moyenne : ${moy.toStringAsFixed(2)}/10\n'
                    'Emis le : ${DateFormat('dd/MM/yyyy HH:mm').format(m.date)}';
                qrData = 'BULLETIN|${m.numeroAuthentification}|${e?.matricule}|${m.periode}|${m.anneeScolaire}';
              });
            },
          ),
          if (resultat != null) ...[
            const Divider(),
            Text(resultat!, style: const TextStyle(fontSize: 13)),
            if (qrData != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: qrData!, size: 160, foregroundColor: WA.teal),
                ),
              ),
          ],
        ]),
        SectionCard(titre: 'Bulletins emis', icone: Icons.list, children: [
          if (s.bulletins.isEmpty) const Text('Aucun bulletin genere.'),
          ...s.bulletins.reversed.take(50).map((b) => ListTile(
                dense: true,
                title: Text(s.eleveParId(b.eleveId)?.nomComplet ?? '-'),
                subtitle: Text('${b.numeroAuthentification} - ${b.periode} - ${b.anneeScolaire}',
                    style: const TextStyle(fontSize: 11)),
              )),
        ]),
      ]),
    );
  }
}
