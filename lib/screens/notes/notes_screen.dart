import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/calcul_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Ecran de saisie des notes en mode "maquette" (tableau type releve de notes) :
/// une ligne par eleve, une colonne par matiere, + Total / Moyenne / Rang / Observation.
/// Toutes les matieres ont un coefficient de 1 (ecole primaire : pas de coefficient).
class NotesScreen extends StatefulWidget {
  final String classe;
  const NotesScreen({super.key, required this.classe});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String evaluation = Evaluations.all.first;

  // Largeurs des colonnes (grille façon maquette papier).
  static const double _wNum = 34;
  static const double _wNom = 132;
  static const double _wMat = 58;
  static const double _wTotal = 56;
  static const double _wMoy = 62;
  static const double _wRang = 46;
  static const double _wObs = 170;
  static const double _hHeader = 58;
  static const double _hRow = 46;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eleves = s.elevesDe(widget.classe);
    final matieres = Matieres.pourClasse(widget.classe);
    final verrouille = s.estVerrouille(widget.classe, evaluation) && !s.estDirecteur;
    final resultats = CalculService.resultatsClasse(s, widget.classe, evaluation);
    final resParEleve = {for (final r in resultats) r.eleve.id: r};

    return Scaffold(
      appBar: AppBar(
        title: Text('Notes - ${widget.classe}'),
        actions: [
          IconButton(
            tooltip: s.estVerrouille(widget.classe, evaluation) ? 'Deverrouiller' : 'Verrouiller',
            icon: Icon(s.estVerrouille(widget.classe, evaluation) ? Icons.lock : Icons.lock_open),
            onPressed: s.estDirecteur
                ? () => s.basculerVerrou(widget.classe, evaluation)
                : () => showError(context, 'Seul le directeur peut modifier le verrouillage.'),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: DropdownButtonFormField<String>(
            value: evaluation,
            decoration: const InputDecoration(labelText: 'Evaluation', isDense: true),
            items: Evaluations.all
                .map((e) => DropdownMenuItem(
                    value: e, child: Text('$e  (Trimestre ${Evaluations.trimestreDe(e)})')))
                .toList(),
            onChanged: (v) => setState(() => evaluation = v!),
          ),
        ),
        if (verrouille)
          Container(
            width: double.infinity,
            color: WA.warn.withOpacity(.2),
            padding: const EdgeInsets.all(8),
            child: const Text('Notes verrouillees par le directeur : modification impossible.',
                style: TextStyle(fontSize: 12)),
          ),
        Expanded(
          child: eleves.isEmpty
              ? const EmptyState(message: 'Aucun eleve dans cette classe.')
              : _tableau(s, eleves, matieres, resParEleve, verrouille),
        ),
        Container(
          color: WA.bubble,
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          child: Text(
            'Moyenne de la classe ($evaluation) : '
            '${CalculService.moyenneClasse(s, widget.classe, evaluation).toStringAsFixed(2)}/10',
            style: const TextStyle(fontWeight: FontWeight.w600, color: WA.teal),
          ),
        ),
      ]),
    );
  }

  /// Construit la grille : une colonne fixe (N° + Nom) et une zone
  /// defilant horizontalement (matieres + Total + Moyenne + Rang + Observation),
  /// le tout dans un seul defilement vertical partage.
  Widget _tableau(AppState s, List<Eleve> eleves, List<Matiere> matieres,
      Map<String, ResultatEleve> resParEleve, bool verrouille) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----- Colonne fixe : N° + Noms et prenoms -----
            Row(children: [
              Column(children: [
                _celluleEntete('N°', _wNum, _hHeader, alignLeft: false),
                for (var i = 0; i < eleves.length; i++)
                  _cellule(Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      _wNum, _hRow),
              ]),
              Column(children: [
                _celluleEntete('Noms et Prenoms', _wNom, _hHeader),
                for (final e in eleves)
                  _cellule(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e.nomComplet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    _wNom,
                    _hRow,
                    alignLeft: true,
                  ),
              ]),
            ]),
            // ----- Zone defilante horizontalement : matieres + synthese -----
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(children: [
                  // En-tete
                  Row(children: [
                    for (final m in matieres) _celluleEntete(m.nom, _wMat, _hHeader),
                    _celluleEntete('Total', _wTotal, _hHeader),
                    _celluleEntete('Moyenne', _wMoy, _hHeader),
                    _celluleEntete('Rang', _wRang, _hHeader),
                    _celluleEntete('Observation', _wObs, _hHeader, alignLeft: true),
                  ]),
                  // Lignes eleves
                  for (final e in eleves)
                    Row(children: [
                      for (final m in matieres)
                        _cellule(
                          _champNote(s, e.id, m.nom, verrouille),
                          _wMat,
                          _hRow,
                        ),
                      Builder(builder: (_) {
                        final r = resParEleve[e.id];
                        final moyenne = r?.moyenne ?? 0.0;
                        final total = r?.total ?? 0.0;
                        final rang = r?.rang;
                        final aDesNotes = r?.moyennesParMatiere.isNotEmpty ?? false;
                        return Row(children: [
                          _cellule(
                            Text(aDesNotes ? total.toStringAsFixed(2) : '-',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            _wTotal,
                            _hRow,
                          ),
                          _cellule(
                            Text(aDesNotes ? moyenne.toStringAsFixed(2) : '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
                            _wMoy,
                            _hRow,
                          ),
                          _cellule(
                            Text(aDesNotes && rang != null ? '$rang' : '-'),
                            _wRang,
                            _hRow,
                          ),
                          _cellule(
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                aDesNotes ? CalculService.appreciationAuto(moyenne) : '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            _wObs,
                            _hRow,
                            alignLeft: true,
                          ),
                        ]);
                      }),
                    ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _celluleEntete(String texte, double w, double h, {bool alignLeft = false}) => Container(
        width: w,
        height: h,
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: alignLeft ? 4 : 2),
        decoration: BoxDecoration(
          color: WA.teal,
          border: Border.all(color: Colors.white, width: .5),
        ),
        child: Text(
          texte,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );

  Widget _cellule(Widget child, double w, double h, {bool alignLeft = false}) => Container(
        width: w,
        height: h,
        alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: .5),
        ),
        child: child,
      );

  Widget _champNote(AppState s, String eleveId, String matiere, bool verrouille) {
    final n = s.note(eleveId, matiere, evaluation);
    final ctrl = TextEditingController(text: n?.valeur.toStringAsFixed(2) ?? '');
    return TextField(
      controller: ctrl,
      enabled: !verrouille,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        hintText: '-',
      ),
      onSubmitted: (v) => _save(s, eleveId, matiere, v),
      onTapOutside: (_) => _save(s, eleveId, matiere, ctrl.text),
    );
  }

  void _save(AppState s, String eleveId, String matiere, String v) {
    final t = v.trim().replaceAll(',', '.');
    if (t.isEmpty) {
      if (!s.setNote(eleveId, widget.classe, matiere, evaluation, null)) {
        showError(context, 'Periode verrouillee : suppression impossible.');
      }
      return;
    }
    final d = double.tryParse(t);
    if (d == null || d < 0 || d > 10) {
      showError(context, 'Note invalide (0 a 10).');
      return;
    }
    if (!s.setNote(eleveId, widget.classe, matiere, evaluation, d)) {
      showError(context, 'Periode verrouillee : modification impossible.');
    }
  }
}
