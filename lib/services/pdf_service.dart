import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/constants.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import 'alerte_service.dart';
import 'calcul_service.dart';

/// Generation de tous les documents PDF (bulletins, deliberation, registres,
/// statistiques, documents administratifs, dossier d'inspection).
class PdfService {
  static final _df = DateFormat('dd/MM/yyyy');

  static const green = PdfColor.fromInt(0xFF075E54);
  static const light = PdfColor.fromInt(0xFFDCF8C6);
  static const greyBg = PdfColor.fromInt(0xFFECE5DD);

  static Future<pw.Document> _nouveauDocument() async {
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.notoSansRegular(),
        bold: await PdfGoogleFonts.notoSansBold(),
      ),
    );
  }

  static pw.MemoryImage? _img(String b64) {
    if (b64.isEmpty) return null;
    try {
      return pw.MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- ENTETE
  static pw.Widget _entete(AppState s, String titre, {String sousTitre = ''}) {
    final logo = _img(s.ecole.logoBase64);
    return pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 60, height: 60,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: green, width: .5)),
          child: logo != null
              ? pw.Image(logo, fit: pw.BoxFit.contain)
              : pw.Center(child: pw.Text('LOGO', style: const pw.TextStyle(fontSize: 8))),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text(s.ecole.nom.toUpperCase(),
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: green)),
            if (s.ecole.devise.isNotEmpty)
              pw.Text(s.ecole.devise, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            pw.Text(
                [s.ecole.adresse, s.ecole.telephone, s.ecole.email].where((e) => e.isNotEmpty).join(' | '),
                style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 3),
            pw.Text('Annee scolaire : ${s.ecole.anneeScolaire}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        pw.SizedBox(width: 60),
      ]),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        color: green,
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Center(
          child: pw.Text(titre.toUpperCase(),
              style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
      ),
      if (sousTitre.isNotEmpty)
        pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(sousTitre, style: const pw.TextStyle(fontSize: 10))),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _signatures(AppState s, {String gauche = "Le Maitre / La Maitresse"}) {
    final sign = _img(s.ecole.signatureBase64);
    final cachet = _img(s.ecole.cachetBase64);
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _bloc(gauche, null),
      _bloc('Cachet de l\'ecole', cachet),
      _bloc('Le Directeur', sign),
    ]);
  }

  static pw.Widget _bloc(String titre, pw.MemoryImage? image) => pw.Container(
        width: 150,
        child: pw.Column(children: [
          pw.Text(titre, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Container(
            height: 55,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: .5)),
            child: image != null
                ? pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Image(image, fit: pw.BoxFit.contain))
                : pw.SizedBox(),
          ),
        ]),
      );

  static pw.Widget _pied(AppState s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
            'Document genere le ${_df.format(DateTime.now())} - ${s.ecole.nom} - Application 100% hors ligne',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      );

  static pw.TableRow _tr(List<String> cells,
      {bool header = false, PdfColor? bg}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg ?? (header ? light : null)),
      children: [
        for (final c in cells)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: pw.Text(c,
                style: pw.TextStyle(
                    fontSize: header ? 8 : 8,
                    fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
          )
      ],
    );
  }

  // ----------------------------------------------------------- BULLETINS
  static Future<Uint8List> bulletins(AppState s, String classe, String periode,
      {List<String>? eleveIds}) async {
    final doc = await _nouveauDocument();
    final resultats = CalculService.resultatsClasse(s, classe, periode);
    final filtres = eleveIds == null
        ? resultats
        : resultats.where((r) => eleveIds.contains(r.eleve.id)).toList();
    final moyMax = resultats.isEmpty ? 0.0 : resultats.first.moyenne;
    final moyMin = resultats.isEmpty ? 0.0 : resultats.last.moyenne;
    final matieres = Matieres.pourClasse(classe);
    final ens = s.enseignantDe(classe).nomComplet;

    for (final r in filtres) {
      final meta = s.bulletins.firstWhere(
        (b) => b.eleveId == r.eleve.id && b.periode == periode && b.anneeScolaire == s.annee,
        orElse: () {
          final m = BulletinMeta(eleveId: r.eleve.id, periode: periode, anneeScolaire: s.annee);
          s.bulletins.add(m);
          return m;
        },
      );
      final photo = _img(r.eleve.photoBase64);
      final appr = s.appreciationDe(r.eleve.id, periode).isNotEmpty
          ? s.appreciationDe(r.eleve.id, periode)
          : CalculService.appreciationAuto(r.moyenne);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          _entete(s, 'Bulletin de notes', sousTitre: 'Periode : $periode'),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Eleve : ${r.eleve.nomComplet}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Matricule : ${r.eleve.matricule}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Sexe : ${r.eleve.sexe}   Ne(e) le : '
                    '${r.eleve.dateNaissance == null ? "-" : _df.format(r.eleve.dateNaissance!)} '
                    'a ${r.eleve.lieuNaissance}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Classe : $classe', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Enseignant : ${ens.isEmpty ? "-" : ens}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Absences (cumul annee) : ${r.absences} jour(s) - Presence : '
                    '${s.tauxPresence(r.eleve.id).toStringAsFixed(0)}%',
                    style: const pw.TextStyle(fontSize: 9)),
              ]),
            ),
            pw.Container(
              width: 70, height: 85,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: .5)),
              child: photo != null
                  ? pw.Image(photo, fit: pw.BoxFit.cover)
                  : pw.Center(child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 7))),
            ),
          ]),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(3),
            },
            children: [
              _tr(['Matiere', 'Coef', 'Moyenne /10', 'Total (M x C)', 'Appreciation'], header: true),
              for (final m in matieres)
                _tr([
                  m.nom,
                  '${m.coefficient}',
                  r.moyennesParMatiere[m.nom] == null
                      ? '-'
                      : r.moyennesParMatiere[m.nom]!.toStringAsFixed(2),
                  r.moyennesParMatiere[m.nom] == null
                      ? '-'
                      : (r.moyennesParMatiere[m.nom]! * m.coefficient).toStringAsFixed(2),
                  r.moyennesParMatiere[m.nom] == null
                      ? ''
                      : CalculService.mention(s, r.moyennesParMatiere[m.nom]!),
                ]),
              _tr([
                'TOTAL / MOYENNE GENERALE',
                '${matieres.fold<int>(0, (a, b) => a + b.coefficient)}',
                r.moyenne.toStringAsFixed(2),
                r.total.toStringAsFixed(2),
                r.mention,
              ], bg: light),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            children: [
              _tr(['Moyenne', 'Rang', 'Mention', 'Moyenne du 1er', 'Moyenne du dernier'], header: true),
              _tr([
                '${r.moyenne.toStringAsFixed(2)}/10',
                '${r.rang}e / ${resultats.length}',
                r.mention,
                moyMax.toStringAsFixed(2),
                moyMin.toStringAsFixed(2),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: .5)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Appreciation generale :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(appr, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
          pw.Spacer(),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Column(children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'BULLETIN|${meta.numeroAuthentification}|${r.eleve.matricule}|$periode|${s.annee}',
                width: 60, height: 60,
              ),
              pw.Text(meta.numeroAuthentification, style: const pw.TextStyle(fontSize: 6)),
            ]),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _signatures(s)),
          ]),
          _pied(s),
        ]),
      ));
    }
    await s.save();
    return doc.save();
  }

  // ------------------------------------------------- FICHE CALCUL MOYENNES
  static Future<Uint8List> ficheCalculMoyennes(AppState s, String classe, String periode) async {
    final doc = await _nouveauDocument();
    final matieres = Matieres.pourClasse(classe);
    final res = CalculService.resultatsClasse(s, classe, periode);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(18),
      build: (ctx) => [
        _entete(s, 'Fiche de calcul des moyennes',
            sousTitre: 'Classe : $classe   |   Periode : $periode   |   Enseignant : ${s.enseignantDe(classe).nomComplet}'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
          children: [
            _tr(['N', 'Matricule', 'Nom et prenoms', ...matieres.map((m) => '${m.nom}\n(c${m.coefficient})'), 'Total', 'Moy', 'Rang', 'Mention'],
                header: true),
            for (var i = 0; i < res.length; i++)
              _tr([
                '${i + 1}',
                res[i].eleve.matricule,
                res[i].eleve.nomComplet,
                ...matieres.map((m) => res[i].moyennesParMatiere[m.nom]?.toStringAsFixed(2) ?? '-'),
                res[i].total.toStringAsFixed(2),
                res[i].moyenne.toStringAsFixed(2),
                '${res[i].rang}',
                res[i].mention,
              ]),
          ],
        ),
        pw.SizedBox(height: 14),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ----------------------------------------------------- DELIBERATION
  static Future<Uint8List> ficheDeliberation(AppState s, String classe, String periode) async {
    final doc = await _nouveauDocument();
    final res = CalculService.resultatsClasse(s, classe, periode);
    final admis = res.where((r) => r.moyenne >= 5).length;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Fiche de deliberation',
            sousTitre: 'Classe : $classe   |   Periode : $periode   |   Enseignant : ${s.enseignantDe(classe).nomComplet}'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Rang', 'Matricule', 'Nom et prenoms', 'Sexe', 'Moyenne', 'Mention', 'Abs.', 'Decision'], header: true),
          for (final r in res)
            _tr([
              '${r.rang}', r.eleve.matricule, r.eleve.nomComplet, r.eleve.sexe,
              r.moyenne.toStringAsFixed(2), r.mention, '${r.absences}',
              r.moyenne >= 5 ? 'ADMIS(E)' : 'REDOUBLE',
            ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: greyBg,
          child: pw.Text(
              'Effectif : ${res.length}   |   Admis : $admis   |   Redoublants : ${res.length - admis}   |   '
              'Taux de reussite : ${res.isEmpty ? 0 : (admis * 100 / res.length).toStringAsFixed(1)}%   |   '
              'Moyenne de classe : ${CalculService.moyenneClasse(s, classe, periode).toStringAsFixed(2)}/10',
              style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(height: 18),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------ LISTE ELEVES
  static Future<Uint8List> listeEleves(AppState s, String classe, {bool emargement = false}) async {
    final doc = await _nouveauDocument();
    final eleves = s.elevesDe(classe);
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, emargement ? "Liste d'emargement" : 'Liste des eleves',
            sousTitre: 'Classe : $classe   |   Effectif : ${eleves.length}'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['N', 'Matricule', 'Nom et prenoms', 'Sexe', 'Date de naissance', 'Parent / Tuteur', 'Telephone', emargement ? 'Signature' : 'Statut'], header: true),
          for (var i = 0; i < eleves.length; i++)
            _tr([
              '${i + 1}', eleves[i].matricule, eleves[i].nomComplet, eleves[i].sexe,
              eleves[i].dateNaissance == null ? '-' : _df.format(eleves[i].dateNaissance!),
              eleves[i].nomParent, eleves[i].telParent,
              emargement ? '' : eleves[i].statut,
            ]),
        ]),
        pw.SizedBox(height: 16),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------- REGISTRE DE NOTES
  static Future<Uint8List> registreNotes(AppState s, String classe, String periode) async {
    final doc = await _nouveauDocument();
    final eleves = s.elevesDe(classe);
    final matieres = Matieres.nomsPourClasse(classe);
    final evals = CalculService.evaluationsDePeriode(periode);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => [
        _entete(s, 'Registre de notes', sousTitre: 'Classe : $classe   |   Periode : $periode'),
        for (final m in matieres) ...[
          pw.Text(m, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: green)),
          pw.SizedBox(height: 2),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
            _tr(['Nom et prenoms', ...evals, 'Moyenne'], header: true),
            for (final e in eleves)
              _tr([
                e.nomComplet,
                ...evals.map((ev) => s.note(e.id, m, ev)?.valeur.toStringAsFixed(2) ?? '-'),
                CalculService.moyenneMatiere(s, e.id, m, periode)?.toStringAsFixed(2) ?? '-',
              ]),
          ]),
          pw.SizedBox(height: 8),
        ],
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------- REGISTRE D'APPEL
  static Future<Uint8List> registreAppel(AppState s, String classe, DateTime debut, DateTime fin) async {
    final doc = await _nouveauDocument();
    final eleves = s.elevesDe(classe);
    final jours = <DateTime>[];
    for (var d = debut; !d.isAfter(fin); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.sunday) jours.add(d);
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => [
        _entete(s, "Registre d'appel",
            sousTitre: 'Classe : $classe   |   Du ${_df.format(debut)} au ${_df.format(fin)}'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Nom et prenoms', ...jours.map((j) => '${j.day}/${j.month}'), 'Abs.'], header: true),
          for (final e in eleves)
            _tr([
              e.nomComplet,
              ...jours.map((j) {
                final p = s.presence(e.id, j);
                if (p == null) return '';
                return p.present ? 'P' : 'A';
              }),
              '${jours.where((j) => s.presence(e.id, j)?.present == false).length}',
            ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Legende : P = Present, A = Absent', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 10),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ---------------------------------------------- STATISTIQUES CLASSE
  static Future<Uint8List> statistiquesClasse(AppState s, String classe, String periode) async {
    final doc = await _nouveauDocument();
    final matieres = Matieres.nomsPourClasse(classe);
    final res = CalculService.resultatsClasse(s, classe, periode);
    final evo = CalculService.evolutionClasse(s, classe);
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Statistiques de la classe', sousTitre: 'Classe : $classe   |   Periode : $periode'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Matiere', 'Moyenne', 'Meilleure', 'Plus faible', 'Taux de reussite', 'Effectif note'], header: true),
          for (final m in matieres)
            () {
              final st = CalculService.statsMatiere(s, classe, m, periode);
              return _tr([
                m,
                (st['moyenne'] as double).toStringAsFixed(2),
                (st['max'] as double).toStringAsFixed(2),
                (st['min'] as double).toStringAsFixed(2),
                '${(st['reussite'] as double).toStringAsFixed(1)}%',
                '${st['effectif']}',
              ]);
            }(),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Evolution des 9 evaluations', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(evo.keys.toList(), header: true),
          _tr(evo.values.map((v) => v.toStringAsFixed(2)).toList()),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Synthese', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Bullet(text: 'Effectif : ${res.length}', style: const pw.TextStyle(fontSize: 9)),
        pw.Bullet(text: 'Moyenne de classe : ${CalculService.moyenneClasse(s, classe, periode).toStringAsFixed(2)}/10', style: const pw.TextStyle(fontSize: 9)),
        pw.Bullet(text: 'Taux de reussite : ${CalculService.tauxReussite(s, classe, periode).toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 14),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------- TABLEAU D'HONNEUR
  static Future<Uint8List> tableauHonneur(AppState s, String periode) async {
    final doc = await _nouveauDocument();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, "Tableau d'honneur", sousTitre: 'Periode : $periode'),
        for (final c in s.salles) ...[
          pw.Text('Classe $c', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: green)),
          pw.SizedBox(height: 2),
          () {
            final res = CalculService.resultatsClasse(s, c, periode).take(5).toList();
            if (res.isEmpty) {
              return pw.Text('Aucune donnee.', style: const pw.TextStyle(fontSize: 9));
            }
            return pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
              _tr(['Rang', 'Nom et prenoms', 'Moyenne', 'Mention'], header: true),
              for (final r in res)
                _tr(['${r.rang}', r.eleve.nomComplet, r.moyenne.toStringAsFixed(2), r.mention]),
            ]);
          }(),
          pw.SizedBox(height: 10),
        ],
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------- RAPPORT ANNUEL
  static Future<Uint8List> rapportAnnuel(AppState s) async {
    final doc = await _nouveauDocument();
    final alertes = AlerteService.pourEcole(s).where((a) => a.niveau == 'critique').take(20).toList();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Rapport annuel', sousTitre: 'Annee scolaire ${s.annee}'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Classe', 'Effectif', 'Garcons', 'Filles', 'Moyenne', 'Reussite', 'Admis', 'Redoublants', 'Enseignant'], header: true),
          for (final c in s.salles)
            () {
              final el = s.elevesDe(c);
              final res = CalculService.resultatsClasse(s, c, 'Annee');
              final admis = res.where((r) => r.moyenne >= 5).length;
              return _tr([
                c, '${el.length}',
                '${el.where((e) => e.sexe == 'M').length}',
                '${el.where((e) => e.sexe == 'F').length}',
                CalculService.moyenneClasse(s, c, 'Annee').toStringAsFixed(2),
                '${CalculService.tauxReussite(s, c, 'Annee').toStringAsFixed(1)}%',
                '$admis', '${res.length - admis}',
                s.enseignantDe(c).nomComplet,
              ]);
            }(),
        ]),
        pw.SizedBox(height: 12),
        pw.Text('Effectif total : ${s.elevesAnnee.length} eleves',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text('Taux d\'absenteisme moyen : ${_absenteisme(s).toStringAsFixed(1)}%',
            style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 10),
        pw.Text('Observations et difficultes observees',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (alertes.isEmpty)
          pw.Text('Aucune difficulte majeure detectee.', style: const pw.TextStyle(fontSize: 9)),
        for (final a in alertes)
          pw.Bullet(text: '${a.titre} : ${a.message}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 16),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  static double _absenteisme(AppState s) {
    final p = s.presences.where((x) => x.anneeScolaire == s.annee).toList();
    if (p.isEmpty) return 0;
    return p.where((x) => !x.present).length * 100 / p.length;
  }

  // ---------------------------------------------- DOCUMENTS ADMINISTRATIFS
  static Future<Uint8List> documentAdministratif(
      AppState s, Eleve e, String type, {String texteLibre = ''}) async {
    final doc = await _nouveauDocument();
    String corps;
    switch (type) {
      case 'Attestation de scolarite':
        corps = "Je soussigne(e) ${s.ecole.nomDirecteur.isEmpty ? 'le Directeur' : s.ecole.nomDirecteur}, "
            "Directeur de ${s.ecole.nom}, atteste que l'eleve ${e.nomComplet}, "
            "matricule ${e.matricule}, ne(e) le "
            "${e.dateNaissance == null ? '................' : _df.format(e.dateNaissance!)} "
            "a ${e.lieuNaissance.isEmpty ? '................' : e.lieuNaissance}, "
            "est regulierement inscrit(e) en classe de ${e.classe} au titre de l'annee scolaire ${s.annee}.\n\n"
            "En foi de quoi la presente attestation lui est delivree pour servir et valoir ce que de droit.";
        break;
      case 'Certificat de frequentation':
        corps = "Je soussigne(e) ${s.ecole.nomDirecteur.isEmpty ? 'le Directeur' : s.ecole.nomDirecteur} "
            "certifie que l'eleve ${e.nomComplet} (matricule ${e.matricule}) a frequente "
            "regulierement la classe de ${e.classe} de ${s.ecole.nom} durant l'annee scolaire ${s.annee}, "
            "avec un taux de presence de ${s.tauxPresence(e.id).toStringAsFixed(0)}%.";
        break;
      case 'Certificat de transfert':
        corps = "Je soussigne(e) ${s.ecole.nomDirecteur.isEmpty ? 'le Directeur' : s.ecole.nomDirecteur} "
            "certifie que l'eleve ${e.nomComplet} (matricule ${e.matricule}), inscrit(e) en classe de "
            "${e.classe}, quitte ${s.ecole.nom} a la date du "
            "${e.dateDepart == null ? _df.format(DateTime.now()) : _df.format(e.dateDepart!)}.\n\n"
            "Motif : ${e.motifDepart.isEmpty ? 'Transfert' : e.motifDepart}.\n\n"
            "Son dossier scolaire complet est remis a la famille.";
        break;
      case 'Convocation des parents':
        corps = "Monsieur / Madame ${e.nomParent.isEmpty ? '................' : e.nomParent},\n\n"
            "Vous etes prie(e) de bien vouloir vous presenter a ${s.ecole.nom} "
            "concernant votre enfant ${e.nomComplet}, eleve en classe de ${e.classe}.\n\n"
            "${texteLibre.isEmpty ? 'Objet : suivi de la scolarite de votre enfant.' : texteLibre}\n\n"
            "Comptant sur votre presence, veuillez agreer nos salutations distinguees.";
        break;
      case 'Fiche d\'information aux parents':
        corps = "Eleve : ${e.nomComplet} (${e.classe}) - Matricule : ${e.matricule}\n"
            "Moyenne annuelle : ${CalculService.calculer(s, e, 'Annee').$2.toStringAsFixed(2)}/10\n"
            "Absences : ${s.absencesDe(e.id)} - Taux de presence : ${s.tauxPresence(e.id).toStringAsFixed(0)}%\n\n"
            "${texteLibre.isEmpty ? 'Nous vous informons du suivi scolaire de votre enfant.' : texteLibre}";
        break;
      default: // Carte scolaire
        corps = texteLibre;
    }

    doc.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _entete(s, type),
        if (type == 'Carte scolaire')
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: green, width: 1)),
            child: pw.Row(children: [
              pw.Container(
                width: 80, height: 95,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: .5)),
                child: _img(e.photoBase64) != null
                    ? pw.Image(_img(e.photoBase64)!, fit: pw.BoxFit.cover)
                    : pw.Center(child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 7))),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e.nomComplet, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Matricule : ${e.matricule}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Classe : ${e.classe}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Annee : ${s.annee}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Parent : ${e.nomParent} - ${e.telParent}', style: const pw.TextStyle(fontSize: 9)),
                ]),
              ),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'ELEVE|${e.matricule}|${e.nomComplet}|${e.classe}|${s.annee}',
                width: 60, height: 60,
              ),
            ]),
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 14),
            child: pw.Text(corps, style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
          ),
        pw.Spacer(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Fait le ${_df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.SizedBox(height: 6),
        _signatures(s, gauche: 'Reference'),
        _pied(s),
      ]),
    ));
    return doc.save();
  }

  // -------------------------------------------------- DOSSIER ELEVE
  static Future<Uint8List> dossierEleve(AppState s, Eleve e) async {
    final doc = await _nouveauDocument();
    final evo = CalculService.evolutionEleve(s, e);
    final comps = s.comportements.where((c) => c.eleveId == e.id).toList();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Dossier scolaire de l\'eleve'),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e.nomComplet, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Matricule : ${e.matricule}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Classe : ${e.classe}   Sexe : ${e.sexe}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Ne(e) le ${e.dateNaissance == null ? "-" : _df.format(e.dateNaissance!)} a ${e.lieuNaissance}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Parent : ${e.nomParent} (${e.telParent})', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Adresse : ${e.adresse}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Statut : ${e.statut}   Groupe : ${e.groupeNiveau}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Absences : ${s.absencesDe(e.id)}   Presence : ${s.tauxPresence(e.id).toStringAsFixed(0)}%',
                  style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
          pw.Container(
            width: 70, height: 85,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: .5)),
            child: _img(e.photoBase64) != null
                ? pw.Image(_img(e.photoBase64)!, fit: pw.BoxFit.cover)
                : pw.Center(child: pw.Text('PHOTO', style: const pw.TextStyle(fontSize: 7))),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Resultats par evaluation', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(evo.keys.toList(), header: true),
          _tr(evo.values.map((v) => v == 0 ? '-' : v.toStringAsFixed(2)).toList()),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Comportement', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (comps.isEmpty) pw.Text('Aucune observation.', style: const pw.TextStyle(fontSize: 9)),
        if (comps.isNotEmpty)
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
            _tr(['Date', 'Type', 'Description', 'Disc.', 'Part.'], header: true),
            for (final c in comps)
              _tr([_df.format(c.date), c.type, c.description, '${c.discipline}/10', '${c.participation}/10']),
          ]),
        pw.SizedBox(height: 10),
        pw.Text('Historique des annees et decisions',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Annee', 'Classe', 'Decision', 'Destination'], header: true),
          for (final d in s.decisions.where((d) => d.eleveId == e.id))
            _tr([d.anneeScolaire, d.classeOrigine, d.decision, d.classeDestination]),
        ]),
        pw.SizedBox(height: 14),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------- CAHIER DE TEXTES
  static Future<Uint8List> cahierTextes(AppState s, String classe) async {
    final doc = await _nouveauDocument();
    final l = s.cahier.where((c) => c.classe == classe && c.anneeScolaire == s.annee).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Cahier de textes numerique', sousTitre: 'Classe : $classe'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Date', 'Matiere', 'Lecon', 'Resume', 'Exercices', 'Devoirs'], header: true),
          for (final c in l)
            _tr([_df.format(c.date), c.matiere, c.lecon, c.resume, c.exercices, c.devoirs]),
        ]),
        pw.SizedBox(height: 14),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------- EMPLOI DU TEMPS
  static Future<Uint8List> emploiDuTemps(AppState s, String classe) async {
    final doc = await _nouveauDocument();
    const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final l = s.edt.where((c) => c.classe == classe).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Emploi du temps', sousTitre: 'Classe : $classe   |   Enseignant : ${s.enseignantDe(classe).nomComplet}'),
        for (final j in jours) ...[
          pw.Text(j, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: green)),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
            _tr(['Horaire', 'Activite'], header: true),
            for (final c in l.where((x) => x.jour == j))
              _tr(['${c.debut} - ${c.fin}', c.matiere]),
          ]),
          pw.SizedBox(height: 6),
        ],
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // -------------------------------------------------- FRAIS SCOLAIRES
  static Future<Uint8List> etatFrais(AppState s) async {
    final doc = await _nouveauDocument();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(s, 'Etat des frais scolaires', sousTitre: 'Annee ${s.annee}'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: .5), children: [
          _tr(['Eleve', 'Classe', 'Libelle', 'Du', 'Paye', 'Reste', 'Recu', 'Date'], header: true),
          for (final p in s.paiements.where((p) => p.anneeScolaire == s.annee))
            _tr([
              s.eleveParId(p.eleveId)?.nomComplet ?? '-',
              s.eleveParId(p.eleveId)?.classe ?? '-',
              p.libelle,
              p.montantDu.toStringAsFixed(0),
              p.montantPaye.toStringAsFixed(0),
              p.reste.toStringAsFixed(0),
              p.recu,
              _df.format(p.date),
            ]),
        ]),
        pw.SizedBox(height: 14),
        _signatures(s),
        _pied(s),
      ],
    ));
    return doc.save();
  }

  // --------------------------------------------- DOSSIER D'INSPECTION
  static Future<Uint8List> dossierInspection(AppState s, String periode) async {
    final doc = await _nouveauDocument();
    doc.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(children: [
        _entete(s, "Dossier d'inspection scolaire", sousTitre: 'Annee ${s.annee} - Periode : $periode'),
        pw.SizedBox(height: 20),
        pw.Text('Ce dossier contient :', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...[
          'Listes des eleves par classe',
          'Registres de notes',
          'Fiches de calcul des moyennes',
          'Fiches de deliberation',
          'Statistiques des classes',
          'Statistiques generales de l\'ecole',
          "Tableau d'honneur",
          'Rapport annuel',
        ].map((t) => pw.Bullet(text: t, style: const pw.TextStyle(fontSize: 10))),
        pw.Spacer(),
        _signatures(s),
        _pied(s),
      ]),
    ));
    final parts = <Uint8List>[await doc.save()];
    for (final c in s.salles) {
      if (s.elevesDe(c).isEmpty) continue;
      parts.add(await listeEleves(s, c));
      parts.add(await registreNotes(s, c, periode));
      parts.add(await ficheCalculMoyennes(s, c, periode));
      parts.add(await ficheDeliberation(s, c, periode));
      parts.add(await statistiquesClasse(s, c, periode));
    }
    parts.add(await tableauHonneur(s, periode));
    parts.add(await rapportAnnuel(s));

    // Fusion des documents
    final merged = pw.Document();
    for (final p in parts) {
      await for (final page in Printing.raster(p, dpi: 110)) {
        final img = pw.MemoryImage(await page.toPng());
        merged.addPage(pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
          build: (c) => pw.Image(img, fit: pw.BoxFit.contain),
        ));
      }
    }
    return merged.save();
  }

  // -------------------------------------------------------------- UTILS
  static Future<void> apercu(Uint8List bytes, String nom) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: nom);

  static Future<void> partager(Uint8List bytes, String nom) =>
      Printing.sharePdf(bytes: bytes, filename: nom);
}
