import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ConfigEcoleScreen extends StatefulWidget {
  const ConfigEcoleScreen({super.key});

  @override
  State<ConfigEcoleScreen> createState() => _ConfigEcoleScreenState();
}

class _ConfigEcoleScreenState extends State<ConfigEcoleScreen> {
  late TextEditingController nom, devise, adresse, tel, email, directeur, annee, pinD, pinE, seuilAbs;
  final Map<String, TextEditingController> seuils = {};

  @override
  void initState() {
    super.initState();
    final e = context.read<AppState>().ecole;
    nom = TextEditingController(text: e.nom);
    devise = TextEditingController(text: e.devise);
    adresse = TextEditingController(text: e.adresse);
    tel = TextEditingController(text: e.telephone);
    email = TextEditingController(text: e.email);
    directeur = TextEditingController(text: e.nomDirecteur);
    annee = TextEditingController(text: e.anneeScolaire);
    pinD = TextEditingController(text: e.pinDirecteur);
    pinE = TextEditingController(text: e.pinEnseignant);
    seuilAbs = TextEditingController(text: '${e.seuilAbsences}');
    for (final k in Ecole.mentionsParDefaut.keys) {
      seuils[k] = TextEditingController(text: '${e.seuilsMentions[k] ?? Ecole.mentionsParDefaut[k]}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text("Configuration de l'ecole")),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        SectionCard(titre: "Identite de l'ecole", icone: Icons.school, children: [
          _c(nom, "Nom de l'ecole"),
          _c(devise, 'Devise'),
          _c(adresse, 'Adresse'),
          _c(tel, 'Telephone'),
          _c(email, 'E-mail'),
          _c(directeur, 'Nom du directeur'),
          _c(annee, 'Annee scolaire (ex: 2026-2027)'),
        ]),
        SectionCard(titre: 'Logo, signature et cachet', icone: Icons.approval, children: [
          const Text(
              'Si la signature et le cachet ne sont pas importes, les bulletins laisseront '
              'des espaces reserves pour une apposition manuelle apres impression.',
              style: TextStyle(fontSize: 12, color: WA.grey)),
          const SizedBox(height: 8),
          _imageRow(s, 'Logo de l\'ecole', s.ecole.logoBase64, (b) => s.ecole.logoBase64 = b),
          _imageRow(s, 'Signature du directeur', s.ecole.signatureBase64, (b) => s.ecole.signatureBase64 = b),
          _imageRow(s, 'Cachet officiel', s.ecole.cachetBase64, (b) => s.ecole.cachetBase64 = b),
        ]),
        SectionCard(titre: 'Options', icone: Icons.tune, children: [
          SwitchListTile(
            value: s.ecole.photosActivees,
            title: const Text('Photos des eleves activees'),
            onChanged: (v) {
              s.ecole.photosActivees = v;
              s.save();
            },
          ),
          _c(seuilAbs, "Seuil d'alerte absences"),
          _c(pinD, 'Code PIN Directeur', pin: true),
          _c(pinE, 'Code PIN Enseignant (par defaut)', pin: true),
        ]),
        SectionCard(titre: 'Seuils des mentions (sur 10)', icone: Icons.workspace_premium, children: [
          ...seuils.entries.map((e) => _c(e.value, e.key)),
        ]),
        SectionCard(titre: 'Salles / classes', icone: Icons.meeting_room, children: [
          const Text(
              "Une ecole peut avoir plusieurs salles pour un meme niveau "
              "(ex: CP1 A, CP1 B, CP1 C). Dupliquez une salle pour en creer une "
              "nouvelle du meme niveau, avec les memes matieres.",
              style: TextStyle(fontSize: 12, color: WA.grey)),
          const SizedBox(height: 8),
          for (final niveau in Classes.all) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(niveau, style: const TextStyle(fontWeight: FontWeight.bold, color: WA.teal)),
            ),
            ...s.sallesDuNiveau(niveau).map((salle) {
              final nbEleves = s.elevesDe(salle, actifsSeulement: false).length;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.door_front_door, color: WA.green),
                title: Text(salle),
                subtitle: Text('$nbEleves eleve(s)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Dupliquer (nouvelle section du meme niveau)',
                    icon: const Icon(Icons.copy, color: WA.teal),
                    onPressed: () async {
                      final nouvelle = await s.dupliquerSalle(salle);
                      if (!context.mounted) return;
                      if (nouvelle == null) {
                        showError(context, "Impossible de dupliquer (nom deja pris ou limite atteinte).");
                      } else {
                        showOk(context, 'Salle "$nouvelle" creee.');
                        setState(() {});
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Renommer',
                    icon: const Icon(Icons.edit, color: WA.grey),
                    onPressed: () => _renommerSalle(context, s, salle),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline, color: WA.danger),
                    onPressed: () async {
                      if (nbEleves > 0) {
                        showError(context,
                            'Impossible de supprimer : $nbEleves eleve(s) encore inscrit(s) dans cette salle.');
                        return;
                      }
                      if (!await confirmer(context, 'Supprimer la salle',
                          'Supprimer la salle "$salle" ? Cette action est irreversible.')) {
                        return;
                      }
                      await s.supprimerSalle(salle);
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
              );
            }),
            if (s.sallesDuNiveau(niveau).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text('Ouvrir une salle de $niveau'),
                  onPressed: () async {
                    await s.ajouterSalle(niveau);
                    if (mounted) setState(() {});
                  },
                ),
              ),
          ],
        ]),
        SectionCard(titre: 'Enseignants par salle', icone: Icons.person, children: [
          ...s.salles.map((c) {
            final ens = s.enseignantDe(c);
            return ListTile(
              dense: true,
              leading: CircleAvatar(backgroundColor: WA.bubble, child: Text(c, style: const TextStyle(fontSize: 9, color: WA.teal))),
              title: Text(ens.nomComplet.isEmpty ? 'Non renseigne' : ens.nomComplet),
              subtitle: Text('Salle $c - ${Matieres.nomsPourClasse(c).length} matieres'),
              trailing: const Icon(Icons.edit, color: WA.green),
              onTap: () => _editEnseignant(context, s, c),
            );
          }),
        ]),
        SectionCard(titre: 'Donnees de test', icone: Icons.science, children: [
          const Text(
              'Remplissez rapidement l\'application avec des eleves, notes, presences... '
              'a partir d\'un fichier JSON, pour tester l\'application avant de saisir les '
              'vraies donnees.',
              style: TextStyle(fontSize: 12, color: WA.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Importer des donnees de test (JSON)'),
            onPressed: () async {
              final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
              if (res == null || res.files.single.path == null) return;
              if (!context.mounted) return;
              if (!await confirmer(context, 'Importer des donnees de test',
                  'Les eleves, notes et autres donnees du fichier seront ajoutes ou mis a jour '
                  '(une sauvegarde automatique sera creee avant l\'import).')) {
                return;
              }
              try {
                final map = Map<String, dynamic>.from(
                    jsonDecode(await File(res.files.single.path!).readAsString()));
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Row(children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Expanded(child: Text('Import en cours, cela peut prendre quelques instants...')),
                    ]),
                  ),
                );
                try {
                  final msg = await SyncService.importerDonneesTest(s, map);
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) showOk(context, msg);
                } catch (e) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) showError(context, 'Erreur : $e');
                }
              } catch (e) {
                if (context.mounted) showError(context, 'Erreur : $e');
              }
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.description),
            label: const Text('Telecharger un exemple de fichier'),
            onPressed: () async {
              final txt = const JsonEncoder.withIndent('  ').convert(SyncService.modeleDonneesTest());
              final f = await s.store.writeExportString('exemple_donnees_test.json', txt);
              if (!context.mounted) return;
              await SharePlus.instance.share(
                ShareParams(files: [XFile(f.path)], text: 'Exemple de donnees de test'),
              );
            },
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer la configuration'),
            onPressed: () async {
              final e = s.ecole;
              e.nom = nom.text.trim();
              e.devise = devise.text.trim();
              e.adresse = adresse.text.trim();
              e.telephone = tel.text.trim();
              e.email = email.text.trim();
              e.nomDirecteur = directeur.text.trim();
              e.anneeScolaire = annee.text.trim();
              e.pinDirecteur = pinD.text.trim().isEmpty ? '1234' : pinD.text.trim();
              // FAILLE CORRIGEE : un PIN enseignant vide desactivait le
              // controle d'acces (voir login_screen). On retombe sur un
              // defaut non-vide, comme pour le PIN directeur.
              e.pinEnseignant = pinE.text.trim().isEmpty ? '0000' : pinE.text.trim();
              e.seuilAbsences = int.tryParse(seuilAbs.text.trim()) ?? 5;
              for (final k in seuils.keys) {
                e.seuilsMentions[k] = double.tryParse(seuils[k]!.text.replaceAll(',', '.')) ??
                    Ecole.mentionsParDefaut[k]!;
              }
              s.log('CONFIG_ECOLE', cible: e.nom);
              await s.save(backup: true, tag: 'config');
              if (context.mounted) showOk(context, 'Configuration enregistree.');
            },
          ),
        ),
      ]),
    );
  }

  Widget _c(TextEditingController c, String label, {bool pin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          obscureText: pin,
          keyboardType: pin ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  Widget _imageRow(AppState s, String titre, String b64, void Function(String) setter) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: b64.isEmpty
          ? const CircleAvatar(backgroundColor: WA.divider, child: Icon(Icons.image, color: WA.grey))
          : CircleAvatar(backgroundImage: MemoryImage(base64Decode(b64))),
      title: Text(titre),
      subtitle: Text(b64.isEmpty ? 'Non defini (espace reserve)' : 'Defini',
          style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.upload, color: WA.green),
          onPressed: () async {
            final b = await choisirImageBase64(maxWidth: 600, quality: 80);
            if (b != null) {
              setter(b);
              await s.save();
              if (mounted) setState(() {});
            }
          },
        ),
        if (b64.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete, color: WA.danger),
            onPressed: () async {
              setter('');
              await s.save();
              if (mounted) setState(() {});
            },
          ),
      ]),
    );
  }

  Future<void> _renommerSalle(BuildContext context, AppState s, String ancien) async {
    final ctrl = TextEditingController(text: ancien);
    final nouveau = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renommer la salle'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nom de la salle (ex: CP1 A)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Renommer')),
        ],
      ),
    );
    if (nouveau == null || nouveau.isEmpty || nouveau == ancien) return;
    final ok = await s.renommerSalle(ancien, nouveau);
    if (!context.mounted) return;
    if (ok) {
      showOk(context, 'Salle renommee en "$nouveau".');
      setState(() {});
    } else {
      showError(context, 'Ce nom de salle existe deja ou est invalide.');
    }
  }

  Future<void> _editEnseignant(BuildContext context, AppState s, String classe) async {
    final ens = s.enseignantDe(classe);
    final n = TextEditingController(text: ens.nomComplet);
    final t = TextEditingController(text: ens.telephone);
    final p = TextEditingController(text: ens.pin);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enseignant de $classe'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: 8),
          TextField(controller: t, decoration: const InputDecoration(labelText: 'Telephone')),
          const SizedBox(height: 8),
          TextField(
            controller: p,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Code PIN personnel'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      await s.setEnseignant(classe, n.text.trim(), tel: t.text.trim(), pin: p.text.trim());
      if (mounted) setState(() {});
    }
  }
}
