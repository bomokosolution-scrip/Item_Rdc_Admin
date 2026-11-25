import 'package:flutter/material.dart';
import 'package:item_rdc_admin/core/push_sender.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

/// Envoi d'une notification push à tous les utilisateurs.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showToast(context, "Le titre et le message sont obligatoires", error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Envoyer à tous ?"),
        content: Text("\"$title\"\n\n$body"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Envoyer")),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    final result = await PushSender.send(title: title, body: body);
    if (!mounted) return;
    setState(() => _sending = false);
    showToast(context, result.message, error: !result.ok);
    if (result.ok) {
      _title.clear();
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!PushSender.configured)
            Card(
              color: theme.colorScheme.errorContainer,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Relais non configuré. Renseignez l'adresse et la clé dans lib/core/push_config.dart.",
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Message à tous les utilisateurs",
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Reçu sur leur téléphone même si l'application est fermée.",
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  AppField(
                    controller: _title,
                    label: "Titre",
                    icon: Icons.title_rounded,
                    showActions: false,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _body,
                    label: "Message",
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sending ? "Envoi…" : "Envoyer à tous"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Pour écrire à une seule personne, ouvrez sa fiche dans « User info » puis touchez « Notify ».",
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Boîte d'envoi d'une notification à un seul utilisateur (depuis « User info »).
Future<void> showUserNotificationDialog(
  BuildContext context, {
  required String name,
  required String? token,
}) async {
  if (token == null || token.isEmpty) {
    showToast(
      context,
      "Cet utilisateur n'a pas encore activé les notifications",
      error: true,
    );
    return;
  }
  final title = TextEditingController();
  final body = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Notifier $name"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: "Titre")),
            const SizedBox(height: 10),
            TextField(
              controller: body,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Message"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Envoyer")),
      ],
    ),
  );
  if (ok != true) return;

  final t = title.text.trim();
  final b = body.text.trim();
  if (t.isEmpty || b.isEmpty) {
    if (context.mounted) {
      showToast(context, "Le titre et le message sont obligatoires", error: true);
    }
    return;
  }
  final result = await PushSender.send(title: t, body: b, token: token);
  if (context.mounted) showToast(context, result.message, error: !result.ok);
}
