import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class EleveForm extends StatefulWidget {
  final String classe;
  final Eleve? eleve;
  const EleveForm({super.key, required this.classe, this.eleve});

  @override
  State<EleveForm> createState() => _EleveFormState();
}

class _EleveFormState extends State<EleveForm> {
  final _form = GlobalKey<FormState>();
  late TextEditingController nom, prenom, lieu, parent, tel, adresse, matricule;
  String sexe = 'M';
  String groupe = 'Moyen';
  DateTime? naissance;
  String photo = '';

  @override
  void initState() {
    super.initState();
    final e = widget.eleve;
    nom = TextEditingController(text: e?.nom ?? '');
    prenom = TextEditingController(text: e?.prenom ?? '');
    lieu = TextEditingController(text: e?.lieuNaissance ?? '');
    parent = TextEditingController(text: e?.nomParent ?? '');
    tel = TextEditingController(text: e?.telParent ?? '');
    adresse = TextEditingController(text: e?.adresse ?? '');
    matricule = TextEditingController(text: e?.matricule ?? '');
    sexe = e?.sexe ?? 'M';
    groupe = e?.groupeNiveau ?? 'Moyen';
    naissance = e?.dateNaissance;
    photo = e?.photoBase64 ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.eleve == null ? 'Nouvel eleve' : 'Modifier l\'eleve')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Center(
            child: Column(children: [
              imageBase64(photo, size: 96),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                  onPressed: () async {
                    final b = await choisirImageBase64();
                    if (b != null) setState(() => photo = b);
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                  onPressed: () async {
                    final b = await prendrePhotoBase64();
                    if (b != null) setState(() => photo = b);
                  },
                ),
                if (photo.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete, color: WA.danger),
                    label: const Text('Retirer', style: TextStyle(color: WA.danger)),
                    onPressed: () => setState(() => photo = ''),
                  ),
              ]),
            ]),
          ),
          _champ(nom, 'Nom *', requis: true),
          _champ(prenom, 'Prenoms *', requis: true),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: sexe,
                decoration: const InputDecoration(labelText: 'Sexe'),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Garcon')),
                  DropdownMenuItem(value: 'F', child: Text('Fille')),
                ],
                onChanged: (v) => setState(() => sexe = v ?? 'M'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: groupe,
                decoration: const InputDecoration(labelText: 'Groupe de niveau'),
                items: const [
                  DropdownMenuItem(value: 'Avance', child: Text('Avance')),
                  DropdownMenuItem(value: 'Moyen', child: Text('Moyen')),
                  DropdownMenuItem(value: 'Difficulte', child: Text('En difficulte')),
                ],
                onChanged: (v) => setState(() => groupe = v ?? 'Moyen'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: const Icon(Icons.cake, color: WA.green),
            title: Text(naissance == null
                ? 'Date de naissance'
                : DateFormat('dd/MM/yyyy').format(naissance!)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: naissance ?? DateTime(DateTime.now().year - 8),
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => naissance = d);
            },
          ),
          const SizedBox(height: 10),
          _champ(lieu, 'Lieu de naissance'),
          _champ(parent, 'Nom du parent / tuteur'),
          _champ(tel, 'Telephone du parent'),
          _champ(adresse, 'Adresse'),
          _champ(matricule, 'Matricule (auto si vide)'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              if (widget.eleve == null) {
                await s.ajouterEleve(Eleve(
                  nom: nom.text.trim(), prenom: prenom.text.trim(), sexe: sexe,
                  dateNaissance: naissance, lieuNaissance: lieu.text.trim(),
                  classe: widget.classe, photoBase64: photo, nomParent: parent.text.trim(),
                  telParent: tel.text.trim(), adresse: adresse.text.trim(),
                  groupeNiveau: groupe, matricule: matricule.text.trim(),
                ));
              } else {
                final e = widget.eleve!;
                e.nom = nom.text.trim();
                e.prenom = prenom.text.trim();
                e.sexe = sexe;
                e.dateNaissance = naissance;
                e.lieuNaissance = lieu.text.trim();
                e.nomParent = parent.text.trim();
                e.telParent = tel.text.trim();
                e.adresse = adresse.text.trim();
                e.groupeNiveau = groupe;
                e.photoBase64 = photo;
                if (matricule.text.trim().isNotEmpty) e.matricule = matricule.text.trim();
                await s.majEleve(e);
              }
              if (context.mounted) {
                showOk(context, 'Eleve enregistre.');
                Navigator.pop(context);
              }
            },
          ),
        ]),
      ),
    );
  }

  Widget _champ(TextEditingController c, String label, {bool requis = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: label),
          validator: requis ? (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null : null,
        ),
      );
}
