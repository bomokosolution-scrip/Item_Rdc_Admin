import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'package:item_rdc_admin/pages/notifications_page.dart';

enum _UserFilter { all, premium, free }

class UsersInfoPage extends StatefulWidget {
  const UsersInfoPage({super.key});

  @override
  State<UsersInfoPage> createState() => _UsersInfoPageState();
}

class _UsersInfoPageState extends State<UsersInfoPage> {
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  bool isSearching = false;
  _UserFilter _filter = _UserFilter.all;

  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('users').snapshots();

  static final DateFormat _fmt = DateFormat('dd-MM-yyyy HH:mm');

  /// Sans signal depuis ce délai, l'utilisateur est considéré hors ligne
  /// (appli fermée de force, coupure réseau...). L'appli utilisateur envoie
  /// un signal toutes les 45 s.
  static const Duration _onlineTimeout = Duration(minutes: 2);

  /// Re-évalue régulièrement l'état « en ligne » même sans nouvel événement Firestore.
  Timer? _tick;
  final Map<String, MemoryImage> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    searchController.dispose();
    super.dispose();
  }

  bool isUserOnline(Map<String, dynamic> data) {
    if (data['isOnline'] != true) return false;
    final seen = data['lastSeen'];
    if (seen is! Timestamp) return false;
    return DateTime.now().difference(seen.toDate()) < _onlineTimeout;
  }

  String lastSeenText(Map<String, dynamic> data) {
    final seen = data['lastSeen'];
    if (seen is! Timestamp) return "Never";
    final d = DateTime.now().difference(seen.toDate());
    if (d.inMinutes < 1) return "just now";
    if (d.inHours < 1) return "${d.inMinutes} min ago";
    if (d.inDays < 1) return "${d.inHours} h ago";
    return _fmt.format(seen.toDate());
  }

  /// Photo : URL http(s) ou image encodée en base64 (envoyée par l'appli utilisateur).
  ImageProvider? _photoOf(String docId, String src) {
    if (src.isEmpty) return null;
    if (src.startsWith('http')) return ResizeImage(NetworkImage(src), width: 120);
    final key = '$docId:${src.length}';
    final cached = _photoCache[key];
    if (cached != null) return cached;
    try {
      final img = MemoryImage(base64Decode(src));
      _photoCache.removeWhere((k, _) => k.startsWith('$docId:'));
      _photoCache[key] = img;
      return img;
    } catch (_) {
      return null;
    }
  }

  Future<void> _editUser(String docId, Map<String, dynamic> data) async {
    final first = TextEditingController(text: (data['firstName'] ?? '').toString());
    final last = TextEditingController(text: (data['lastName'] ?? '').toString());
    final phone = TextEditingController(text: (data['phone'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit user"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: first, decoration: const InputDecoration(labelText: "First name")),
              const SizedBox(height: 10),
              TextField(controller: last, decoration: const InputDecoration(labelText: "Last name")),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Mobile"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Save")),
        ],
      ),
    );

    final f = first.text.trim(), l = last.text.trim(), p = phone.text.trim();
    if (ok != true) return;
    if (f.isEmpty || l.isEmpty) {
      if (mounted) showToast(context, "First and last name are required", error: true);
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .update({'firstName': f, 'lastName': l, 'phone': p});
      if (mounted) showToast(context, "User updated");
    } catch (e) {
      if (mounted) showToast(context, "Update failed: $e", error: true);
    }
  }

  Future<void> _deleteUser(String docId, String name) async {
    final ok = await confirmDelete(
      context,
      title: "Delete user?",
      message: "$name will be removed and signed out of the app. This cannot be undone.",
    );
    if (!ok) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      if (mounted) showToast(context, "User deleted");
    } catch (e) {
      if (mounted) showToast(context, "Delete failed: $e", error: true);
    }
  }

  /// Date ET heure (ex : 12-02-2027 23:59).
  String formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) return "N/A";
    return _fmt.format(timestamp.toDate());
  }

  bool isUserPremium(Map<String, dynamic> data) {
    final v = data['premiumExpiryTime'];
    if (v is! Timestamp) return false;
    return v.toDate().isAfter(DateTime.now());
  }

  /// Temps restant lisible : "3 d 4 h", "5 h 12 min"...
  String remaining(Map<String, dynamic> data) {
    final v = data['premiumExpiryTime'];
    if (v is! Timestamp) return "";
    final d = v.toDate().difference(DateTime.now());
    if (d.isNegative) return "Expired";
    if (d.inDays > 0) return "${d.inDays} d ${d.inHours % 24} h left";
    if (d.inHours > 0) return "${d.inHours} h ${d.inMinutes % 60} min left";
    return "${d.inMinutes} min left";
  }

  void copyUID(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    showToast(context, "UID copied");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? const Text("Users info")
            : AppBarSearchField(
                controller: searchController,
                hint: "Search by name or email...",
                onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
              ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  searchQuery = "";
                  searchController.clear();
                }
              });
            },
            icon: Icon(isSearching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Error loading users",
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!.docs;
          final premiumCount = all.where((d) => isUserPremium(d.data())).length;
          final onlineCount = all.where((d) => isUserOnline(d.data())).length;

          final docs = all.where((doc) {
            final data = doc.data();
            final first = (data['firstName'] ?? "").toString();
            final last = (data['lastName'] ?? "").toString();
            final email = (data['email'] ?? "").toString();
            final fullName = "$first $last".toLowerCase();
            final matches = fullName.contains(searchQuery) ||
                email.toLowerCase().contains(searchQuery);
            final premium = isUserPremium(data);
            final matchesFilter = _filter == _UserFilter.all ||
                (_filter == _UserFilter.premium && premium) ||
                (_filter == _UserFilter.free && !premium);
            return matches && matchesFilter;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: docs.isEmpty ? 3 : docs.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return BrandHeader(
                  icon: Icons.people_alt_rounded,
                  title: "${all.length} user(s)",
                  subtitle: "$onlineCount online · $premiumCount premium · ${all.length - premiumCount} free",
                );
              }
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final f in _UserFilter.values)
                        ChoiceChip(
                          label: Text(
                            f == _UserFilter.all
                                ? "All"
                                : f == _UserFilter.premium
                                ? "Premium"
                                : "Free",
                          ),
                          selected: _filter == f,
                          showCheckmark: false,
                          selectedColor: dark ? AppColors.brandDark : AppColors.brand,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _filter == f ? Colors.white : theme.textTheme.bodyMedium?.color,
                          ),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                );
              }
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.person_search_rounded,
                    title: "No users found",
                  ),
                );
              }
              return _buildUserCard(docs[index - 2], index - 2);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, int index) {
    final theme = Theme.of(context);
    final data = doc.data();
    final docId = doc.id;

    final first = (data['firstName'] ?? "").toString();
    final last = (data['lastName'] ?? "").toString();
    final email = (data['email'] ?? "N/A").toString();
    final phone = (data['phone'] ?? "N/A").toString();
    final profileImage = (data['profileImage'] ?? "").toString();
    final fullName = "$first $last".trim().isEmpty ? "Unnamed user" : "$first $last".trim();
    final premiumUser = isUserPremium(data);
    final online = isUserOnline(data);
    final photo = _photoOf(docId, profileImage);
    const green = Color(0xFF2E9E5B);
    const red = Color(0xFFD32F2F);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: FadeSlideIn(
        index: index,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('user_$docId'),
              tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              iconColor: AppColors.accent(context),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.accent(context).withValues(alpha: 0.14),
                    backgroundImage: photo,
                    onBackgroundImageError: photo != null ? (_, _) {} : null,
                    child: photo == null
                        ? Icon(Icons.person_outline_rounded, color: AppColors.accent(context))
                        : null,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: online ? green : red,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.listTileTheme.textColor,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InfoPill(
                      online ? "Online" : "Offline",
                      color: online ? green : red,
                    ),
                    InfoPill(
                      premiumUser ? "Premium" : "Free",
                      color: premiumUser ? const Color(0xFFB8860B) : null,
                      icon: premiumUser ? Icons.workspace_premium_rounded : null,
                    ),
                    if (premiumUser)
                      Text(
                        remaining(data),
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                      ),
                  ],
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        Icons.circle,
                        "Status",
                        online ? "Online now" : "Offline · last seen ${lastSeenText(data)}",
                      ),
                      _infoRow(Icons.mail_outline_rounded, "Email", email),
                      _infoRow(Icons.phone_outlined, "Mobile", phone),
                      _infoRow(Icons.workspace_premium_rounded, "Premium bought", formatDate(data['premiumBoughtTime'])),
                      _infoRow(Icons.event_rounded, "Premium expiry", formatDate(data['premiumExpiryTime'])),
                      _infoRow(Icons.person_add_alt_1_rounded, "Account created", formatDate(data['createdAt'])),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => showUserNotificationDialog(
                            context,
                            name: fullName,
                            token: (data['fcmToken'] ?? '').toString(),
                          ),
                          icon: const Icon(Icons.notifications_active_rounded, size: 18),
                          label: const Text("Notify"),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editUser(docId, data),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text("Edit"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _deleteUser(docId, fullName),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text("Delete"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => copyUID(docId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 16, color: AppColors.accent(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "UID $docId",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodyMedium?.color),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.listTileTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
