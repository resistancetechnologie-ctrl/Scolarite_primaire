import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../widgets/common.dart';
import '../eleves/eleve_detail.dart';

class RechercheScreen extends StatefulWidget {
  const RechercheScreen({super.key});

  @override
  State<RechercheScreen> createState() => _RechercheScreenState();
}

class _RechercheScreenState extends State<RechercheScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final res = s.rechercher(q);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche rapide'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Nom, prenom ou matricule', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
        ),
      ),
      body: q.isEmpty
          ? const EmptyState(message: 'Saisissez un nom, un prenom ou un matricule.', icone: Icons.search)
          : res.isEmpty
              ? const EmptyState(message: 'Aucun resultat.')
              : ListView(
                  children: res
                      .map((e) => Card(
                            child: ListTile(
                              leading: imageBase64(e.photoBase64),
                              title: Text(e.nomComplet),
                              subtitle: Text('${e.matricule} - ${e.classe} - ${e.anneeScolaire}'),
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => EleveDetail(eleveId: e.id))),
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
