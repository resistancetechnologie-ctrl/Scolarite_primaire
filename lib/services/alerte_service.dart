import '../core/constants.dart';
import '../data/app_state.dart';
import 'calcul_service.dart';

class Alerte {
  final String niveau; // info / attention / critique
  final String titre;
  final String message;
  final String recommandation;
  final String? eleveId;

  Alerte(this.niveau, this.titre, this.message, this.recommandation, {this.eleveId});
}

/// Alertes pedagogiques intelligentes (baisse de niveau, absences, risques...).
class AlerteService {
  static List<Alerte> pourClasse(AppState s, String classe) {
    final out = <Alerte>[];
    final eleves = s.elevesDe(classe);

    for (final e in eleves) {
      final evo = CalculService.evolutionEleve(s, e).entries.where((x) => x.value > 0).toList();

      // Baisse de niveau
      if (evo.length >= 2) {
        final d = evo.last.value - evo[evo.length - 2].value;
        if (d <= -1.5) {
          out.add(Alerte('attention', 'Baisse de niveau', 
              '${e.nomComplet} : ${d.toStringAsFixed(2)} pt entre ${evo[evo.length - 2].key} et ${evo.last.key}.',
              'Entretien avec l\'eleve et les parents, exercices de remediation ciblee.',
              eleveId: e.id));
        }
        if (d >= 1.5) {
          out.add(Alerte('info', 'Progression remarquable',
              '${e.nomComplet} : +${d.toStringAsFixed(2)} pt.',
              'Encourager et valoriser cet eleve.', eleveId: e.id));
        }
      }

      // Absences
      final abs = s.absencesDe(e.id);
      if (abs >= s.ecole.seuilAbsences) {
        out.add(Alerte('critique', 'Absences repetees',
            '${e.nomComplet} : $abs absence(s) - taux de presence ${s.tauxPresence(e.id).toStringAsFixed(0)}%.',
            'Convoquer les parents et etablir un suivi d\'assiduite.', eleveId: e.id));
      }
      if (absencesConsecutives(s, e.id) >= 3) {
        out.add(Alerte('critique', 'Absences consecutives',
            '${e.nomComplet} : absent 3 jours consecutifs ou plus.',
            'Contacter immediatement la famille.', eleveId: e.id));
      }

      // Difficulte / risque de redoublement
      final moy = CalculService.calculer(s, e, 'Annee').$2;
      if (moy > 0 && moy < 5) {
        out.add(Alerte('critique', 'Risque de redoublement',
            '${e.nomComplet} : moyenne annuelle ${moy.toStringAsFixed(2)}/10.',
            'Mettre en place un accompagnement individualise et un soutien renforce.',
            eleveId: e.id));
      } else if (moy >= 9) {
        out.add(Alerte('info', 'Eleve excellent',
            '${e.nomComplet} : moyenne ${moy.toStringAsFixed(2)}/10.',
            'Proposer des activites d\'approfondissement (haut potentiel).', eleveId: e.id));
      }
    }

    // Matieres faibles
    for (final m in Matieres.pourClasse(classe)) {
      final st = CalculService.statsMatiere(s, classe, m.nom, 'Annee');
      if ((st['effectif'] as int) > 0 && (st['moyenne'] as double) < 5) {
        out.add(Alerte('attention', 'Matiere en difficulte',
            '${m.nom} : moyenne de classe ${(st['moyenne'] as double).toStringAsFixed(2)}/10.',
            'Renforcer les seances et revoir la progression pedagogique.'));
      }
    }

    out.sort((a, b) => _poids(b.niveau).compareTo(_poids(a.niveau)));
    return out;
  }

  static int _poids(String n) => n == 'critique' ? 3 : (n == 'attention' ? 2 : 1);

  /// FAILLE CORRIGEE : la version precedente triait les seules presences
  /// *existantes* et comptait les absences consecutives dans cette liste,
  /// sans verifier l'ecart de calendrier reel entre deux enregistrements.
  /// Deux absences isolees a plusieurs semaines d'intervalle (mais sans
  /// aucun enregistrement de presence entre les deux) étaient donc comptees
  /// comme "consecutives". On exige desormais un ecart <= 3 jours calendaires
  /// entre deux absences successives (tolerance pour un week-end) pour les
  /// considerer comme faisant partie de la meme serie.
  static int absencesConsecutives(AppState s, String eleveId) {
    final l = s.presences.where((p) => p.eleveId == eleveId).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    int max = 0, cur = 0;
    DateTime? dernierJourAbsent;
    for (final p in l) {
      if (!p.present) {
        final proche = dernierJourAbsent != null &&
            p.date.difference(dernierJourAbsent).inDays <= 3;
        cur = proche ? cur + 1 : 1;
        if (cur > max) max = cur;
        dernierJourAbsent = p.date;
      } else {
        cur = 0;
        dernierJourAbsent = null;
      }
    }
    return max;
  }

  static List<Alerte> pourEcole(AppState s) {
    final out = <Alerte>[];
    for (final c in s.salles) {
      out.addAll(pourClasse(s, c).map((a) => Alerte(a.niveau, '[$c] ${a.titre}', a.message, a.recommandation, eleveId: a.eleveId)));
    }
    return out;
  }
}
