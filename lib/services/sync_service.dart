import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../core/constants.dart';
import '../data/app_state.dart';
import '../models/models.dart';

/// Import / export de fichiers JSON entre enseignants et directeur.
/// Fonctionne 100% hors ligne, avec controle d'integrite SHA-256.
class SyncService {
  static const formatVersion = 1;

  static String checksum(Map<String, dynamic> payload) {
    final normalized = jsonEncode(_sorted(payload));
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static dynamic _sorted(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((e) => e.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return v.map(_sorted).toList();
    return v;
  }

  /// Export du paquet d'une classe (enseignant -> directeur).
  static Map<String, dynamic> exporterClasse(
    AppState s,
    String classe, {
    required String periode, // MENSUELLE / TRIMESTRIELLE / ANNUELLE
    bool inclurePhotos = true,
  }) {
    final eleves = s.eleves.where((e) => e.classe == classe && e.anneeScolaire == s.annee).toList();
    final ids = eleves.map((e) => e.id).toSet();

    final payload = <String, dynamic>{
      'classe': classe,
      'anneeScolaire': s.annee,
      'enseignant': s.enseignantDe(classe).toJson(),
      'ecole': {
        'nom': s.ecole.nom,
        'devise': s.ecole.devise,
        'adresse': s.ecole.adresse,
        'telephone': s.ecole.telephone,
        'email': s.ecole.email,
      },
      'eleves': eleves
          .map((e) => inclurePhotos
              ? e.toJson()
              : (e.toJson()..['photoBase64'] = ''))
          .toList(),
      'notes': s.notes.where((n) => ids.contains(n.eleveId)).map((e) => e.toJson()).toList(),
      'presences': s.presences.where((p) => ids.contains(p.eleveId)).map((e) => e.toJson()).toList(),
      'appreciations':
          s.appreciations.where((a) => ids.contains(a.eleveId)).map((e) => e.toJson()).toList(),
      'comportements':
          s.comportements.where((c) => ids.contains(c.eleveId)).map((e) => e.toJson()).toList(),
      'cahier': s.cahier.where((c) => c.classe == classe).map((e) => e.toJson()).toList(),
      'devoirs': s.devoirs.where((d) => d.classe == classe).map((e) => e.toJson()).toList(),
      'edt': s.edt.where((c) => c.classe == classe).map((e) => e.toJson()).toList(),
      'bulletins': s.bulletins.where((b) => ids.contains(b.eleveId)).map((e) => e.toJson()).toList(),
      'audit': s.audit.take(500).map((e) => e.toJson()).toList(),
      'statistiques': statistiquesClasse(s, classe),
    };

    final entete = {
      'identifiant': newId(),
      'formatVersion': formatVersion,
      'type': 'EXPORT_CLASSE',
      'classe': classe,
      'anneeScolaire': s.annee,
      'periode': periode,
      'dateCreation': DateTime.now().toIso8601String(),
      'enseignant': s.enseignantDe(classe).nomComplet,
      'photosIncluses': inclurePhotos,
    };

    return {'entete': entete, 'donnees': payload, 'checksum': checksum(payload)};
  }

  static Map<String, dynamic> statistiquesClasse(AppState s, String classe) {
    final eleves = s.eleves.where((e) => e.classe == classe && e.anneeScolaire == s.annee && e.actif);
    return {
      'effectif': eleves.length,
      'garcons': eleves.where((e) => e.sexe == 'M').length,
      'filles': eleves.where((e) => e.sexe == 'F').length,
    };
  }

  /// Verifie l'integrite d'un fichier importe.
  static (bool ok, String message) verifier(Map<String, dynamic> fichier) {
    if (!fichier.containsKey('entete') || !fichier.containsKey('donnees')) {
      return (false, "Structure de fichier invalide.");
    }
    final entete = Map<String, dynamic>.from(fichier['entete']);
    if (entete['formatVersion'] != formatVersion) {
      return (false, "Version de format non prise en charge (${entete['formatVersion']}).");
    }
    final calc = checksum(Map<String, dynamic>.from(fichier['donnees']));
    if (calc != fichier['checksum']) {
      return (false, "Fichier corrompu ou modifie : controle d'integrite echoue.");
    }
    return (true, "Fichier valide - classe ${entete['classe']}, "
        "annee ${entete['anneeScolaire']}, periode ${entete['periode']}.");
  }

  /// Fusion sans perte : mise a jour des existants, ajout des nouveaux.
  static Future<String> importerClasse(AppState s, Map<String, dynamic> fichier) async {
    final v = verifier(fichier);
    if (!v.$1) throw Exception(v.$2);

    await s.store.backup(s.toJson(), tag: 'avant-import');

    final d = Map<String, dynamic>.from(fichier['donnees']);
    final entete = Map<String, dynamic>.from(fichier['entete']);
    final classe = entete['classe'] as String;
    int nvEleves = 0, majEleves = 0, nvNotes = 0, majNotes = 0, nvPres = 0;

    // Enseignant
    if (d['enseignant'] != null) {
      final ens = Enseignant.fromJson(Map<String, dynamic>.from(d['enseignant']));
      final local = s.enseignantDe(classe);
      if (ens.nomComplet.isNotEmpty) local.nomComplet = ens.nomComplet;
      if (ens.telephone.isNotEmpty) local.telephone = ens.telephone;
    }

    // Eleves
    for (final raw in (d['eleves'] as List? ?? [])) {
      final e = Eleve.fromJson(Map<String, dynamic>.from(raw));
      final i = s.eleves.indexWhere((x) => x.id == e.id || (x.matricule.isNotEmpty && x.matricule == e.matricule));
      if (i >= 0) {
        final ancien = s.eleves[i];
        if (e.photoBase64.isEmpty) e.photoBase64 = ancien.photoBase64;
        s.eleves[i] = e;
        majEleves++;
      } else {
        s.eleves.add(e);
        nvEleves++;
      }
    }

    // Notes (deduplication par cle metier)
    // FAILLE CORRIGEE : l'import fusionnait aveuglement les notes d'un
    // fichier externe, sans revalider leur plage (0-10) ni respecter le
    // verrouillage de periode pose par le directeur (voir app_state.setNote).
    int noteRejetees = 0;
    final indexNotes = {for (final n in s.notes) n.cle: n};
    for (final raw in (d['notes'] as List? ?? [])) {
      final n = Note.fromJson(Map<String, dynamic>.from(raw));
      if (n.valeur < 0 || n.valeur > 10) {
        noteRejetees++;
        continue;
      }
      if (s.estVerrouille(n.classe, n.evaluation)) {
        noteRejetees++;
        continue;
      }
      final ex = indexNotes[n.cle];
      if (ex == null) {
        s.notes.add(n);
        indexNotes[n.cle] = n;
        nvNotes++;
      } else if (n.maj.isAfter(ex.maj)) {
        ex.valeur = n.valeur;
        ex.maj = n.maj;
        ex.verrouillee = ex.verrouillee || n.verrouillee;
        majNotes++;
      }
    }

    // Presences
    final indexPres = {for (final p in s.presences) p.cle: p};
    for (final raw in (d['presences'] as List? ?? [])) {
      final p = Presence.fromJson(Map<String, dynamic>.from(raw));
      final ex = indexPres[p.cle];
      if (ex == null) {
        s.presences.add(p);
        indexPres[p.cle] = p;
        nvPres++;
      } else {
        ex.present = p.present;
        ex.motif = p.motif;
        ex.justifiee = p.justifiee;
      }
    }

    // Appreciations
    for (final raw in (d['appreciations'] as List? ?? [])) {
      final a = Appreciation.fromJson(Map<String, dynamic>.from(raw));
      final i = s.appreciations.indexWhere((x) =>
          x.eleveId == a.eleveId && x.periode == a.periode && x.anneeScolaire == a.anneeScolaire);
      if (i >= 0) {
        s.appreciations[i] = a;
      } else {
        s.appreciations.add(a);
      }
    }

    void mergeById<T>(String key, List<T> target, T Function(Map<String, dynamic>) from,
        String Function(T) idOf) {
      final idx = {for (final t in target) idOf(t): t};
      for (final raw in (d[key] as List? ?? [])) {
        final o = from(Map<String, dynamic>.from(raw));
        final ex = idx[idOf(o)];
        if (ex == null) {
          target.add(o);
          idx[idOf(o)] = o;
        } else {
          target[target.indexOf(ex)] = o;
        }
      }
    }

    mergeById('comportements', s.comportements, Comportement.fromJson, (c) => c.id);
    mergeById('cahier', s.cahier, SeanceCahier.fromJson, (c) => c.id);
    mergeById('devoirs', s.devoirs, Devoir.fromJson, (c) => c.id);
    mergeById('edt', s.edt, CreneauEDT.fromJson, (c) => c.id);
    mergeById('bulletins', s.bulletins, BulletinMeta.fromJson, (c) => c.id);

    // s.notes / s.presences ont ete modifiees directement ci-dessus (hors
    // setNote/marquerPresence) : on reconstruit les index de recherche rapide.
    s.reindexerNotes();
    s.reindexerPresences();

    s.log('IMPORT_JSON',
        cible: 'Classe $classe (${entete['periode']})',
        apres: '$nvEleves nouveaux eleves, $majEleves maj, $nvNotes notes, $nvPres presences'
            '${noteRejetees > 0 ? ', $noteRejetees note(s) rejetee(s)' : ''}');
    await s.save();

    return "Import reussi - classe $classe :\n"
        "- $nvEleves nouvel(le)s eleve(s), $majEleves mis a jour\n"
        "- $nvNotes nouvelle(s) note(s), $majNotes mise(s) a jour\n"
        "- $nvPres presence(s) ajoutee(s)"
        "${noteRejetees > 0 ? '\n- $noteRejetees note(s) rejetee(s) (hors plage 0-10 ou periode verrouillee)' : ''}";
  }

  /// Sauvegarde complete de l'ecole.
  static Map<String, dynamic> exporterEcole(AppState s) {
    final donnees = s.toJson();
    return {
      'entete': {
        'identifiant': newId(),
        'formatVersion': formatVersion,
        'type': 'SAUVEGARDE_ECOLE',
        'anneeScolaire': s.annee,
        'periode': 'ANNUELLE',
        'dateCreation': DateTime.now().toIso8601String(),
        'ecole': s.ecole.nom,
      },
      'donnees': donnees,
      'checksum': checksum(donnees),
    };
  }

  static Future<String> restaurerEcole(AppState s, Map<String, dynamic> fichier) async {
    final v = verifier(fichier);
    if (!v.$1) throw Exception(v.$2);
    await s.remplacerParJson(Map<String, dynamic>.from(fichier['donnees']));
    return "Restauration complete effectuee.";
  }

  static String nomFichierClasse(String classe, String annee, String periode) {
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    return 'CLASSE_${classe}_${annee.replaceAll('/', '-')}_${periode}_$ts.json';
  }

  // -------------------------------------------------------- DONNEES DE TEST
  /// Remplit rapidement l'application avec des donnees de demonstration a
  /// partir d'un fichier JSON simple (sans l'enveloppe entete/checksum des
  /// echanges enseignant <-> directeur, voir [importerClasse]). Les eleves
  /// sont identifies par leur "matricule" (cree automatiquement s'il est
  /// absent) : les notes, presences, comportements et paiements y font
  /// reference plutot qu'a un identifiant technique, pour rester faciles a
  /// ecrire a la main. Voir [modeleDonneesTest] pour le format attendu.
  static Future<String> importerDonneesTest(AppState s, Map<String, dynamic> j) async {
    await s.store.backup(s.toJson(), tag: 'avant-import-test');

    int nvEleves = 0, majEleves = 0, nvNotes = 0, nvPres = 0, nvComp = 0;
    int nvCahier = 0, nvDevoirs = 0, nvEdt = 0, nvPaiements = 0, ignores = 0;

    final parMatricule = {for (final e in s.eleves) if (e.matricule.isNotEmpty) e.matricule: e.id};

    String? idDe(Map<String, dynamic> r) {
      final m = (r['matricule'] ?? '').toString();
      if (m.isNotEmpty && parMatricule.containsKey(m)) return parMatricule[m];
      final id = (r['eleveId'] ?? '').toString();
      if (id.isNotEmpty) return id;
      return null;
    }

    // Valide qu'une salle correspond a un niveau pedagogique connu
    // (CP1..CM2, avec ou sans section : "CM2", "CM2 A", "CM2 B"...) et
    // l'ajoute automatiquement a la liste des salles de l'ecole si elle
    // n'existe pas encore (permet d'importer directement plusieurs sections
    // par niveau, ex: "CP1 A", "CP1 B", "CP1 C", sans avoir a les creer
    // manuellement au prealable dans Configuration de l'ecole).
    bool classeValide(String classe) {
      if (classe.isEmpty || !Classes.all.contains(Classes.niveauDe(classe))) return false;
      if (!s.salles.contains(classe)) s.salles.add(classe);
      return true;
    }

    for (final raw in (j['eleves'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final classe = (r['classe'] ?? '').toString();
      if (!classeValide(classe)) {
        ignores++;
        continue;
      }
      final matriculeVoulu = (r['matricule'] ?? '').toString();
      final existantId = matriculeVoulu.isNotEmpty ? parMatricule[matriculeVoulu] : null;
      if (existantId != null) {
        final e = s.eleveParId(existantId)!;
        e.nom = r['nom'] ?? e.nom;
        e.prenom = r['prenom'] ?? e.prenom;
        e.sexe = r['sexe'] ?? e.sexe;
        e.classe = classe;
        majEleves++;
      } else {
        final e = Eleve(
          nom: r['nom'] ?? '',
          prenom: r['prenom'] ?? '',
          sexe: r['sexe'] ?? 'M',
          classe: classe,
          nomParent: r['nomParent'] ?? '',
          telParent: r['telParent'] ?? '',
          adresse: r['adresse'] ?? '',
          groupeNiveau: r['groupeNiveau'] ?? 'Moyen',
          matricule: matriculeVoulu,
        );
        e.anneeScolaire = s.annee;
        if (e.matricule.isEmpty) e.matricule = s.genererMatricule(classe);
        s.eleves.add(e);
        parMatricule[e.matricule] = e.id;
        nvEleves++;
      }
    }

    for (final raw in (j['notes'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final eleveId = idDe(r);
      final classe = eleveId == null ? null : s.eleveParId(eleveId)?.classe;
      final valeur = (r['valeur'] as num?)?.toDouble();
      if (eleveId == null || classe == null || valeur == null || valeur < 0 || valeur > 10) {
        ignores++;
        continue;
      }
      s.setNote(eleveId, classe, r['matiere'] ?? '', r['evaluation'] ?? '', valeur,
          forcer: true, sauvegarder: false);
      nvNotes++;
    }

    for (final raw in (j['presences'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final eleveId = idDe(r);
      final classe = eleveId == null ? null : s.eleveParId(eleveId)?.classe;
      if (eleveId == null || classe == null || r['date'] == null) {
        ignores++;
        continue;
      }
      await s.marquerPresence(eleveId, classe, DateTime.parse(r['date']), r['present'] ?? true,
          motif: r['motif'] ?? '', justifiee: r['justifiee'] ?? false, sauvegarder: false);
      nvPres++;
    }

    for (final raw in (j['comportements'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final eleveId = idDe(r);
      if (eleveId == null) {
        ignores++;
        continue;
      }
      s.comportements.add(Comportement(
        eleveId: eleveId,
        type: r['type'] ?? 'Observation',
        description: r['description'] ?? '',
        discipline: r['discipline'] ?? 8,
        participation: r['participation'] ?? 8,
        anneeScolaire: s.annee,
      ));
      nvComp++;
    }

    for (final raw in (j['paiements'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final eleveId = idDe(r);
      final montantDu = (r['montantDu'] as num?)?.toDouble();
      if (eleveId == null || montantDu == null) {
        ignores++;
        continue;
      }
      s.paiements.add(Paiement(
        eleveId: eleveId,
        libelle: r['libelle'] ?? '',
        montantDu: montantDu,
        montantPaye: (r['montantPaye'] as num?)?.toDouble() ?? 0,
        anneeScolaire: s.annee,
      ));
      nvPaiements++;
    }

    for (final raw in (j['cahier'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final classe = (r['classe'] ?? '').toString();
      if (!classeValide(classe) || r['date'] == null) {
        ignores++;
        continue;
      }
      s.cahier.add(SeanceCahier(
        classe: classe,
        date: DateTime.parse(r['date']),
        matiere: r['matiere'] ?? '',
        lecon: r['lecon'] ?? '',
        resume: r['resume'] ?? '',
        exercices: r['exercices'] ?? '',
        devoirs: r['devoirs'] ?? '',
        anneeScolaire: s.annee,
      ));
      nvCahier++;
    }

    for (final raw in (j['devoirs'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final classe = (r['classe'] ?? '').toString();
      if (!classeValide(classe) || r['dateDonne'] == null || r['dateRemise'] == null) {
        ignores++;
        continue;
      }
      s.devoirs.add(Devoir(
        classe: classe,
        matiere: r['matiere'] ?? '',
        titre: r['titre'] ?? '',
        dateDonne: DateTime.parse(r['dateDonne']),
        dateRemise: DateTime.parse(r['dateRemise']),
        anneeScolaire: s.annee,
      ));
      nvDevoirs++;
    }

    for (final raw in (j['edt'] as List? ?? [])) {
      final r = Map<String, dynamic>.from(raw);
      final classe = (r['classe'] ?? '').toString();
      if (!classeValide(classe)) {
        ignores++;
        continue;
      }
      s.edt.add(CreneauEDT(
        classe: classe,
        jour: r['jour'] ?? 'Lundi',
        debut: r['debut'] ?? '08:00',
        fin: r['fin'] ?? '09:00',
        matiere: r['matiere'] ?? '',
        anneeScolaire: s.annee,
      ));
      nvEdt++;
    }

    s.log('IMPORT_DONNEES_TEST',
        apres: '$nvEleves eleve(s), $majEleves maj, $nvNotes note(s), $nvPres presence(s), '
            '$nvComp comportement(s), $nvPaiements paiement(s), $nvCahier seance(s), '
            '$nvDevoirs devoir(s), $nvEdt creneau(x)'
            '${ignores > 0 ? ", $ignores ligne(s) ignoree(s)" : ""}');
    await s.save();

    return 'Donnees de test importees :\n'
        '- $nvEleves nouvel(le)s eleve(s), $majEleves mis a jour\n'
        '- $nvNotes note(s), $nvPres presence(s), $nvComp comportement(s)\n'
        '- $nvPaiements paiement(s), $nvCahier seance(s) de cahier, $nvDevoirs devoir(s), $nvEdt creneau(x) EDT'
        '${ignores > 0 ? '\n- $ignores ligne(s) ignoree(s) (classe/eleve/valeur invalide)' : ''}';
  }

  /// Exemple de fichier de donnees de test, telechargeable depuis les
  /// parametres pour montrer le format attendu.
  static Map<String, dynamic> modeleDonneesTest() => {
        'eleves': [
          {'matricule': 'TEST-CP1-001', 'nom': 'Kone', 'prenom': 'Awa', 'sexe': 'F', 'classe': 'CP1'},
          {'matricule': 'TEST-CP1-002', 'nom': 'Traore', 'prenom': 'Ismael', 'sexe': 'M', 'classe': 'CP1'},
        ],
        'notes': [
          {'matricule': 'TEST-CP1-001', 'matiere': 'Lecture', 'evaluation': 'Eval 1', 'valeur': 8.5},
          {'matricule': 'TEST-CP1-002', 'matiere': 'Lecture', 'evaluation': 'Eval 1', 'valeur': 6},
        ],
        'presences': [
          {'matricule': 'TEST-CP1-001', 'date': '2026-09-08', 'present': true},
          {'matricule': 'TEST-CP1-002', 'date': '2026-09-08', 'present': false, 'motif': 'Maladie'},
        ],
        'comportements': [
          {
            'matricule': 'TEST-CP1-001',
            'type': 'Encouragement',
            'description': 'Tres bonne participation',
            'discipline': 9,
            'participation': 9,
          },
        ],
        'paiements': [
          {'matricule': 'TEST-CP1-001', 'libelle': 'Inscription', 'montantDu': 25000, 'montantPaye': 25000},
        ],
      };
}
