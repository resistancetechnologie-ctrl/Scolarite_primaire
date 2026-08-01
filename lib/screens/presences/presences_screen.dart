import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PresencesScreen extends StatefulWidget {
  final String classe;
  const PresencesScreen({super.key, required this.classe});

  @override
  State<PresencesScreen> createState() => _PresencesScreenState();
}

class _PresencesScreenState extends State<PresencesScreen> {
  DateTime jour = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eleves = s.elevesDe(widget.classe);
    final presents = eleves.where((e) => s.presence(e.id, jour)?.present == true).length;
    final absents = eleves.where((e) => s.presence(e.id, jour)?.present == false).length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Presences - ${widget.classe}'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Appel du jour'),
            Tab(text: 'Historique'),
            Tab(text: 'Statistiques'),
          ]),
        ),
        body: TabBarView(children: [
          // ---------------- APPEL
          Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(jour),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month, color: WA.green),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context, initialDate: jour,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => jour = d);
                  },
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Tous presents'),
                    onPressed: () async {
                      for (final e in eleves) {
                        await s.marquerPresence(e.id, widget.classe, jour, true);
                      }
                      if (context.mounted) showOk(context, 'Classe marquee presente.');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('$presents P / $absents A', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: eleves.isEmpty
                  ? const EmptyState(message: 'Aucun eleve.')
                  : ListView.builder(
                      itemCount: eleves.length,
                      itemBuilder: (_, i) {
                        final e = eleves[i];
                        final p = s.presence(e.id, jour);
                        return Card(
                          child: ListTile(
                            leading: imageBase64(e.photoBase64, size: 40),
                            title: Text(e.nomComplet),
                            subtitle: Text(p == null
                                ? 'Non pointe'
                                : (p.present ? 'Present' : 'Absent${p.justifiee ? ' (justifie)' : ''}')),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: Icon(Icons.check_circle,
                                    color: p?.present == true ? WA.lightGreen : Colors.grey.shade300),
                                onPressed: () => s.marquerPresence(e.id, widget.classe, jour, true),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel,
                                    color: p?.present == false ? WA.danger : Colors.grey.shade300),
                                onPressed: () => s.marquerPresence(e.id, widget.classe, jour, false),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: PdfActions(
                builder: () => PdfService.registreAppel(
                    s, widget.classe, jour.subtract(const Duration(days: 30)), jour),
                nom: 'registre_appel_${widget.classe}.pdf',
                label: "Registre d'appel (30 jours)",
              ),
            ),
          ]),

          // ---------------- HISTORIQUE
          _Historique(classe: widget.classe),

          // ---------------- STATISTIQUES
          ListView(children: [
            SectionCard(titre: 'Taux de presence de la classe', icone: Icons.pie_chart, children: [
              Text('${_tauxClasse(s, eleves).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: WA.teal)),
            ]),
            SectionCard(titre: 'Classement des eleves les plus absents', icone: Icons.warning_amber, children: [
              ...(eleves.toList()
                    ..sort((a, b) => s.absencesDe(b.id).compareTo(s.absencesDe(a.id))))
                  .take(10)
                  .map((e) => ListTile(
                        dense: true,
                        title: Text(e.nomComplet),
                        subtitle: Text('Taux de presence : ${s.tauxPresence(e.id).toStringAsFixed(1)}%'),
                        trailing: Text('${s.absencesDe(e.id)} abs.',
                            style: TextStyle(
                                color: s.absencesDe(e.id) >= s.ecole.seuilAbsences ? WA.danger : WA.grey,
                                fontWeight: FontWeight.bold)),
                      )),
            ]),
          ]),
        ]),
      ),
    );
  }

  double _tauxClasse(AppState s, List<Eleve> eleves) {
    if (eleves.isEmpty) return 0;
    return eleves.map((e) => s.tauxPresence(e.id)).reduce((a, b) => a + b) / eleves.length;
  }
}

class _Historique extends StatefulWidget {
  final String classe;
  const _Historique({required this.classe});

  @override
  State<_Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<_Historique> {
  DateTime date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final eleves = s.elevesDe(widget.classe);
    final presents = eleves.where((e) => s.presence(e.id, date)?.present == true).toList();
    final absents = eleves.where((e) => s.presence(e.id, date)?.present == false).toList();

    return ListView(children: [
      Card(
        child: ListTile(
          leading: const Icon(Icons.search, color: WA.green),
          title: const Text('Rechercher une date'),
          subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final d = await showDatePicker(
                context: context, initialDate: date,
                firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => date = d);
          },
        ),
      ),
      SectionCard(titre: 'Presents (${presents.length})', icone: Icons.check_circle, children: [
        if (presents.isEmpty) const Text('Aucun.'),
        ...presents.map((e) => Text('- ${e.nomComplet}')),
      ]),
      SectionCard(titre: 'Absents (${absents.length})', icone: Icons.cancel, children: [
        if (absents.isEmpty) const Text('Aucun.'),
        ...absents.map((e) => Text('- ${e.nomComplet}')),
      ]),
      SectionCard(titre: 'Non pointes', icone: Icons.help_outline, children: [
        ...eleves
            .where((e) => s.presence(e.id, date) == null)
            .map((e) => Text('- ${e.nomComplet}')),
      ]),
    ]);
  }
}
