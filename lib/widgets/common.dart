import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

/// Barre d'actions PDF : apercu / impression / partage.
class PdfActions extends StatelessWidget {
  final Future<Uint8List> Function() builder;
  final String nom;
  final String label;
  final IconData icone;

  const PdfActions({
    super.key,
    required this.builder,
    required this.nom,
    this.label = 'Generer le PDF',
    this.icone = Icons.picture_as_pdf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          icon: Icon(icone),
          label: Text(label),
          onPressed: () async {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()));
            try {
              final bytes = await builder();
              if (context.mounted) Navigator.pop(context);
              await PdfService.apercu(bytes, nom);
            } catch (e) {
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) showError(context, "Erreur : $e");
            }
          },
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Partager / Enregistrer',
        icon: const Icon(Icons.share, color: WA.green),
        onPressed: () async {
          try {
            await PdfService.partager(await builder(), nom);
          } catch (e) {
            if (context.mounted) showError(context, "Erreur : $e");
          }
        },
      ),
    ]);
  }
}

class SectionCard extends StatelessWidget {
  final String titre;
  final IconData icone;
  final List<Widget> children;
  const SectionCard({super.key, required this.titre, required this.icone, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icone, color: WA.teal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WA.teal)),
            ),
          ]),
          const Divider(),
          ...children,
        ]),
      ),
    );
  }
}

class ClassePicker extends StatelessWidget {
  final String valeur;
  final List<String> classes;
  final ValueChanged<String> onChanged;
  const ClassePicker({super.key, required this.valeur, required this.classes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: classes
          .map((c) => ChoiceChip(
                label: Text(c),
                selected: c == valeur,
                selectedColor: WA.bubble,
                onSelected: (_) => onChanged(c),
              ))
          .toList(),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icone;
  const EmptyState({super.key, required this.message, this.icone = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, size: 56, color: WA.grey.withOpacity(.5)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: WA.grey)),
          ]),
        ),
      );
}

void showOk(BuildContext c, String msg) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: WA.green));

void showError(BuildContext c, String msg) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: WA.danger));

Future<bool> confirmer(BuildContext context, String titre, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
      ],
    ),
  );
  return r ?? false;
}

/// Selection d'une image et conversion en base64 (photo, logo, signature, cachet).
Future<String?> choisirImageBase64({int maxWidth = 800, int quality = 70}) async {
  final picker = ImagePicker();
  final x = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: maxWidth.toDouble(), imageQuality: quality);
  if (x == null) return null;
  return base64Encode(await x.readAsBytes());
}

Future<String?> prendrePhotoBase64() async {
  final picker = ImagePicker();
  final x = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
  if (x == null) return null;
  return base64Encode(await x.readAsBytes());
}

Widget imageBase64(String b64, {double size = 48, IconData fallback = Icons.person}) {
  if (b64.isEmpty) {
    return CircleAvatar(radius: size / 2, backgroundColor: WA.bubble, child: Icon(fallback, color: WA.teal));
  }
  try {
    return CircleAvatar(radius: size / 2, backgroundImage: MemoryImage(base64Decode(b64)));
  } catch (_) {
    return CircleAvatar(radius: size / 2, backgroundColor: WA.bubble, child: Icon(fallback));
  }
}

class MenuTile extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;
  const MenuTile(
      {super.key, required this.icone, required this.titre, this.sousTitre = '', required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: WA.bubble, child: Icon(icone, color: WA.teal)),
          title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: sousTitre.isEmpty ? null : Text(sousTitre, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: WA.grey),
          onTap: onTap,
        ),
      );
}
