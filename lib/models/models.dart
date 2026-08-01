// Modeles de donnees - tous serialisables en JSON (mode 100% offline).
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

/// ---------------------------------------------------------------- ECOLE
class Ecole {
  String nom;
  String devise;
  String adresse;
  String telephone;
  String email;
  String logoBase64;
  String signatureBase64;
  String cachetBase64;
  String nomDirecteur;
  String anneeScolaire;
  bool photosActivees;
  String pinDirecteur;
  String pinEnseignant;
  int seuilAbsences;
  Map<String, double> seuilsMentions;

  Ecole({
    this.nom = "Ecole Primaire",
    this.devise = "Travail - Discipline - Reussite",
    this.adresse = "",
    this.telephone = "",
    this.email = "",
    this.logoBase64 = "",
    this.signatureBase64 = "",
    this.cachetBase64 = "",
    this.nomDirecteur = "",
    String? anneeScolaire,
    this.photosActivees = true,
    this.pinDirecteur = "1234",
    this.pinEnseignant = "0000",
    this.seuilAbsences = 5,
    Map<String, double>? seuilsMentions,
  })  : anneeScolaire = anneeScolaire ?? defaultAnnee(),
        seuilsMentions = seuilsMentions ?? Map<String, double>.from(mentionsParDefaut);

  static String defaultAnnee() {
    final n = DateTime.now();
    return n.month >= 9 ? '${n.year}-${n.year + 1}' : '${n.year - 1}-${n.year}';
  }

  static const Map<String, double> mentionsParDefaut = {
    'Excellent': 9.0,
    'Tres Bien': 8.0,
    'Bien': 7.0,
    'Assez Bien': 6.0,
    'Passable': 5.0,
    'Insuffisant': 3.5,
    'Faible': 0.0,
  };

  Map<String, dynamic> toJson() => {
        'nom': nom, 'devise': devise, 'adresse': adresse, 'telephone': telephone,
        'email': email, 'logoBase64': logoBase64, 'signatureBase64': signatureBase64,
        'cachetBase64': cachetBase64, 'nomDirecteur': nomDirecteur,
        'anneeScolaire': anneeScolaire, 'photosActivees': photosActivees,
        'pinDirecteur': pinDirecteur, 'pinEnseignant': pinEnseignant,
        'seuilAbsences': seuilAbsences, 'seuilsMentions': seuilsMentions,
      };

  factory Ecole.fromJson(Map<String, dynamic> j) => Ecole(
        nom: j['nom'] ?? 'Ecole Primaire',
        devise: j['devise'] ?? '',
        adresse: j['adresse'] ?? '',
        telephone: j['telephone'] ?? '',
        email: j['email'] ?? '',
        logoBase64: j['logoBase64'] ?? '',
        signatureBase64: j['signatureBase64'] ?? '',
        cachetBase64: j['cachetBase64'] ?? '',
        nomDirecteur: j['nomDirecteur'] ?? '',
        anneeScolaire: j['anneeScolaire'],
        photosActivees: j['photosActivees'] ?? true,
        pinDirecteur: j['pinDirecteur'] ?? '1234',
        pinEnseignant: j['pinEnseignant'] ?? '0000',
        seuilAbsences: j['seuilAbsences'] ?? 5,
        seuilsMentions: (j['seuilsMentions'] as Map?)
                ?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ??
            Map<String, double>.from(mentionsParDefaut),
      );
}

/// ------------------------------------------------------------- ENSEIGNANT
class Enseignant {
  String classe; // identifiant : un enseignant par classe
  String nomComplet;
  String telephone;
  String pin;

  Enseignant({required this.classe, this.nomComplet = '', this.telephone = '', this.pin = ''});

  Map<String, dynamic> toJson() =>
      {'classe': classe, 'nomComplet': nomComplet, 'telephone': telephone, 'pin': pin};

  factory Enseignant.fromJson(Map<String, dynamic> j) => Enseignant(
        classe: j['classe'],
        nomComplet: j['nomComplet'] ?? '',
        telephone: j['telephone'] ?? '',
        pin: j['pin'] ?? '',
      );
}

/// ------------------------------------------------------------------ ELEVE
class Eleve {
  String id;
  String matricule;
  String nom;
  String prenom;
  String sexe; // M / F
  DateTime? dateNaissance;
  String lieuNaissance;
  String classe;
  String photoBase64;
  String nomParent;
  String telParent;
  String adresse;
  bool actif;
  String statut; // INSCRIT / TRANSFERE / REDOUBLANT / PROMU
  String groupeNiveau; // Avance / Moyen / Difficulte
  String anneeScolaire;
  DateTime? dateDepart;
  String motifDepart;

  Eleve({
    String? id,
    this.matricule = '',
    required this.nom,
    required this.prenom,
    this.sexe = 'M',
    this.dateNaissance,
    this.lieuNaissance = '',
    required this.classe,
    this.photoBase64 = '',
    this.nomParent = '',
    this.telParent = '',
    this.adresse = '',
    this.actif = true,
    this.statut = 'INSCRIT',
    this.groupeNiveau = 'Moyen',
    this.anneeScolaire = '',
    this.dateDepart,
    this.motifDepart = '',
  }) : id = id ?? newId();

  String get nomComplet => '$nom $prenom'.trim();

  Map<String, dynamic> toJson() => {
        'id': id, 'matricule': matricule, 'nom': nom, 'prenom': prenom, 'sexe': sexe,
        'dateNaissance': dateNaissance?.toIso8601String(), 'lieuNaissance': lieuNaissance,
        'classe': classe, 'photoBase64': photoBase64, 'nomParent': nomParent,
        'telParent': telParent, 'adresse': adresse, 'actif': actif, 'statut': statut,
        'groupeNiveau': groupeNiveau, 'anneeScolaire': anneeScolaire,
        'dateDepart': dateDepart?.toIso8601String(), 'motifDepart': motifDepart,
      };

  factory Eleve.fromJson(Map<String, dynamic> j) => Eleve(
        id: j['id'],
        matricule: j['matricule'] ?? '',
        nom: j['nom'] ?? '',
        prenom: j['prenom'] ?? '',
        sexe: j['sexe'] ?? 'M',
        dateNaissance: j['dateNaissance'] == null ? null : DateTime.parse(j['dateNaissance']),
        lieuNaissance: j['lieuNaissance'] ?? '',
        classe: j['classe'] ?? 'CP1',
        photoBase64: j['photoBase64'] ?? '',
        nomParent: j['nomParent'] ?? '',
        telParent: j['telParent'] ?? '',
        adresse: j['adresse'] ?? '',
        actif: j['actif'] ?? true,
        statut: j['statut'] ?? 'INSCRIT',
        groupeNiveau: j['groupeNiveau'] ?? 'Moyen',
        anneeScolaire: j['anneeScolaire'] ?? '',
        dateDepart: j['dateDepart'] == null ? null : DateTime.parse(j['dateDepart']),
        motifDepart: j['motifDepart'] ?? '',
      );
}

/// ------------------------------------------------------------------- NOTE
class Note {
  String id;
  String eleveId;
  String classe;
  String matiere;
  String evaluation; // Eval 1..9
  double valeur; // sur 10
  String anneeScolaire;
  bool verrouillee;
  DateTime maj;

  Note({
    String? id,
    required this.eleveId,
    required this.classe,
    required this.matiere,
    required this.evaluation,
    required this.valeur,
    required this.anneeScolaire,
    this.verrouillee = false,
    DateTime? maj,
  })  : id = id ?? newId(),
        maj = maj ?? DateTime.now();

  String get cle => '$eleveId|$matiere|$evaluation|$anneeScolaire';

  Map<String, dynamic> toJson() => {
        'id': id, 'eleveId': eleveId, 'classe': classe, 'matiere': matiere,
        'evaluation': evaluation, 'valeur': valeur, 'anneeScolaire': anneeScolaire,
        'verrouillee': verrouillee, 'maj': maj.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        eleveId: j['eleveId'],
        classe: j['classe'],
        matiere: j['matiere'],
        evaluation: j['evaluation'],
        valeur: (j['valeur'] as num).toDouble(),
        anneeScolaire: j['anneeScolaire'] ?? '',
        verrouillee: j['verrouillee'] ?? false,
        maj: j['maj'] == null ? DateTime.now() : DateTime.parse(j['maj']),
      );
}

/// -------------------------------------------------------------- PRESENCE
class Presence {
  String id;
  String eleveId;
  String classe;
  DateTime date;
  bool present;
  bool justifiee;
  String motif;
  String anneeScolaire;

  Presence({
    String? id,
    required this.eleveId,
    required this.classe,
    required this.date,
    required this.present,
    this.justifiee = false,
    this.motif = '',
    this.anneeScolaire = '',
  }) : id = id ?? newId();

  static String jour(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get cle => '$eleveId|${jour(date)}';

  Map<String, dynamic> toJson() => {
        'id': id, 'eleveId': eleveId, 'classe': classe, 'date': date.toIso8601String(),
        'present': present, 'justifiee': justifiee, 'motif': motif, 'anneeScolaire': anneeScolaire,
      };

  factory Presence.fromJson(Map<String, dynamic> j) => Presence(
        id: j['id'], eleveId: j['eleveId'], classe: j['classe'],
        date: DateTime.parse(j['date']), present: j['present'] ?? true,
        justifiee: j['justifiee'] ?? false, motif: j['motif'] ?? '',
        anneeScolaire: j['anneeScolaire'] ?? '',
      );
}

/// ------------------------------------------------------------- APPRECIATION
class Appreciation {
  String eleveId;
  String periode; // Eval x ou Trimestre x
  String texte;
  String anneeScolaire;

  Appreciation({required this.eleveId, required this.periode, required this.texte, this.anneeScolaire = ''});

  Map<String, dynamic> toJson() =>
      {'eleveId': eleveId, 'periode': periode, 'texte': texte, 'anneeScolaire': anneeScolaire};

  factory Appreciation.fromJson(Map<String, dynamic> j) => Appreciation(
      eleveId: j['eleveId'], periode: j['periode'], texte: j['texte'] ?? '',
      anneeScolaire: j['anneeScolaire'] ?? '');
}

/// ------------------------------------------------------- CAHIER DE TEXTES
class SeanceCahier {
  String id;
  String classe;
  DateTime date;
  String matiere;
  String lecon;
  String resume;
  String exercices;
  String devoirs;
  String anneeScolaire;

  SeanceCahier({
    String? id, required this.classe, required this.date, required this.matiere,
    this.lecon = '', this.resume = '', this.exercices = '', this.devoirs = '',
    this.anneeScolaire = '',
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id, 'classe': classe, 'date': date.toIso8601String(), 'matiere': matiere,
        'lecon': lecon, 'resume': resume, 'exercices': exercices, 'devoirs': devoirs,
        'anneeScolaire': anneeScolaire,
      };

  factory SeanceCahier.fromJson(Map<String, dynamic> j) => SeanceCahier(
        id: j['id'], classe: j['classe'], date: DateTime.parse(j['date']),
        matiere: j['matiere'] ?? '', lecon: j['lecon'] ?? '', resume: j['resume'] ?? '',
        exercices: j['exercices'] ?? '', devoirs: j['devoirs'] ?? '',
        anneeScolaire: j['anneeScolaire'] ?? '',
      );
}

/// -------------------------------------------------------------- DEVOIRS
class Devoir {
  String id;
  String classe;
  String matiere;
  String titre;
  DateTime dateDonne;
  DateTime dateRemise;
  String anneeScolaire;
  Map<String, double?> notes; // eleveId -> note (null = non remis)

  Devoir({
    String? id, required this.classe, required this.matiere, required this.titre,
    required this.dateDonne, required this.dateRemise, this.anneeScolaire = '',
    Map<String, double?>? notes,
  })  : id = id ?? newId(),
        notes = notes ?? {};

  Map<String, dynamic> toJson() => {
        'id': id, 'classe': classe, 'matiere': matiere, 'titre': titre,
        'dateDonne': dateDonne.toIso8601String(), 'dateRemise': dateRemise.toIso8601String(),
        'anneeScolaire': anneeScolaire, 'notes': notes,
      };

  factory Devoir.fromJson(Map<String, dynamic> j) => Devoir(
        id: j['id'], classe: j['classe'], matiere: j['matiere'] ?? '', titre: j['titre'] ?? '',
        dateDonne: DateTime.parse(j['dateDonne']), dateRemise: DateTime.parse(j['dateRemise']),
        anneeScolaire: j['anneeScolaire'] ?? '',
        notes: (j['notes'] as Map?)?.map((k, v) => MapEntry(k as String, _d(v))) ?? {},
      );
}

/// --------------------------------------------------------- EMPLOI DU TEMPS
class CreneauEDT {
  String id;
  String classe;
  String jour; // Lundi..Samedi
  String debut;
  String fin;
  String matiere; // ou "Recreation"
  String anneeScolaire;

  CreneauEDT({
    String? id, required this.classe, required this.jour, required this.debut,
    required this.fin, required this.matiere, this.anneeScolaire = '',
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
        'id': id, 'classe': classe, 'jour': jour, 'debut': debut, 'fin': fin,
        'matiere': matiere, 'anneeScolaire': anneeScolaire,
      };

  factory CreneauEDT.fromJson(Map<String, dynamic> j) => CreneauEDT(
        id: j['id'], classe: j['classe'], jour: j['jour'], debut: j['debut'],
        fin: j['fin'], matiere: j['matiere'], anneeScolaire: j['anneeScolaire'] ?? '',
      );
}

/// ------------------------------------------------------------------ FRAIS
class Paiement {
  String id;
  String eleveId;
  String libelle; // Inscription, Mensualite Octobre...
  double montantDu;
  double montantPaye;
  DateTime date;
  String recu;
  String anneeScolaire;

  Paiement({
    String? id, required this.eleveId, required this.libelle, required this.montantDu,
    this.montantPaye = 0, DateTime? date, String? recu, this.anneeScolaire = '',
  })  : id = id ?? newId(),
        date = date ?? DateTime.now(),
        recu = recu ?? 'REC-${DateTime.now().millisecondsSinceEpoch}';

  double get reste => (montantDu - montantPaye).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id, 'eleveId': eleveId, 'libelle': libelle, 'montantDu': montantDu,
        'montantPaye': montantPaye, 'date': date.toIso8601String(), 'recu': recu,
        'anneeScolaire': anneeScolaire,
      };

  factory Paiement.fromJson(Map<String, dynamic> j) => Paiement(
        id: j['id'], eleveId: j['eleveId'], libelle: j['libelle'] ?? '',
        montantDu: (j['montantDu'] as num).toDouble(),
        montantPaye: (j['montantPaye'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(j['date']), recu: j['recu'],
        anneeScolaire: j['anneeScolaire'] ?? '',
      );
}

/// ------------------------------------------------------------ COMPORTEMENT
class Comportement {
  String id;
  String eleveId;
  DateTime date;
  String type; // Encouragement / Sanction / Observation
  String description;
  int discipline; // /10
  int participation; // /10
  String anneeScolaire;

  Comportement({
    String? id, required this.eleveId, DateTime? date, this.type = 'Observation',
    this.description = '', this.discipline = 8, this.participation = 8,
    this.anneeScolaire = '',
  })  : id = id ?? newId(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'eleveId': eleveId, 'date': date.toIso8601String(), 'type': type,
        'description': description, 'discipline': discipline,
        'participation': participation, 'anneeScolaire': anneeScolaire,
      };

  factory Comportement.fromJson(Map<String, dynamic> j) => Comportement(
        id: j['id'], eleveId: j['eleveId'], date: DateTime.parse(j['date']),
        type: j['type'] ?? 'Observation', description: j['description'] ?? '',
        discipline: j['discipline'] ?? 8, participation: j['participation'] ?? 8,
        anneeScolaire: j['anneeScolaire'] ?? '',
      );
}

/// ----------------------------------------------------------------- AUDIT
class AuditEntry {
  String id;
  DateTime date;
  String utilisateur;
  String action;
  String cible;
  String ancienneValeur;
  String nouvelleValeur;

  AuditEntry({
    String? id, DateTime? date, required this.utilisateur, required this.action,
    this.cible = '', this.ancienneValeur = '', this.nouvelleValeur = '',
  })  : id = id ?? newId(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'date': date.toIso8601String(), 'utilisateur': utilisateur,
        'action': action, 'cible': cible, 'ancienneValeur': ancienneValeur,
        'nouvelleValeur': nouvelleValeur,
      };

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'], date: DateTime.parse(j['date']), utilisateur: j['utilisateur'] ?? '',
        action: j['action'] ?? '', cible: j['cible'] ?? '',
        ancienneValeur: j['ancienneValeur'] ?? '', nouvelleValeur: j['nouvelleValeur'] ?? '',
      );
}

/// ------------------------------------------------- JOURNAL DE BORD DIRECTEUR
class JournalEntry {
  String id;
  DateTime date;
  String type; // Reunion / Decision / Evenement / Inspection / Observation
  String titre;
  String contenu;

  JournalEntry({
    String? id, DateTime? date, this.type = 'Observation', this.titre = '', this.contenu = '',
  })  : id = id ?? newId(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'date': date.toIso8601String(), 'type': type, 'titre': titre, 'contenu': contenu,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'], date: DateTime.parse(j['date']), type: j['type'] ?? '',
        titre: j['titre'] ?? '', contenu: j['contenu'] ?? '',
      );
}

/// ------------------------------------------------------------- DECISIONS
class DecisionFinale {
  String eleveId;
  String anneeScolaire;
  String classeOrigine;
  String decision; // ADMIS / REDOUBLE / TRANSFERE
  String classeDestination;
  bool manuelle;
  DateTime date;

  DecisionFinale({
    required this.eleveId, required this.anneeScolaire, required this.classeOrigine,
    required this.decision, this.classeDestination = '', this.manuelle = false, DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'eleveId': eleveId, 'anneeScolaire': anneeScolaire, 'classeOrigine': classeOrigine,
        'decision': decision, 'classeDestination': classeDestination,
        'manuelle': manuelle, 'date': date.toIso8601String(),
      };

  factory DecisionFinale.fromJson(Map<String, dynamic> j) => DecisionFinale(
        eleveId: j['eleveId'], anneeScolaire: j['anneeScolaire'],
        classeOrigine: j['classeOrigine'], decision: j['decision'],
        classeDestination: j['classeDestination'] ?? '', manuelle: j['manuelle'] ?? false,
        date: DateTime.parse(j['date']),
      );
}

/// -------------------------------------------------------------- BULLETIN
class BulletinMeta {
  String id;
  String eleveId;
  String periode;
  String anneeScolaire;
  String numeroAuthentification;
  DateTime date;

  BulletinMeta({
    String? id, required this.eleveId, required this.periode, required this.anneeScolaire,
    String? numeroAuthentification, DateTime? date,
  })  : id = id ?? newId(),
        numeroAuthentification = numeroAuthentification ??
            'BUL-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id, 'eleveId': eleveId, 'periode': periode, 'anneeScolaire': anneeScolaire,
        'numeroAuthentification': numeroAuthentification, 'date': date.toIso8601String(),
      };

  factory BulletinMeta.fromJson(Map<String, dynamic> j) => BulletinMeta(
        id: j['id'], eleveId: j['eleveId'], periode: j['periode'],
        anneeScolaire: j['anneeScolaire'],
        numeroAuthentification: j['numeroAuthentification'],
        date: DateTime.parse(j['date']),
      );
}

/// ---------------------------------------------------------------- ARCHIVE
class ArchiveAnnee {
  String anneeScolaire;
  DateTime dateCloture;
  Map<String, dynamic> donnees;

  ArchiveAnnee({required this.anneeScolaire, DateTime? dateCloture, required this.donnees})
      : dateCloture = dateCloture ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'anneeScolaire': anneeScolaire,
        'dateCloture': dateCloture.toIso8601String(),
        'donnees': donnees,
      };

  factory ArchiveAnnee.fromJson(Map<String, dynamic> j) => ArchiveAnnee(
        anneeScolaire: j['anneeScolaire'],
        dateCloture: DateTime.parse(j['dateCloture']),
        donnees: Map<String, dynamic>.from(j['donnees'] ?? {}),
      );
}

/// ------------------------------------------------------- RESULTAT CALCULE
class ResultatEleve {
  final Eleve eleve;
  final Map<String, double> moyennesParMatiere;
  final double total;
  final double moyenne;
  final int rang;
  final String mention;
  final int absences;

  ResultatEleve({
    required this.eleve,
    required this.moyennesParMatiere,
    required this.total,
    required this.moyenne,
    required this.rang,
    required this.mention,
    required this.absences,
  });
}
