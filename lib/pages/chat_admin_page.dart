import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Modération du chat : ouverture du groupe, messages, signalements, suspensions.
class ChatAdminPage extends StatelessWidget {
  const ChatAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Chat"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Messages"),
              Tab(text: "Help"),
              Tab(text: "Reports"),
              Tab(text: "Suspended"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MessagesTab(), _HelpTab(), _ReportsTab(), _BansTab()],
        ),
      ),
    );
  }
}

/// Actions de modération partagées par les trois onglets.
class _Mod {
  _Mod._();

  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get messages =>
      db.collection('chat_rooms').doc('general').collection('messages');

  static void snack(BuildContext c, String m) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  static Future<void> deleteMessage(String id) => messages.doc(id).delete();

  static Future<void> unban(String uid) => db.collection('chat_bans').doc(uid).delete();

  /// Libère le pseudo : l'utilisateur pourra en choisir un nouveau.
  static Future<void> resetPseudo(String uid, String pseudo) async {
    final b = db.batch();
    b.delete(db.collection('chat_profiles').doc(uid));
    if (pseudo.isNotEmpty) b.delete(db.collection('chat_pseudos').doc(pseudo.toLowerCase()));
    await b.commit();
  }

  static Future<void> ban(BuildContext context, String uid, String pseudo) async {
    if (uid.isEmpty) return;
    final reason = TextEditingController();
    int choice = 1; // index dans _options
    const labels = ["1 hour", "24 hours", "7 days", "30 days", "Permanent"];
    const durations = [
      Duration(hours: 1),
      Duration(hours: 24),
      Duration(days: 7),
      Duration(days: 30),
      null,
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text("Suspend $pseudo"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < labels.length; i++)
                    ChoiceChip(
                      label: Text(labels[i]),
                      selected: choice == i,
                      onSelected: (_) => setS(() => choice = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Reason (shown to the user)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Suspend")),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final d = durations[choice];
    try {
      await db.collection('chat_bans').doc(uid).set({
        'until': d == null ? null : Timestamp.fromDate(DateTime.now().add(d)),
        'reason': reason.text.trim(),
        'pseudo': pseudo,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) snack(context, "$pseudo suspended ✓");
    } catch (e) {
      if (context.mounted) snack(context, "Could not suspend: $e");
    }
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'help':
      return 'Help';
    case 'dm':
      return 'Private message';
    default:
      return 'Group';
  }
}

String _when(Object? t) {
  if (t is Timestamp) return DateFormat('dd/MM HH:mm').format(t.toDate());
  return '…';
}

// ---------------------------------------------------------------- Messages
class _MessagesTab extends StatefulWidget {
  const _MessagesTab();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _Mod.messages
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();
  final _settings = FirebaseFirestore.instance.collection('settings').doc('chat');

  Widget _switch(
    Map<String, dynamic>? data,
    String field,
    String title,
    String subtitleOn,
    String subtitleOff,
    IconData icon,
  ) {
    final accent = AppColors.accent(context);
    final on = data?[field] == true;
    return SwitchListTile(
      value: on,
      activeThumbColor: accent,
      secondary: Icon(icon, color: accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(on ? subtitleOn : subtitleOff),
      onChanged: (v) => _settings.set({
        field: v,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Widget _switchCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _settings.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              _switch(data, 'generalEnabled', "General group",
                  "Open to all signed-in users.", "Closed.", Icons.groups_rounded),
              const Divider(height: 1),
              _switch(data, 'helpEnabled', "Help space (images)",
                  "Users can post and answer.", "Closed.", Icons.support_rounded),
              const Divider(height: 1),
              _switch(data, 'dmEnabled', "Private messages",
                  "Users can contact authors.", "Closed.", Icons.mail_rounded),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        final docs = snap.data?.docs ?? const <_Doc>[];
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _switchCard(),
            if (snap.connectionState == ConnectionState.waiting && docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "No messages yet",
                ),
              ),
            for (final m in docs) _tile(m),
          ],
        );
      },
    );
  }

  Widget _tile(_Doc m) {
    final d = m.data();
    final uid = '${d['uid'] ?? ''}';
    final pseudo = '${d['pseudo'] ?? ''}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              child: Text(pseudo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text(_when(d['createdAt']),
                style: TextStyle(
                    fontSize: 11.5, color: Theme.of(context).textTheme.bodyMedium?.color)),
          ],
        ),
        subtitle: Text('${d['text'] ?? ''}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              await _Mod.deleteMessage(m.id);
            } else if (v == 'ban') {
              await _Mod.ban(context, uid, pseudo);
            } else if (v == 'reset') {
              await _Mod.resetPseudo(uid, pseudo);
              if (mounted) _Mod.snack(context, "Pseudo reset ✓");
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text("Delete message")),
            PopupMenuItem(value: 'ban', child: Text("Suspend user")),
            PopupMenuItem(value: 'reset', child: Text("Reset pseudo")),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- Help
class _HelpTab extends StatelessWidget {
  const _HelpTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _Mod.db
          .collection('help_posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.support_rounded,
            title: "No help requests yet",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            for (final p in docs)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: ('${p.data()['imageUrl'] ?? ''}').isEmpty
                      ? const Icon(Icons.chat_bubble_outline_rounded)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${p.data()['imageUrl']}',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
                          ),
                        ),
                  title: Text('${p.data()['pseudo'] ?? ''}  ·  ${_when(p.data()['createdAt'])}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(
                    '${p.data()['text'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await p.reference.delete();
                      } else if (v == 'ban') {
                        await _Mod.ban(context, '${p.data()['uid'] ?? ''}',
                            '${p.data()['pseudo'] ?? ''}');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text("Delete request")),
                      PopupMenuItem(value: 'ban', child: Text("Suspend user")),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------- Reports
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _Mod.db.collection('chat_reports').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.where((d) => d.data()['status'] == 'open').toList()
          ..sort((a, b) {
            final x = a.data()['createdAt'];
            final y = b.data()['createdAt'];
            if (x is Timestamp && y is Timestamp) return y.compareTo(x);
            return 0;
          });
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_user_rounded,
            title: "No open reports",
            message: "Reported messages appear here.",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            for (final r in docs)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${r.data()['messagePseudo'] ?? ''}  ·  ${_kindLabel('${r.data()['kind'] ?? 'chat'}')}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${r.data()['messageText'] ?? ''}'),
                      const SizedBox(height: 6),
                      Text(
                        'Reason: ${r.data()['reason'] ?? ''} · ${_when(r.data()['createdAt'])}',
                        style: TextStyle(
                            fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if ('${r.data()['kind'] ?? 'chat'}' != 'dm')
                            FilledButton.icon(
                              onPressed: () async {
                                final kind = '${r.data()['kind'] ?? 'chat'}';
                                try {
                                  if (kind == 'help') {
                                    final post = '${r.data()['postId'] ?? ''}';
                                    final reply = '${r.data()['replyId'] ?? ''}';
                                    final postRef = _Mod.db.collection('help_posts').doc(post);
                                    if (reply.isNotEmpty) {
                                      await postRef.collection('replies').doc(reply).delete();
                                    } else {
                                      await postRef.delete();
                                    }
                                  } else {
                                    await _Mod.deleteMessage('${r.data()['messageId'] ?? ''}');
                                  }
                                } catch (_) {}
                                await r.reference.update({'status': 'closed'});
                              },
                              icon: const Icon(Icons.delete_rounded, size: 18),
                              label: const Text("Delete content"),
                            ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _Mod.ban(
                                context,
                                '${r.data()['messageUid'] ?? ''}',
                                '${r.data()['messagePseudo'] ?? ''}',
                              );
                            },
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text("Suspend"),
                          ),
                          TextButton(
                            onPressed: () => r.reference.update({'status': 'closed'}),
                            child: const Text("Dismiss"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------------- Bans
class _BansTab extends StatelessWidget {
  const _BansTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _Mod.db.collection('chat_bans').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error: ${snap.error}"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.how_to_reg_rounded,
            title: "No suspended users",
          );
        }
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          children: [
            for (final b in docs)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Builder(
                  builder: (context) {
                    final d = b.data();
                    final until = d['until'];
                    final permanent = until == null;
                    final expired = until is Timestamp && !until.toDate().isAfter(DateTime.now());
                    return ListTile(
                      title: Text('${d['pseudo'] ?? b.id}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${permanent ? 'Permanent' : expired ? 'Expired' : 'Until ${_when(until)}'}'
                        '${'${d['reason'] ?? ''}'.isEmpty ? '' : ' · ${d['reason']}'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => _Mod.unban(b.id),
                        child: const Text("Lift"),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
