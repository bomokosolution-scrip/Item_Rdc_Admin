import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc_admin/util/folder_icons.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/util/sorting.dart';
import 'package:item_rdc_admin/util/supabase_storage.dart';
import 'package:item_rdc_admin/widgets/image_import.dart';

/// Bandeau d'en-tête dégradé, dans le prolongement de l'AppBar.
class BrandHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BrandHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.headerGradient(context),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille d'icône teintée (carré arrondi).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconBadge({super.key, required this.icon, this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: c, size: size * 0.52),
    );
  }
}

/// Titre de section avec compteur.
class SectionTitle extends StatelessWidget {
  final String text;
  final int? count;
  final IconData? icon;

  const SectionTitle(this.text, {super.key, this.count, this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Petite pastille (compteur, statut...).
class InfoPill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const InfoPill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, size: 72),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Champ de saisie avec icône (utilise le thème global).
class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// Affiche les boutons Coller et Effacer.
  final bool showActions;

  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType,
    this.onChanged,
    this.showActions = true,
  });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    final sel = controller.selection;
    final current = controller.text;
    String result;
    int offset;
    if (sel.isValid && sel.start >= 0 && sel.end <= current.length) {
      result = current.replaceRange(sel.start, sel.end, text);
      offset = sel.start + text.length;
    } else {
      result = current + text;
      offset = result.length;
    }
    controller.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: offset),
    );
    onChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
          suffixIcon: !showActions
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value.text.isNotEmpty)
                      IconButton(
                        tooltip: "Clear",
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          controller.clear();
                          onChanged?.call('');
                        },
                      ),
                    IconButton(
                      tooltip: "Paste",
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      onPressed: _paste,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Ligne de boutons Annuler / Valider pour les feuilles modales.
class SheetActions extends StatelessWidget {
  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String cancelLabel;

  const SheetActions({
    super.key,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmIcon = Icons.check_rounded,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel ?? () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onConfirm,
            icon: Icon(confirmIcon, size: 20),
            label: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}

/// Feuille modale standard : poignée, titre, contenu défilant, clavier géré.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  IconData? icon,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerTheme.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (icon != null) ...[
                        IconBadge(icon: icon),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  builder(ctx),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Boîte de confirmation de suppression.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.delete_outline_rounded,
        color: Theme.of(ctx).colorScheme.error,
        size: 32,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Barre de recherche à intégrer dans une AppBar.
class AppBarSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const AppBarSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onChanged: onChanged,
    );
  }
}

/// Apparition douce (fondu + glissement), sans contrôleur.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final i = index > 8 ? 8 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + i * 50),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Message court (succès / erreur).
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? const Color(0xFFB3261E) : null,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Icône d'un dossier : image (URL) > icône prédéfinie > icône par défaut.
class FolderIconBadge extends StatelessWidget {
  final String? iconKey;
  final String? iconUrl;
  final double size;
  final IconData fallback;

  const FolderIconBadge({
    super.key,
    this.iconKey,
    this.iconUrl,
    this.size = 42,
    this.fallback = Icons.folder_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final url = (iconUrl ?? '').trim();
    final preset = FolderIcons.byKey(iconKey);
    final badge = IconBadge(icon: preset ?? fallback, size: size);
    if (url.isEmpty) return badge;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: SupabaseStorage.recent[url] != null
            ? Image.memory(SupabaseStorage.recent[url]!, fit: BoxFit.cover)
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => badge,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : badge,
              ),
      ),
    );
  }
}

/// Choix de l'icône d'un dossier : URL d'image OU icône prédéfinie.
class FolderIconPicker extends StatelessWidget {
  final TextEditingController urlController;
  final String? selectedKey;
  final ValueChanged<String?> onKeyChanged;

  const FolderIconPicker({
    super.key,
    required this.urlController,
    required this.selectedKey,
    required this.onKeyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: urlController,
              builder: (context, v, _) => FolderIconBadge(
                iconKey: selectedKey,
                iconUrl: v.text,
                size: 52,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Folder icon",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    "Paste an image URL or pick an icon (shown in the user app)",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppField(
          controller: urlController,
          label: "Icon image URL (optional)",
          icon: Icons.image_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        ImageImportButton(
          controller: urlController,
          folder: 'icons',
          maxSide: 192,
          label: "Import icon from gallery",
        ),
        const SizedBox(height: 14),
        Text(
          "OR PICK AN ICON",
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in FolderIcons.options)
              Tooltip(
                message: o.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onKeyChanged(selectedKey == o.key ? null : o.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selectedKey == o.key
                          ? accent
                          : accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      o.icon,
                      size: 24,
                      color: selectedKey == o.key
                          ? (theme.brightness == Brightness.dark ? AppColors.brandDark : Colors.white)
                          : accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}


/// Barre de tri : un bouton « pilule » qui ouvre le menu des modes de tri
/// (récents, anciens, A → Z, Z → A, plus de contenu) + un compteur optionnel.
class SortBar extends StatelessWidget {
  final SortMode value;
  final ValueChanged<SortMode> onChanged;
  final String? trailing;
  final bool allowCount;
  final EdgeInsetsGeometry padding;

  const SortBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.trailing,
    this.allowCount = true,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 2),
  });

  static String labelOf(SortMode m) {
    switch (m) {
      case SortMode.newest:
        return 'Newest first';
      case SortMode.oldest:
        return 'Oldest first';
      case SortMode.az:
        return 'A → Z';
      case SortMode.za:
        return 'Z → A';
      case SortMode.most:
        return 'Most content';
    }
  }

  static IconData iconOf(SortMode m) {
    switch (m) {
      case SortMode.newest:
        return Icons.schedule_rounded;
      case SortMode.oldest:
        return Icons.history_rounded;
      case SortMode.az:
        return Icons.sort_by_alpha_rounded;
      case SortMode.za:
        return Icons.sort_by_alpha_rounded;
      case SortMode.most:
        return Icons.folder_copy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final modes = [
      SortMode.newest,
      SortMode.oldest,
      SortMode.az,
      SortMode.za,
      if (allowCount) SortMode.most,
    ];
    final current = modes.contains(value) ? value : SortMode.newest;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          PopupMenuButton<SortMode>(
            tooltip: 'Sort',
            initialValue: current,
            onSelected: onChanged,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (ctx) => [
              for (final m in modes)
                PopupMenuItem<SortMode>(
                  value: m,
                  child: Row(
                    children: [
                      Icon(
                        iconOf(m),
                        size: 20,
                        color: m == current ? accent : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          labelOf(m),
                          style: TextStyle(
                            fontWeight: m == current ? FontWeight.w800 : FontWeight.w500,
                            color: m == current ? accent : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (m == current) Icon(Icons.check_rounded, size: 18, color: accent),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    labelOf(current),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 20, color: accent),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
        ],
      ),
    );
  }
}
