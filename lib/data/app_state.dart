import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/calcul_service.dart';
import 'local_store.dart';

enum Profil { aucun, directeur, enseignant }

/// Etat global de l'application : contient toutes les donnees de l'ecole,
/// persistees localement en JSON.
class AppState extends ChangeNotifier {
  final LocalStore store = LocalStore();

  Ecole ecole = Ecole();
  List<Enseignant> enseignants = [];
  List<Eleve> eleves = [];
  List<Note> notes = [];
  List<Presence> presences = [];
  List<Appreciation> appreciations = [];
  List<SeanceCahier> cahier = [];
  List<Devoir> devoirs = [];
  List<CreneauEDT> edt = [];
  List<Paiement> paiements = [];
  List<Comportement> comportements = [];
  List<AuditEntry> audit = [];
  List<JournalEntry> journal = [];
  List<DecisionFinale> decisions = [];
  List<BulletinMeta> bulletins = [];
  List<ArchiveAnnee> archives = [];
  Set<String> periodesVerrouillees = {}; // "classe|periode|annee"

  /// Liste des salles/classes reellement ouvertes dans l'ecole (ex :
  /// ['CP1 A', 'CP1 B', 'CP2', 'CE1', ...]). Par defaut (nouvelle
  /// installation ou ancienne sauvegarde sans ce champ), une seule salle par
  /// niveau pedagogique (voir Classes.all). Le directeur peut ensuite
  /// dupliquer/ajouter/renommer/supprimer des salles (ecran de configuration).
  List<String> salles = List<String>.from(Classes.all);

  // Index de recherche rapide (cle -> objet), reconstruits au chargement et
  // maintenus a jour a chaque ajout/suppression. Indispensable des que
  // l'ecole accumule plusieurs centaines/milliers de notes ou presences
  // (ex: import massif de donnees de test sur une annee scolaire complete) :
  // sans cela, chaque saisie devrait relire toute la liste (cout croissant
  // au fur et a mesure que les listes grossissent).
  final Map<String, Note> _indexNotes = {};
  final Map<String, Presence> _indexPresences = {};

  /// A appeler apres toute modification directe des listes [notes] ou
  /// [presences] qui ne passe pas par [setNote] / [marquerPresence]
  /// (ex : import complet, fusion entre classes).
  void reindexerNotes() {
    _indexNotes
      ..clear()
      ..addEntries(notes.map((n) => MapEntry(n.cle, n)));
  }

  void reindexerPresences() {
    _indexPresences
      ..clear()
      ..addEntries(presences.map((p) => MapEntry(p.cle, p)));
  }

  Profil profil = Profil.aucun;
  String classeActive = 'CP1';
  bool chargement = true;

  String get annee => ecole.anneeScolaire;
  bool get estDirecteur => profil == Profil.directeur;

  String get utilisateurCourant => profil == Profil.directeur
      ? 'Directeur (${ecole.nomDirecteur.isEmpty ? "-" : ecole.nomDirecteur})'
      : 'Enseignant ${enseignantDe(classeActive).nomComplet} [$classeActive]';

  // ------------------------------------------------------------ CHARGEMENT
  Future<void> init() async {
    final data = await store.read();
    if (data != null) _fromJson(data);
    chargement = false;
    notifyListeners();
  }

  Future<void> save({bool backup = false, String tag = 'auto'}) async {
    final data = toJson();
    if (backup) await store.backup(data, tag: tag);
    await store.write(data);
    notifyListeners();
  }

  // ------------------------------------------------------- SERIALISATION
  Map<String, dynamic> toJson() => {
        'version': 1,
        'ecole': ecole.toJson(),
        'enseignants': enseignants.map((e) => e.toJson()).toList(),
        'eleves': eleves.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'presences': presences.map((e) => e.toJson()).toList(),
        'appreciations': appreciations.map((e) => e.toJson()).toList(),
        'cahier': cahier.map((e) => e.toJson()).toList(),
        'devoirs': devoirs.map((e) => e.toJson()).toList(),
        'edt': edt.map((e) => e.toJson()).toList(),
        'paiements': paiements.map((e) => e.toJson()).toList(),
        'comportements': comportements.map((e) => e.toJson()).toList(),
        'audit': audit.map((e) => e.toJson()).toList(),
        'journal': journal.map((e) => e.toJson()).toList(),
        'decisions': decisions.map((e) => e.toJson()).toList(),
        'bulletins': bulletins.map((e) => e.toJson()).toList(),
        'archives': archives.map((e) => e.toJson()).toList(),
        'periodesVerrouillees': periodesVerrouillees.toList(),
        'salles': salles,
      };

  void _fromJson(Map<String, dynamic> j) {
    ecole = Ecole.fromJson(Map<String, dynamic>.from(j['ecole'] ?? {}));
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(Map<String, dynamic>.from(e))).toList();
    enseignants = l('enseignants', Enseignant.fromJson);
    eleves = l('eleves', Eleve.fromJson);
    notes = l('notes', Note.fromJson);
    presences = l('presences', Presence.fromJson);
    appreciations = l('appreciations', Appreciation.fromJson);
    cahier = l('cahier', SeanceCahier.fromJson);
    devoirs = l('devoirs', Devoir.fromJson);
    edt = l('edt', CreneauEDT.fromJson);
    paiements = l('paiements', Paiement.fromJson);
    comportements = l('comportements', Comportement.fromJson);
    audit = l('audit', AuditEntry.fromJson);
    journal = l('journal', JournalEntry.fromJson);
    decisions = l('decisions', DecisionFinale.fromJson);
    bulletins = l('bulletins', BulletinMeta.fromJson);
    archives = l('archives', ArchiveAnnee.fromJson);
    periodesVerrouillees = ((j['periodesVerrouillees'] as List?) ?? []).map((e) => e.toString()).toSet();
    salles = ((j['salles'] as List?) ?? []).map((e) => e.toString()).toList();
    if (salles.isEmpty) salles = List<String>.from(Classes.all);
    reindexerNotes();
    reindexerPresences();
  }

  Future<void> remplacerParJson(Map<String, dynamic> j) async {
    await store.backup(toJson(), tag: 'avant-restauration');
    _fromJson(j);
    await save();
  }

  String exportJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  // ------------------------------------------------------------- SESSION
  void connecterDirecteur() {
    profil = Profil.directeur;
    log('CONNEXION', cible: 'Directeur');
    notifyListeners();
  }

  void connecterEnseignant(String classe) {
    profil = Profil.enseignant;
    classeActive = classe;
    log('CONNEXION', cible: 'Enseignant $classe');
    notifyListeners();
  }

  void deconnecter() {
    profil = Profil.aucun;
    notifyListeners();
  }

  // ------------------------------------------------------------- AUDIT
  void log(String action, {String cible = '', String avant = '', String apres = ''}) {
    audit.insert(
      0,
      AuditEntry(
        utilisateur: profil == Profil.aucun ? 'Systeme' : utilisateurCourant,
        action: action,
        cible: cible,
        ancienneValeur: avant,
        nouvelleValeur: apres,
      ),
    );
    if (audit.length > 5000) audit.removeRange(5000, audit.length);
  }

  // -------------------------------------------------------- ENSEIGNANTS
  Enseignant enseignantDe(String classe) {
    return enseignants.firstWhere(
      (e) => e.classe == classe,
      orElse: () {
        final n = Enseignant(classe: classe);
        enseignants.add(n);
        return n;
      },
    );
  }

  Future<void> setEnseignant(String classe, String nom, {String tel = '', String pin = ''}) async {
    final e = enseignantDe(classe);
    final avant = e.nomComplet;
    e.nomComplet = nom;
    if (tel.isNotEmpty) e.telephone = tel;
    if (pin.isNotEmpty) e.pin = pin;
    log('MAJ_ENSEIGNANT', cible: classe, avant: avant, apres: nom);
    await save();
  }

  // -------------------------------------------------------------- ELEVES
  List<Eleve> elevesDe(String classe, {bool actifsSeulement = true}) => eleves
      .where((e) =>
          e.classe == classe &&
          e.anneeScolaire == annee &&
          (!actifsSeulement || e.actif))
      .toList()
    ..sort((a, b) => a.nomComplet.toLowerCase().compareTo(b.nomComplet.toLowerCase()));

  List<Eleve> get elevesAnnee =>
      eleves.where((e) => e.anneeScolaire == annee && e.actif).toList();

  Eleve? eleveParId(String id) {
    for (final e in eleves) {
      if (e.id == id) return e;
    }
    return null;
  }

  String genererMatricule(String classe) {
    final an = annee.split('-').first;
    final cle = classe.replaceAll(' ', '');
    final n = eleves.where((e) => e.matricule.startsWith('$an-$cle-')).length + 1;
    var mat = '$an-$cle-${n.toString().padLeft(3, '0')}';
    var i = n;
    while (eleves.any((e) => e.matricule == mat)) {
      i++;
      mat = '$an-$cle-${i.toString().padLeft(3, '0')}';
    }
    return mat;
  }

  Future<void> ajouterEleve(Eleve e) async {
    e.anneeScolaire = annee;
    if (e.matricule.isEmpty) e.matricule = genererMatricule(e.classe);
    eleves.add(e);
    log('AJOUT_ELEVE', cible: e.nomComplet, apres: e.matricule);
    await save();
  }

  Future<void> majEleve(Eleve e) async {
    final i = eleves.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      log('MAJ_ELEVE', cible: e.nomComplet, avant: eleves[i].nomComplet, apres: e.nomComplet);
      eleves[i] = e;
    }
    await save();
  }

  Future<void> supprimerEleve(String id) async {
    final e = eleveParId(id);
    eleves.removeWhere((x) => x.id == id);
    notes.removeWhere((n) => n.eleveId == id);
    presences.removeWhere((p) => p.eleveId == id);
    reindexerNotes();
    reindexerPresences();
    log('SUPPRESSION_ELEVE', cible: e?.nomComplet ?? id);
    await save(backup: true, tag: 'suppr-eleve');
  }

  Future<void> transfererEleve(String id, String motif) async {
    final e = eleveParId(id);
    if (e == null) return;
    e.actif = false;
    e.statut = 'TRANSFERE';
    e.dateDepart = DateTime.now();
    e.motifDepart = motif;
    log('TRANSFERT_ELEVE', cible: e.nomComplet, apres: motif);
    await save();
  }

  List<Eleve> rechercher(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return [];
    return eleves
        .where((e) =>
            e.nom.toLowerCase().contains(s) ||
            e.prenom.toLowerCase().contains(s) ||
            e.matricule.toLowerCase().contains(s))
        .toList();
  }

  // --------------------------------------------------------------- NOTES
  bool estVerrouille(String classe, String periode) =>
      periodesVerrouillees.contains('$classe|$periode|$annee');

  Future<void> basculerVerrou(String classe, String periode) async {
    final k = '$classe|$periode|$annee';
    if (periodesVerrouillees.contains(k)) {
      periodesVerrouillees.remove(k);
      log('DEVERROUILLAGE_NOTES', cible: k);
    } else {
      periodesVerrouillees.add(k);
      log('VERROUILLAGE_NOTES', cible: k);
    }
    await save();
  }

  Note? note(String eleveId, String matiere, String evaluation) =>
      _indexNotes['$eleveId|$matiere|$evaluation|$annee'];

  /// Retourne false (et n'enregistre rien) si la note est hors plage ou si
  /// la periode/evaluation est verrouillee pour un profil non-directeur.
  /// FAILLE CORRIGEE : ces deux controles n'existaient qu'au niveau de
  /// l'ecran de saisie (UI). Un import de fichier JSON externe (voir
  /// sync_service.dart) pouvait donc injecter une note hors plage ou
  /// modifier une periode verrouillee sans passer par cet ecran.
  ///
  /// [sauvegarder] : mettre a false lors d'un import en masse (des centaines
  /// ou milliers de notes) pour eviter de reecrire tout le fichier de
  /// donnees a chaque note ajoutee. Dans ce cas, l'appelant doit lui-meme
  /// appeler `save()` une seule fois a la fin de l'import.
  bool setNote(String eleveId, String classe, String matiere, String evaluation, double? valeur,
      {bool forcer = false, bool sauvegarder = true}) {
    if (valeur != null && (valeur < 0 || valeur > 10)) return false;
    if (!forcer && estVerrouille(classe, evaluation) && profil != Profil.directeur) return false;
    _appliquerNote(eleveId, classe, matiere, evaluation, valeur);
    if (sauvegarder) save();
    return true;
  }

  void _appliquerNote(String eleveId, String classe, String matiere, String evaluation, double? valeur) {
    final existante = note(eleveId, matiere, evaluation);
    if (valeur == null) {
      if (existante != null) {
        notes.remove(existante);
        _indexNotes.remove(existante.cle);
        log('SUPPR_NOTE', cible: '$matiere/$evaluation', avant: existante.valeur.toString());
      }
    } else if (existante != null) {
      log('MAJ_NOTE',
          cible: '${eleveParId(eleveId)?.nomComplet} $matiere/$evaluation',
          avant: existante.valeur.toStringAsFixed(2),
          apres: valeur.toStringAsFixed(2));
      existante.valeur = valeur;
      existante.maj = DateTime.now();
    } else {
      final n = Note(
        eleveId: eleveId, classe: classe, matiere: matiere,
        evaluation: evaluation, valeur: valeur, anneeScolaire: annee,
      );
      notes.add(n);
      _indexNotes[n.cle] = n;
      log('SAISIE_NOTE',
          cible: '${eleveParId(eleveId)?.nomComplet} $matiere/$evaluation',
          apres: valeur.toStringAsFixed(2));
    }
  }

  List<Note> notesDe(String eleveId, {String? periode}) => notes
      .where((n) =>
          n.eleveId == eleveId &&
          n.anneeScolaire == annee &&
          (periode == null || CalculService.evaluationsDePeriode(periode).contains(n.evaluation)))
      .toList();

  // ----------------------------------------------------------- PRESENCES
  Presence? presence(String eleveId, DateTime jour) =>
      _indexPresences['$eleveId|${Presence.jour(jour)}'];

  /// [sauvegarder] : mettre a false lors d'un import en masse, voir [setNote].
  Future<void> marquerPresence(String eleveId, String classe, DateTime jour, bool present,
      {String motif = '', bool justifiee = false, bool sauvegarder = true}) async {
    final ex = presence(eleveId, jour);
    if (ex != null) {
      ex.present = present;
      ex.motif = motif;
      ex.justifiee = justifiee;
    } else {
      final p = Presence(
        eleveId: eleveId, classe: classe, date: jour, present: present,
        motif: motif, justifiee: justifiee, anneeScolaire: annee,
      );
      presences.add(p);
      _indexPresences[p.cle] = p;
    }
    if (sauvegarder) await save();
  }

  // NOTE : ce calcul est un cumul sur l'ANNEE entiere. Le parametre
  // `periode` n'est pas utilise : aucune date de debut/fin de trimestre
  // n'est stockee dans le modele (Presence n'a qu'une date, sans lien vers
  // une periode/evaluation), il n'est donc pas possible de filtrer les
  // absences par trimestre sans ajouter cette donnee. Voir l'affichage
  // "Absences (cumul annee)" dans les bulletins (pdf_service.dart).
  int absencesDe(String eleveId, {String? periode}) => presences
      .where((p) =>
          p.eleveId == eleveId &&
          !p.present &&
          p.anneeScolaire == annee)
      .length;

  double tauxPresence(String eleveId) {
    final l = presences.where((p) => p.eleveId == eleveId && p.anneeScolaire == annee).toList();
    if (l.isEmpty) return 100;
    return l.where((p) => p.present).length * 100 / l.length;
  }

  // ------------------------------------------------------- APPRECIATIONS
  String appreciationDe(String eleveId, String periode) {
    for (final a in appreciations) {
      if (a.eleveId == eleveId && a.periode == periode && a.anneeScolaire == annee) return a.texte;
    }
    return '';
  }

  Future<void> setAppreciation(String eleveId, String periode, String texte) async {
    final i = appreciations.indexWhere(
        (a) => a.eleveId == eleveId && a.periode == periode && a.anneeScolaire == annee);
    if (i >= 0) {
      appreciations[i].texte = texte;
    } else {
      appreciations.add(Appreciation(
          eleveId: eleveId, periode: periode, texte: texte, anneeScolaire: annee));
    }
    await save();
  }

  // ------------------------------------------------------------ ARCHIVES
  Future<void> cloturerAnnee(String nouvelleAnnee) async {
    archives.add(ArchiveAnnee(anneeScolaire: annee, donnees: toJson()));
    log('CLOTURE_ANNEE', cible: annee, apres: nouvelleAnnee);
    ecole.anneeScolaire = nouvelleAnnee;
    await save(backup: true, tag: 'cloture');
  }

  // ------------------------------------------------------------ CLASSES
  List<String> get classesAccessibles => estDirecteur ? salles : [classeActive];

  /// Salles deja ouvertes pour un niveau donne (ex: niveau 'CP1' ->
  /// ['CP1 A', 'CP1 B'] si ces deux salles existent), triees.
  List<String> sallesDuNiveau(String niveau) =>
      salles.where((s) => Classes.niveauDe(s) == niveau).toList()..sort();

  /// Ajoute une nouvelle salle pour un niveau donne. Si [section] est vide,
  /// la salle porte simplement le nom du niveau (ex: 'CP1'), sinon
  /// "niveau section" (ex: 'CP1 B'). Retourne false si le nom existe deja.
  Future<bool> ajouterSalle(String niveau, {String section = ''}) async {
    final nom = section.trim().isEmpty ? niveau : '$niveau ${section.trim()}';
    if (salles.contains(nom)) return false;
    salles.add(nom);
    log('AJOUT_SALLE', apres: nom);
    await save();
    return true;
  }

  /// Duplique une salle existante : cree une nouvelle salle du meme niveau
  /// pedagogique (ex: dupliquer 'CP1 A' -> propose 'CP1 B'), sans eleves
  /// (les eleves ne sont pas copies, seule la salle/section est creee).
  /// Suggere automatiquement la prochaine lettre disponible si [section]
  /// n'est pas precisee.
  Future<String?> dupliquerSalle(String source, {String? section}) async {
    final niveau = Classes.niveauDe(source);
    String sec = section?.trim() ?? '';
    if (sec.isEmpty) {
      const lettres = 'ABCDEFGHIJ';
      for (final l in lettres.split('')) {
        if (!salles.contains('$niveau $l')) {
          sec = l;
          break;
        }
      }
      if (sec.isEmpty) return null; // plus de lettre disponible (>10 sections)
    }
    final ok = await ajouterSalle(niveau, section: sec);
    return ok ? (sec.isEmpty ? niveau : '$niveau $sec') : null;
  }

  /// Renomme une salle et met a jour toutes les donnees qui y font
  /// reference (eleves, notes, presences, cahier, devoirs, edt, enseignant,
  /// verrous de periode, decisions de promotion).
  Future<bool> renommerSalle(String ancien, String nouveau) async {
    nouveau = nouveau.trim();
    if (nouveau.isEmpty || nouveau == ancien) return false;
    if (salles.contains(nouveau)) return false;
    final i = salles.indexOf(ancien);
    if (i < 0) return false;
    salles[i] = nouveau;
    for (final e in eleves) {
      if (e.classe == ancien) e.classe = nouveau;
    }
    for (final n in notes) {
      if (n.classe == ancien) n.classe = nouveau;
    }
    for (final p in presences) {
      if (p.classe == ancien) p.classe = nouveau;
    }
    for (final c in cahier) {
      if (c.classe == ancien) c.classe = nouveau;
    }
    for (final d in devoirs) {
      if (d.classe == ancien) d.classe = nouveau;
    }
    for (final c in edt) {
      if (c.classe == ancien) c.classe = nouveau;
    }
    for (final en in enseignants) {
      if (en.classe == ancien) en.classe = nouveau;
    }
    for (final d in decisions) {
      if (d.classeOrigine == ancien) d.classeOrigine = nouveau;
      if (d.classeDestination == ancien) d.classeDestination = nouveau;
    }
    periodesVerrouillees = periodesVerrouillees.map((k) {
      final parts = k.split('|');
      if (parts.isNotEmpty && parts[0] == ancien) {
        parts[0] = nouveau;
        return parts.join('|');
      }
      return k;
    }).toSet();
    if (classeActive == ancien) classeActive = nouveau;
    reindexerNotes();
    reindexerPresences();
    log('RENOMMAGE_SALLE', avant: ancien, apres: nouveau);
    await save();
    return true;
  }

  /// Supprime une salle. Refuse (retourne false) si des eleves y sont
  /// encore inscrits, pour eviter de perdre la trace de leurs donnees.
  Future<bool> supprimerSalle(String nom) async {
    if (elevesDe(nom, actifsSeulement: false).isNotEmpty) return false;
    salles.remove(nom);
    enseignants.removeWhere((e) => e.classe == nom);
    log('SUPPRESSION_SALLE', cible: nom);
    await save();
    return true;
  }
}
