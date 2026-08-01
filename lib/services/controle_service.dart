import '../core/constants.dart';
import '../data/app_state.dart';
import 'calcul_service.dart';

class Anomalie {
  final String gravite; // bloquant / avertissement
  final String message;
  Anomalie(this.gravite, this.message);
}

/// Assistant de controle avant generation des bulletins (16.20).
class ControleService {
  static List<Anomalie> controler(AppState s, String classe, String periode) {
    final out = <Anomalie>[];
    final eleves = s.elevesDe(classe);
    if (eleves.isEmpty) {
      out.add(Anomalie('bloquant', "Aucun eleve enregistre dans la classe $classe."));
      return out;
    }
    if (s.ecole.nom.trim().isEmpty) out.add(Anomalie('bloquant', "Nom de l'ecole non renseigne."));
    if (s.ecole.anneeScolaire.trim().isEmpty) out.add(Anomalie('bloquant', "Annee scolaire non renseignee."));
    if (s.enseignantDe(classe).nomComplet.trim().isEmpty) {
      out.add(Anomalie('avertissement', "Nom de l'enseignant de $classe non renseigne."));
    }
    if (s.ecole.signatureBase64.isEmpty) {
      out.add(Anomalie('avertissement', "Signature du directeur absente : un espace reserve sera imprime."));
    }
    if (s.ecole.cachetBase64.isEmpty) {
      out.add(Anomalie('avertissement', "Cachet de l'ecole absent : un espace reserve sera imprime."));
    }

    final matieres = Matieres.nomsPourClasse(classe);
    final evals = CalculService.evaluationsDePeriode(periode);

    for (final e in eleves) {
      final manquantes = <String>[];
      for (final m in matieres) {
        for (final ev in evals) {
          if (s.note(e.id, m, ev) == null) manquantes.add('$m/$ev');
        }
      }
      if (manquantes.length == matieres.length * evals.length) {
        out.add(Anomalie('bloquant', "${e.nomComplet} : aucune note saisie pour $periode."));
      } else if (manquantes.isNotEmpty) {
        out.add(Anomalie('avertissement',
            "${e.nomComplet} : ${manquantes.length} note(s) manquante(s) (${manquantes.take(3).join(', ')}${manquantes.length > 3 ? '...' : ''})."));
      }
      for (final n in s.notesDe(e.id, periode: periode)) {
        if (n.valeur < 0 || n.valeur > 10) {
          out.add(Anomalie('bloquant', "${e.nomComplet} : note invalide ${n.valeur} en ${n.matiere} (${n.evaluation})."));
        }
      }
      if (s.ecole.photosActivees && e.photoBase64.isEmpty) {
        out.add(Anomalie('avertissement', "${e.nomComplet} : photo manquante (option photo activee)."));
      }
      if (e.matricule.isEmpty) {
        out.add(Anomalie('bloquant', "${e.nomComplet} : matricule absent."));
      }
    }
    return out;
  }
}
