import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../services/alerte_service.dart';
import '../../services/calcul_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../documents/bulletins_screen.dart';
import '../documents/documents_screen.dart';
import '../eleves/eleves_screen.dart';
import '../notes/notes_screen.dart';
import '../pedagogie/cahier_screen.dart';
import '../pedagogie/comportement_screen.dart';
import '../pedagogie/devoirs_screen.dart';
import '../pedagogie/edt_screen.dart';
import '../pedagogie/groupes_screen.dart';
import '../presences/presences_screen.dart';
import '../stats/alertes_screen.dart';
import '../stats/honneur_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/backup_screen.dart';
import '../sync/sync_screen.dart';
import 'archives_screen.dart';
import 'audit_screen.dart';
import 'config_ecole_screen.dart';
import 'frais_screen.dart';
import 'journal_screen.dart';
import 'promotion_screen.dart';
import 'rapports_screen.dart';
import 'recherche_screen.dart';
import 'verification_screen.dart';

class DirecteurHome extends StatefulWidget {
  const DirecteurHome({super.key});

  @override
  State<DirecteurHome> createState() => _DirecteurHomeState();
}

class _DirecteurHomeState extends State<DirecteurHome> {
  String? classe;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    classe ??= s.salles.isEmpty ? '' : s.salles.first;
    if (classe!.isNotEmpty && !s.salles.contains(classe)) classe = s.salles.first;
    final classeSel = classe!;
    final total = s.elevesAnnee.length;
    final garcons = s.elevesAnnee.where((e) => e.sexe == 'M').length;
    final filles = total - garcons;
    final res = s.salles.expand((c) => CalculService.resultatsClasse(s, c, 'Annee')).toList();
    final avecNotes = res.where((r) => r.moyenne > 0).toList();
    final admis = avecNotes.where((r) => r.moyenne >= 5).length;
    final alertes = AlerteService.pourEcole(s).where((a) => a.niveau == 'critique').length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Directeur'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () => _go(const RechercheScreen())),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                s.deconnecter();
                Navigator.pop(context);
              },
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.dashboard), text: 'Tableau de bord'),
            Tab(icon: Icon(Icons.class_), text: 'Classes'),
            Tab(icon: Icon(Icons.settings), text: 'Administration'),
          ]),
        ),
        body: TabBarView(children: [
          // ---------------- DASHBOARD
          ListView(padding: const EdgeInsets.all(8), children: [
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: WA.teal, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.ecole.nom,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Annee scolaire ${s.annee}', style: const TextStyle(color: Colors.white70)),
                Text(s.ecole.devise, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
              ]),
            ),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                _kpi('Eleves', '$total', Icons.groups),
                _kpi('Garcons / Filles', '$garcons / $filles', Icons.wc),
                _kpi('Admis', '$admis', Icons.check_circle),
                _kpi('Redoublants', '${avecNotes.length - admis}', Icons.replay),
                _kpi('Taux de reussite',
                    '${avecNotes.isEmpty ? 0 : (admis * 100 / avecNotes.length).toStringAsFixed(0)}%',
                    Icons.trending_up),
                _kpi('Alertes critiques', '$alertes', Icons.warning_amber),
              ],
            ),
            SectionCard(titre: 'Effectifs et resultats par classe', icone: Icons.bar_chart, children: [
              ...s.salles.map((c) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                        backgroundColor: WA.bubble,
                        child: Text(c, style: const TextStyle(fontSize: 10, color: WA.teal))),
                    title: Text('${s.elevesDe(c).length} eleve(s) - ${s.enseignantDe(c).nomComplet}'),
                    subtitle: Text('Moyenne ${CalculService.moyenneClasse(s, c, 'Annee').toStringAsFixed(2)}/10 - '
                        'Reussite ${CalculService.tauxReussite(s, c, 'Annee').toStringAsFixed(0)}%'),
                  )),
            ]),
            MenuTile(
                icone: Icons.warning_amber,
                titre: 'Alertes pedagogiques',
                sousTitre: "Detection des difficultes et recommandations",
                onTap: () => _go(const AlertesScreen())),
            MenuTile(
                icone: Icons.emoji_events,
                titre: "Tableau d'honneur",
                onTap: () => _go(HonneurScreen(classes: s.salles))),
            MenuTile(
                icone: Icons.assessment,
                titre: 'Rapports et mode inspection',
                onTap: () => _go(const RapportsScreen())),
          ]),

          // ---------------- CLASSES
          s.salles.isEmpty
              ? const EmptyState(
                  message: "Aucune salle ouverte. Allez dans Configuration de l'ecole > "
                      "Salles / classes pour en creer.")
              : Column(children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(10),
                    child: ClassePicker(
                        valeur: classeSel, classes: s.salles, onChanged: (c) => setState(() => classe = c)),
                  ),
                  Expanded(
                    child: ListView(children: [
                      MenuTile(icone: Icons.groups, titre: 'Eleves', sousTitre: '${s.elevesDe(classeSel).length} inscrit(s)', onTap: () => _go(ElevesScreen(classe: classeSel))),
                      MenuTile(icone: Icons.edit_note, titre: 'Notes', onTap: () => _go(NotesScreen(classe: classeSel))),
                      MenuTile(icone: Icons.event_available, titre: 'Presences', onTap: () => _go(PresencesScreen(classe: classeSel))),
                      MenuTile(icone: Icons.picture_as_pdf, titre: 'Bulletins', onTap: () => _go(BulletinsScreen(classe: classeSel))),
                      MenuTile(icone: Icons.folder_copy, titre: 'Documents et registres', onTap: () => _go(DocumentsScreen(classe: classeSel))),
                      MenuTile(icone: Icons.insert_chart, titre: 'Statistiques', onTap: () => _go(StatsClasseScreen(classe: classeSel))),
                      MenuTile(icone: Icons.menu_book, titre: 'Cahier de textes', onTap: () => _go(CahierScreen(classe: classeSel))),
                      MenuTile(icone: Icons.assignment, titre: 'Devoirs', onTap: () => _go(DevoirsScreen(classe: classeSel))),
                      MenuTile(icone: Icons.schedule, titre: 'Emploi du temps', onTap: () => _go(EdtScreen(classe: classeSel))),
                      MenuTile(icone: Icons.emoji_people, titre: 'Carnet de comportement', onTap: () => _go(ComportementScreen(classe: classeSel))),
                      MenuTile(icone: Icons.group_work, titre: 'Groupes de niveau', onTap: () => _go(GroupesScreen(classe: classeSel))),
                    ]),
                  ),
                ]),

          // ---------------- ADMINISTRATION
          ListView(children: [
            MenuTile(icone: Icons.settings, titre: "Configuration de l'ecole", sousTitre: 'Logo, devise, signature, cachet, enseignants, mentions', onTap: () => _go(const ConfigEcoleScreen())),
            MenuTile(icone: Icons.sync, titre: 'Synchronisation JSON', sousTitre: 'Importer les fichiers des enseignants', onTap: () => _go(const SyncScreen())),
            MenuTile(icone: Icons.backup, titre: 'Sauvegarde et restauration', onTap: () => _go(const BackupScreen())),
            MenuTile(icone: Icons.inventory_2, titre: 'Archives des annees', onTap: () => _go(const ArchivesScreen())),
            MenuTile(icone: Icons.upgrade, titre: 'Promotion et rentree', onTap: () => _go(const PromotionScreen())),
            MenuTile(icone: Icons.payments, titre: 'Frais scolaires', onTap: () => _go(const FraisScreen())),
            MenuTile(icone: Icons.verified_user, titre: 'Authentification des bulletins (QR)', onTap: () => _go(const VerificationScreen())),
            MenuTile(icone: Icons.edit_note, titre: 'Journal de bord', onTap: () => _go(const JournalScreen())),
            MenuTile(icone: Icons.history, titre: 'Historique des modifications', onTap: () => _go(const AuditScreen())),
          ]),
        ]),
      ),
    );
  }

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Widget _kpi(String titre, String valeur, IconData icone) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icone, color: WA.green),
            const SizedBox(height: 4),
            Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: WA.teal)),
            Text(titre, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: WA.grey)),
          ]),
        ),
      );
}
