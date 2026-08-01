import '../core/constants.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import 'calcul_service.dart';

/// Promotion automatique / redoublement en fin d'annee.
class PromotionService {
  static const seuilAdmission = 5.0;

  static List<DecisionFinale> proposer(AppState s) {
    final out = <DecisionFinale>[];
    for (final c in s.salles) {
      for (final r in CalculService.resultatsClasse(s, c, 'Annee')) {
        final admis = r.moyenne >= seuilAdmission;
        out.add(DecisionFinale(
          eleveId: r.eleve.id,
          anneeScolaire: s.annee,
          classeOrigine: c,
          decision: admis ? 'ADMIS' : 'REDOUBLE',
          classeDestination: admis ? (Classes.next(c) ?? 'SORTIE (fin de cycle)') : c,
        ));
      }
    }
    return out;
  }

  static Future<void> enregistrer(AppState s, List<DecisionFinale> decisions) async {
    for (final d in decisions) {
      s.decisions.removeWhere((x) => x.eleveId == d.eleveId && x.anneeScolaire == d.anneeScolaire);
      s.decisions.add(d);
    }
    s.log('DECISIONS_FINALES', cible: s.annee, apres: '${decisions.length} decisions enregistrees');
    await s.save(backup: true, tag: 'decisions');
  }

  /// Applique les decisions : cree les eleves de la nouvelle annee.
  static Future<int> appliquer(AppState s, String nouvelleAnnee) async {
    final decisions = s.decisions.where((d) => d.anneeScolaire == s.annee).toList();
    int n = 0;
    final anciennes = List<Eleve>.from(s.eleves);
    for (final d in decisions) {
      final e = anciennes.firstWhere((x) => x.id == d.eleveId, orElse: () => Eleve(nom: '', prenom: '', classe: 'CP1'));
      if (e.nom.isEmpty) continue;
      if (d.classeDestination.startsWith('SORTIE')) continue;
      final copie = Eleve(
        matricule: '',
        nom: e.nom, prenom: e.prenom, sexe: e.sexe, dateNaissance: e.dateNaissance,
        lieuNaissance: e.lieuNaissance, classe: d.classeDestination,
        photoBase64: e.photoBase64, nomParent: e.nomParent, telParent: e.telParent,
        adresse: e.adresse, statut: d.decision == 'ADMIS' ? 'PROMU' : 'REDOUBLANT',
        anneeScolaire: nouvelleAnnee,
      );
      copie.matricule = _matricule(s, copie.classe, nouvelleAnnee);
      s.eleves.add(copie);
      n++;
    }
    s.log('PROMOTION_APPLIQUEE', cible: nouvelleAnnee, apres: '$n eleves reinscrits');
    await s.save(backup: true, tag: 'promotion');
    return n;
  }

  static String _matricule(AppState s, String classe, String annee) {
    final an = annee.split('-').first;
    final cle = classe.replaceAll(' ', '');
    var i = s.eleves.where((e) => e.matricule.startsWith('$an-$cle-')).length + 1;
    var mat = '$an-$cle-${i.toString().padLeft(3, '0')}';
    while (s.eleves.any((e) => e.matricule == mat)) {
      i++;
      mat = '$an-$cle-${i.toString().padLeft(3, '0')}';
    }
    return mat;
  }
}
