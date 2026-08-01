/// Constantes metier : niveaux pedagogiques fixes et matieres predefinies par niveau.
///
/// Une "salle" (ex: "CP1 A", "CP1 B") est le nom concret d'une classe physique,
/// gere dynamiquement par l'ecole (voir AppState.salles). Elle est toujours
/// rattachee a un "niveau" pedagogique fixe (CP1..CM2, cette liste [Classes.all])
/// qui determine les matieres enseignees et l'ordre de promotion. [niveauDe]
/// fait le lien entre les deux : "CP1 B" -> niveau "CP1".
class Classes {
  static const List<String> all = ['CP1', 'CP2', 'CE1', 'CE2', 'CM1', 'CM2'];

  /// Deduit le niveau pedagogique (CP1..CM2) d'un nom de salle quelconque.
  /// "CP1" -> "CP1" ; "CP1 A" -> "CP1" ; "CP1 B" -> "CP1".
  /// Si aucun niveau connu ne correspond, retourne la salle telle quelle
  /// (repli defensif pour ne jamais planter sur une donnee inattendue).
  static String niveauDe(String salle) {
    for (final n in all) {
      if (salle == n || salle.startsWith('$n ')) return n;
    }
    return salle;
  }

  /// Classe superieure pour la promotion automatique (par niveau).
  static String? next(String c) {
    final i = all.indexOf(niveauDe(c));
    if (i < 0 || i >= all.length - 1) return null;
    return all[i + 1];
  }
}

class Matiere {
  final String nom;
  final int coefficient;
  const Matiere(this.nom, [this.coefficient = 1]);
}

class Matieres {
  /// CP1 -> CE1 (aucune ponderation : coefficient 1 pour toutes les matieres)
  static const List<Matiere> petitesClasses = [
    Matiere('Dictee', 1),
    Matiere('Question', 1),
    Matiere('Ecriture', 1),
    Matiere('Calcul ecrit', 1),
    Matiere('Calcul mental', 1),
    Matiere('Dessin', 1),
    Matiere('Anglais', 1),
    Matiere('Lecture', 1),
    Matiere('Poesie', 1),
  ];

  /// CE2 -> CM2 (aucune ponderation : coefficient 1 pour toutes les matieres)
  static const List<Matiere> grandesClasses = [
    Matiere('Dictee', 1),
    Matiere('Question', 1),
    Matiere('Question de cours', 1),
    Matiere('Calcul', 1),
    Matiere('Calcul ecrit', 1),
    Matiere('Francais', 1),
    Matiere('Arts plastiques', 1),
    Matiere('Lecture', 1),
    Matiere('Poesie', 1),
    Matiere('Morale', 1),
    Matiere('Conduite', 1),
  ];

  static List<Matiere> pourClasse(String classe) {
    switch (Classes.niveauDe(classe)) {
      case 'CP1':
      case 'CP2':
      case 'CE1':
        return petitesClasses;
      default:
        return grandesClasses;
    }
  }

  static List<String> nomsPourClasse(String classe) =>
      pourClasse(classe).map((m) => m.nom).toList();

  static int coefficient(String classe, String matiere) {
    for (final m in pourClasse(classe)) {
      if (m.nom == matiere) return m.coefficient;
    }
    return 1;
  }
}

/// Les 9 evaluations de l'annee (3 par trimestre).
class Evaluations {
  static const List<String> all = [
    'Eval 1', 'Eval 2', 'Eval 3',
    'Eval 4', 'Eval 5', 'Eval 6',
    'Eval 7', 'Eval 8', 'Eval 9',
  ];

  static int trimestreDe(String eval) {
    final i = all.indexOf(eval);
    if (i < 0) return 1;
    return (i ~/ 3) + 1;
  }

  static List<String> duTrimestre(int t) =>
      all.sublist((t - 1) * 3, (t - 1) * 3 + 3);

  static const List<String> trimestres = ['Trimestre 1', 'Trimestre 2', 'Trimestre 3'];
}

class Periodes {
  static const mensuelle = 'MENSUELLE';
  static const trimestrielle = 'TRIMESTRIELLE';
  static const annuelle = 'ANNUELLE';
  static const all = [mensuelle, trimestrielle, annuelle];
  // ignore: constant_identifier_names
  static const MENSUELLE_DEFAULT = mensuelle;
}
