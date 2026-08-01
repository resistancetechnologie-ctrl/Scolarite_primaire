import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/calcul_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../documents/documents_admin_screen.dart';

class EleveDetail extends StatelessWidget {
  final String eleveId;
  const EleveDetail({super.key, required this.eleveId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final e = s.eleveParId(eleveId);
    if (e == null) return const Scaffold(body: EmptyState(message: 'Eleve introuvable.'));
    final evo = CalculService.evolutionEleve(s, e);
    final moyAnnee = CalculService.calculer(s, e, 'Annee').$2;

    return Scaffold(
      appBar: AppBar(title: const Text('Dossier de l\'eleve')),
      body: ListView(children: [
        Container(
          color: WA.teal,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            imageBase64(e.photoBase64, size: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nomComplet,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(e.matricule, style: const TextStyle(color: Colors.white70)),
                Text('${e.classe} - ${e.statut}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        SectionCard(titre: 'Identite', icone: Icons.badge, children: [
          _l('Sexe', e.sexe == 'M' ? 'Garcon' : 'Fille'),
          _l('Naissance',
              '${e.dateNaissance == null ? '-' : DateFormat('dd/MM/yyyy').format(e.dateNaissance!)} a ${e.lieuNaissance}'),
          _l('Parent / tuteur', '${e.nomParent} ${e.telParent}'),
          _l('Adresse', e.adresse),
          _l('Groupe de niveau', e.groupeNiveau),
        ]),
        SectionCard(titre: 'Resultats', icone: Icons.assessment, children: [
          _l('Moyenne annuelle', '${moyAnnee.toStringAsFixed(2)}/10'),
          _l('Mention', CalculService.mention(s, moyAnnee)),
          const Divider(),
          ...evo.entries.map((x) => _l(x.key, x.value == 0 ? '-' : '${x.value.toStringAsFixed(2)}/10')),
        ]),
        SectionCard(titre: 'Assiduite', icone: Icons.event_available, children: [
          _l('Absences', '${s.absencesDe(e.id)} jour(s)'),
          _l('Taux de presence', '${s.tauxPresence(e.id).toStringAsFixed(1)}%'),
        ]),
        SectionCard(titre: 'Comportement', icone: Icons.emoji_people, children: [
          if (s.comportements.where((c) => c.eleveId == e.id).isEmpty)
            const Text('Aucune observation enregistree.'),
          ...s.comportements.where((c) => c.eleveId == e.id).map((c) => ListTile(
                dense: true,
                leading: Icon(
                    c.type == 'Sanction'
                        ? Icons.report
                        : (c.type == 'Encouragement' ? Icons.star : Icons.note),
                    color: c.type == 'Sanction' ? WA.danger : WA.green),
                title: Text(c.description),
                subtitle: Text('${DateFormat('dd/MM/yyyy').format(c.date)} - ${c.type}'),
              )),
        ]),
        SectionCard(titre: 'Frais scolaires', icone: Icons.payments, children: [
          if (s.paiements.where((p) => p.eleveId == e.id).isEmpty) const Text('Aucun paiement enregistre.'),
          ...s.paiements.where((p) => p.eleveId == e.id).map((p) => ListTile(
                dense: true,
                title: Text(p.libelle),
                subtitle: Text('Du : ${p.montantDu.toStringAsFixed(0)} | Paye : ${p.montantPaye.toStringAsFixed(0)} | Reste : ${p.reste.toStringAsFixed(0)}'),
              )),
        ]),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            PdfActions(
              builder: () => PdfService.dossierEleve(s, e),
              nom: 'dossier_${e.matricule}.pdf',
              label: 'Dossier complet PDF',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.description),
              label: const Text('Documents administratifs'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DocumentsAdminScreen(eleveId: e.id))),
            ),
            const SizedBox(height: 8),
            if (e.actif)
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, color: WA.warn),
                label: const Text('Transferer / depart de l\'eleve',
                    style: TextStyle(color: WA.warn)),
                onPressed: () => _transferer(context, s, e),
              ),
            const SizedBox(height: 8),
            if (s.estDirecteur)
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever, color: WA.danger),
                label: const Text('Supprimer l\'eleve', style: TextStyle(color: WA.danger)),
                onPressed: () async {
                  if (await confirmer(context, 'Supprimer',
                      'Supprimer definitivement ${e.nomComplet} et toutes ses donnees ?')) {
                    await s.supprimerEleve(e.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _l(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: WA.grey, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ]),
      );

  Future<void> _transferer(BuildContext context, AppState s, Eleve e) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transfert / depart'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Motif du depart')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok == true) {
      await s.transfererEleve(e.id, ctrl.text.trim());
      if (context.mounted) showOk(context, 'Transfert enregistre. Certificat disponible dans les documents.');
    }
  }
}
