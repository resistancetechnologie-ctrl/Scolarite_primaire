import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../services/pdf_service.dart';
import '../../widgets/common.dart';

/// Documents administratifs + communication ecole-parents.
class DocumentsAdminScreen extends StatefulWidget {
  final String eleveId;
  const DocumentsAdminScreen({super.key, required this.eleveId});

  @override
  State<DocumentsAdminScreen> createState() => _DocumentsAdminScreenState();
}

class _DocumentsAdminScreenState extends State<DocumentsAdminScreen> {
  final texte = TextEditingController();

  static const types = [
    'Attestation de scolarite',
    'Certificat de frequentation',
    'Certificat de transfert',
    'Convocation des parents',
    "Fiche d'information aux parents",
    'Carte scolaire',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final e = s.eleveParId(widget.eleveId);
    if (e == null) return const Scaffold(body: EmptyState(message: 'Eleve introuvable.'));

    return Scaffold(
      appBar: AppBar(title: const Text('Documents administratifs')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        Card(
          child: ListTile(
            leading: imageBase64(e.photoBase64),
            title: Text(e.nomComplet),
            subtitle: Text('${e.matricule} - ${e.classe}'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: texte,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Texte libre / objet (convocations, messages aux parents)',
              ),
            ),
          ),
        ),
        for (final t in types)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: PdfActions(
              builder: () => PdfService.documentAdministratif(s, e, t, texteLibre: texte.text.trim()),
              nom: '${t.replaceAll(' ', '_')}_${e.matricule}.pdf',
              label: t,
              icone: Icons.description,
            ),
          ),
      ]),
    );
  }
}
