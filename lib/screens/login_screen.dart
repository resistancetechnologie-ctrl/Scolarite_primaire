import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'directeur/directeur_home.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Anti brute-force : compteur d'echecs et verrou temporaire par cle
  // (role/classe). Volontairement en memoire (non persiste) : il suffit a
  // dissuader les essais automatises pendant la session en cours.
  static final Map<String, int> _echecs = {};
  static final Map<String, DateTime> _verrouJusqua = {};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: WA.teal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: WA.lightGreen,
                  child: Icon(Icons.school, size: 46, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(s.ecole.nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(s.ecole.devise,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text('Annee scolaire ${s.ecole.anneeScolaire}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      const Text('Espace Directeur',
                          style: TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text('Se connecter'),
                          onPressed: () => _directeur(context, s),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.wifi_off, color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Text('Application 100% hors ligne',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _directeur(BuildContext context, AppState s) async {
    final ok = await _demanderPin(context, 'directeur', 'Code PIN Directeur', s.ecole.pinDirecteur);
    if (!ok || !context.mounted) return;
    s.connecterDirecteur();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DirecteurHome()));
  }

  /// Verifie le code PIN saisi.
  /// FAILLE CORRIGEE : un code PIN vide ("") ne doit jamais etre accepte,
  /// meme si le PIN configure est lui-meme vide (ex. champ efface par
  /// erreur dans la configuration). Sans ce garde-fou, laisser le champ
  /// de saisie vide et valider suffisait a se connecter sans code.
  bool _pinValide(String saisi, String attendu) => saisi.isNotEmpty && saisi == attendu;

  Future<bool> _demanderPin(BuildContext context, String cle, String titre, String attendu) async {
    final maintenant = DateTime.now();
    final verrou = _verrouJusqua[cle];
    if (verrou != null && maintenant.isBefore(verrou)) {
      final restant = verrou.difference(maintenant).inSeconds;
      if (context.mounted) {
        showError(context, 'Trop de tentatives. Reessayez dans ${restant}s.');
      }
      return false;
    }

    final ctrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Code PIN'),
          onSubmitted: (_) => Navigator.pop(context, _pinValide(ctrl.text, attendu)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, _pinValide(ctrl.text, attendu)),
              child: const Text('Valider')),
        ],
      ),
    );

    if (res == true) {
      _echecs.remove(cle);
      _verrouJusqua.remove(cle);
      return true;
    }

    // Annulation explicite (bouton "Annuler") : ne compte pas comme un echec.
    if (res == null) return false;

    final n = (_echecs[cle] ?? 0) + 1;
    _echecs[cle] = n;
    if (n >= 5) {
      _verrouJusqua[cle] = maintenant.add(const Duration(seconds: 30));
      _echecs[cle] = 0;
      if (context.mounted) showError(context, 'Trop de tentatives. Verrouille 30s.');
    } else if (context.mounted) {
      showError(context, 'Code PIN incorrect.');
    }
    return false;
  }
}
