import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/supabase_storage.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

/// Bouton « Importer depuis la galerie » : choisit une image, la réduit, l'envoie
/// sur Supabase puis écrit son URL dans [controller].
class ImageImportButton extends StatefulWidget {
  final TextEditingController controller;

  /// Dossier de rangement dans le bucket (icons, covers, logos…).
  final String folder;

  /// Plus grand côté de l'image envoyée (icônes : 192, couvertures : 512).
  final int maxSide;
  final String label;

  const ImageImportButton({
    super.key,
    required this.controller,
    this.folder = 'icons',
    this.maxSide = 192,
    this.label = "Import from gallery",
  });

  @override
  State<ImageImportButton> createState() => _ImageImportButtonState();
}

class _ImageImportButtonState extends State<ImageImportButton> {
  bool _busy = false;

  Future<void> _pick() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final bytes = await file.readAsBytes();
      final url = await SupabaseStorage.uploadImage(
        bytes,
        folder: widget.folder,
        maxSide: widget.maxSide,
      );
      if (!mounted) return;
      widget.controller.text = url;
      messenger?.showSnackBar(const SnackBar(content: Text("Image uploaded ✓")));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _pick,
        icon: _busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            : const Icon(Icons.add_photo_alternate_rounded, size: 20),
        label: Text(_busy ? "Uploading…" : widget.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// Champs facultatifs d'un fichier : couverture (URL ou import), propriétaire, détails.
class FileExtrasFields extends StatelessWidget {
  final TextEditingController cover;
  final TextEditingController owner;
  final TextEditingController? details;

  const FileExtrasFields({
    super.key,
    required this.cover,
    required this.owner,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        AppField(
          controller: cover,
          label: "Cover image URL (optional)",
          icon: Icons.image_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        ImageImportButton(
          controller: cover,
          folder: 'covers',
          maxSide: 512,
          label: "Import cover from gallery",
        ),
        const SizedBox(height: 12),
        AppField(
          controller: owner,
          label: "Owner / author name (optional)",
          icon: Icons.person_rounded,
        ),
        if (details != null) ...[
          const SizedBox(height: 12),
          AppField(
            controller: details!,
            label: "Details (optional)",
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
        ],
      ],
    );
  }
}

/// Champs facultatifs à fusionner dans un fichier (cover / owner / details).
/// [withDate] ajoute la date d'ajout (fichiers rangés dans un tableau).
Map<String, dynamic> fileExtras({
  String cover = '',
  String owner = '',
  String details = '',
  bool withDate = false,
}) => {
  if (cover.trim().isNotEmpty) 'cover': cover.trim(),
  if (owner.trim().isNotEmpty) 'owner': owner.trim(),
  if (details.trim().isNotEmpty) 'details': details.trim(),
  if (withDate) 'createdAt': Timestamp.now(),
};

/// Valeurs à écrire dans un document Firestore : champ vidé = champ supprimé.
Map<String, dynamic> extrasUpdate(Map<String, String> values) => {
  for (final e in values.entries)
    e.key: e.value.trim().isEmpty ? FieldValue.delete() : e.value.trim(),
};

/// Feuille « Cover & details » : modifier la couverture, le propriétaire et les
/// détails d'un fichier déjà ajouté.
void showEditExtrasSheet(
  BuildContext context, {
  required String fileTitle,
  required Map current,
  required Future<void> Function(Map<String, String> values) onSave,
}) {
  final cover = TextEditingController(text: (current['cover'] ?? '').toString());
  final owner = TextEditingController(text: (current['owner'] ?? '').toString());
  final details = TextEditingController(text: (current['details'] ?? '').toString());

  showAppSheet(
    context,
    title: "Cover & details",
    subtitle: fileTitle,
    icon: Icons.image_rounded,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FileExtrasFields(cover: cover, owner: owner, details: details),
        const SizedBox(height: 16),
        SheetActions(
          confirmLabel: "Save",
          onConfirm: () async {
            Navigator.pop(ctx);
            try {
              await onSave({
                'cover': cover.text,
                'owner': owner.text,
                'details': details.text,
              });
            } catch (e) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text("Could not save: $e")),
              );
            }
          },
        ),
      ],
    ),
  );
}

/// Boutons d'un fichier : modifier la couverture + supprimer.
class FileTrailing extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const FileTrailing({super.key, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "Cover & details",
          onPressed: onEdit,
          icon: Icon(Icons.image_outlined, color: AppColors.accent(context)),
        ),
        IconButton(
          tooltip: "Delete",
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
        ),
      ],
    );
  }
}
