import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'eleve_form.dart';
import 'eleve_detail.dart';

class ElevesScreen extends StatefulWidget {
  final String classe;
  const ElevesScreen({super.key, required this.classe});

  @override
  State<ElevesScreen> createState() => _ElevesScreenState();
}

class _ElevesScreenState extends State<ElevesScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var eleves = s.elevesDe(widget.classe);
    if (q.isNotEmpty) {
      final t = q.toLowerCase();
      eleves = eleves
          .where((e) =>
              e.nom.toLowerCase().contains(t) ||
              e.prenom.toLowerCase().contains(t) ||
              e.matricule.toLowerCase().contains(t))
          .toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Eleves - ${widget.classe}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher (nom, prenom, matricule)',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
        ),
      ),
      body: eleves.isEmpty
          ? const EmptyState(message: 'Aucun eleve. Appuyez sur + pour en ajouter.', icone: Icons.group_outlined)
          : ListView.builder(
              itemCount: eleves.length,
              itemBuilder: (_, i) {
                final e = eleves[i];
                return Card(
                  child: ListTile(
                    leading: imageBase64(e.photoBase64),
                    title: Text(e.nomComplet, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.matricule} - ${e.sexe == 'M' ? 'Garcon' : 'Fille'} - ${e.statut}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: WA.green),
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => EleveForm(classe: widget.classe, eleve: e))),
                      ),
                      const Icon(Icons.chevron_right, color: WA.grey),
                    ]),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => EleveDetail(eleveId: e.id))),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel eleve'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => EleveForm(classe: widget.classe))),
      ),
      bottomNavigationBar: Container(
        color: WA.bubble,
        padding: const EdgeInsets.all(10),
        child: Text(
          'Effectif : ${s.elevesDe(widget.classe).length}  |  '
          'Garcons : ${s.elevesDe(widget.classe).where((e) => e.sexe == 'M').length}  |  '
          'Filles : ${s.elevesDe(widget.classe).where((e) => e.sexe == 'F').length}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: WA.teal),
        ),
      ),
    );
  }
}
