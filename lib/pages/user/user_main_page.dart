import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'home_user_page.dart';
import 'video_user_page.dart';
import 'library_user_page.dart';

class UserMainPage extends StatefulWidget {
  const UserMainPage({super.key});

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  // En situation réelle, on utilise l'UID de l'utilisateur connecté
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // Note: Pour vos tests sans système de login complet,
  // vous pouvez remplacer par un UID existant dans votre base 'users'
  final String testUid = "VOTRE_UID_TEST";

  static final DateFormat _expiryFormat = DateFormat("dd/MM/yyyy 'à' HH:mm");

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final currentThemeMode = themeManager.themeMode;
    final Color primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid ?? testUid)
          .snapshots(),
      builder: (context, snapshot) {
        bool isPremium = false;
        String statusText = "Compte Standard";
        String? statusDetail;
        Color statusColor = Colors.grey;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final Timestamp? expiry = data['premiumExpiryTime'];

          if (expiry != null) {
            final expiryDate = expiry.toDate();
            isPremium = expiryDate.isAfter(DateTime.now());
            if (isPremium) {
              statusText = "Membre Premium";
              statusDetail = "Valable jusqu'au ${_expiryFormat.format(expiryDate)}";
              statusColor = Colors.amber;
            } else {
              statusText = "Abonnement Expiré";
              statusDetail = "Expiré le ${_expiryFormat.format(expiryDate)}";
              statusColor = Colors.redAccent;
            }
          }
        }

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Item RDC - Espace Étudiant"),
            actions: [
              IconButton(
                icon: Icon(
                  currentThemeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () =>
                    themeManager.toggleTheme(currentThemeMode != ThemeMode.dark),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              children: [
                BrandHeader(
                  icon: isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.school_rounded,
                  title: "Bienvenue",
                  subtitle: isPremium
                      ? "Tous vos contenus sont débloqués"
                      : "Accédez aux contenus généraux",
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      // Badge de statut Premium
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPremium ? Icons.verified : Icons.info_outline,
                              color: statusColor,
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (statusDetail != null)
                                    Text(
                                      statusDetail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildUserCard(
                        "Bibliothèque",
                        "Consultez les documents par université",
                        Icons.menu_book,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LibraryUserPage(),
                          ),
                        ),
                        primaryColor,
                      ),
                      const SizedBox(height: 14),
                      _buildUserCard(
                        "Cours & PDF",
                        isPremium
                            ? "Accès illimité aux contenus"
                            : "Contenu général uniquement",
                        Icons.folder_shared,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeUserPage(isPremium: isPremium),
                          ),
                        ),
                        primaryColor,
                      ),
                      const SizedBox(height: 14),
                      _buildUserCard(
                        "Vidéos",
                        "Leçons et tutoriels",
                        Icons.play_circle_fill,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoUserPage(isPremium: isPremium),
                          ),
                        ),
                        primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Color primaryColor,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              IconBadge(icon: icon, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
