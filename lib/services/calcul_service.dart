import '../core/constants.dart';
import '../data/app_state.dart';
import '../models/models.dart';

/// Calculs pedagogiques : moyennes, totaux, rangs, mentions, appreciations.
class CalculService {
  static List<String> evaluationsDePeriode(String periode) {
    if (periode == 'Annee') return Evaluations.all;
    if (periode.startsWith('Trimestre')) {
      final t = int.tryParse(periode.split(' ').last) ?? 1;
      return Evaluations.duTrimestre(t);
    }
    return [periode];
  }

  /// Moyenne d'une matiere sur une periode (notes sur 10).
  static double? moyenneMatiere(AppState s, String eleveId, String matiere, String periode) {
    final evals = evaluationsDePeriode(periode);
    final vals = <double>[];
    for (final e in evals) {
      final n = s.note(eleveId, matiere, e);
      if (n != null) vals.add(n.valeur);
    }
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  /// Total pondere et moyenne generale.
  static (double total, double moyenne, Map<String, double> parMatiere) calculer(
      AppState s, Eleve el, String periode) {
    final matieres = Matieres.pourClasse(el.classe);
    double total = 0, coefTotal = 0;
    final map = <String, double>{};
    for (final m in matieres) {
      final moy = moyenneMatiere(s, el.id, m.nom, periode);
      if (moy == null) continue;
      map[m.nom] = moy;
      total += moy * m.coefficient;
      coefTotal += m.coefficient;
    }
    final moyenne = coefTotal == 0 ? 0.0 : total / coefTotal;
    return (total, moyenne, map);
  }

  /// Resultats classes d'une classe entiere (rangs inclus).
  static List<ResultatEleve> resultatsClasse(AppState s, String classe, String periode) {
    final eleves = s.elevesDe(classe);
    final tmp = <(Eleve, double, double, Map<String, double>)>[];
    for (final e in eleves) {
      final r = calculer(s, e, periode);
      tmp.add((e, r.$1, r.$2, r.$3));
    }
    tmp.sort((a, b) => b.$3.compareTo(a.$3));
    final out = <ResultatEleve>[];
    for (var i = 0; i < tmp.length; i++) {
      var rang = i + 1;
      if (i > 0 && (tmp[i].$3 - tmp[i - 1].$3).abs() < 0.0001) {
        rang = out[i - 1].rang;
      }
      out.add(ResultatEleve(
        eleve: tmp[i].$1,
        total: tmp[i].$2,
        moyenne: tmp[i].$3,
        moyennesParMatiere: tmp[i].$4,
        rang: rang,
        mention: mention(s, tmp[i].$3),
        absences: s.absencesDe(tmp[i].$1.id),
      ));
    }
    return out;
  }

  static String mention(AppState s, double moyenne) {
    final entries = s.ecole.seuilsMentions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      if (moyenne >= e.value) return e.key;
    }
    return 'Faible';
  }

  static String appreciationAuto(double moyenne) {
    if (moyenne >= 9) return "Excellent travail, continuez ainsi.";
    if (moyenne >= 8) return "Tres bons resultats, felicitations.";
    if (moyenne >= 7) return "Bon travail, poursuivez vos efforts.";
    if (moyenne >= 6) return "Resultats satisfaisants, des efforts supplementaires sont attendus.";
    if (moyenne >= 5) return "Travail passable, plus de rigueur est necessaire.";
    if (moyenne >= 3.5) return "Resultats insuffisants, un accompagnement particulier est recommande.";
    return "Resultats tres faibles, un soutien urgent est indispensable.";
  }

  /// Statistiques d'une matiere pour une classe.
  static Map<String, dynamic> statsMatiere(AppState s, String classe, String matiere, String periode) {
    final eleves = s.elevesDe(classe);
    final vals = <double>[];
    for (final e in eleves) {
      final m = moyenneMatiere(s, e.id, matiere, periode);
      if (m != null) vals.add(m);
    }
    if (vals.isEmpty) {
      return {'moyenne': 0.0, 'max': 0.0, 'min': 0.0, 'reussite': 0.0, 'effectif': 0};
    }
    vals.sort();
    final moy = vals.reduce((a, b) => a + b) / vals.length;
    final reussite = vals.where((v) => v >= 5).length * 100 / vals.length;
    return {
      'moyenne': moy, 'max': vals.last, 'min': vals.first,
      'reussite': reussite, 'effectif': vals.length,
    };
  }

  /// Moyenne de classe par evaluation (comparaison des 9 evaluations).
  static Map<String, double> evolutionClasse(AppState s, String classe) {
    final out = <String, double>{};
    for (final ev in Evaluations.all) {
      final res = resultatsClasse(s, classe, ev);
      final avec = res.where((r) => r.moyenne > 0).toList();
      out[ev] = avec.isEmpty ? 0 : avec.map((e) => e.moyenne).reduce((a, b) => a + b) / avec.length;
    }
    return out;
  }

  static Map<String, double> evolutionEleve(AppState s, Eleve el) {
    final out = <String, double>{};
    for (final ev in Evaluations.all) {
      out[ev] = calculer(s, el, ev).$2;
    }
    return out;
  }

  static double moyenneClasse(AppState s, String classe, String periode) {
    final res = resultatsClasse(s, classe, periode).where((r) => r.moyenne > 0).toList();
    if (res.isEmpty) return 0;
    return res.map((r) => r.moyenne).reduce((a, b) => a + b) / res.length;
  }

  static double tauxReussite(AppState s, String classe, String periode) {
    final res = resultatsClasse(s, classe, periode).where((r) => r.moyenne > 0).toList();
    if (res.isEmpty) return 0;
    return res.where((r) => r.moyenne >= 5).length * 100 / res.length;
  }
}
