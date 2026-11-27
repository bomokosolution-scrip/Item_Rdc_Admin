import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc_admin/pages/main_page.dart';
import 'package:item_rdc_admin/theme_manager.dart';

/// Porte d'entrée de l'application admin : connexion obligatoire, puis
/// vérification que le compte figure dans la collection `admins`.
class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const AdminLoginPage();
        return _AdminCheck(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _AdminCheck extends StatefulWidget {
  final User user;
  const _AdminCheck({super.key, required this.user});

  @override
  State<_AdminCheck> createState() => _AdminCheckState();
}

class _AdminCheckState extends State<_AdminCheck> {
  late Future<bool> _future = _isAdmin();

  Future<bool> _isAdmin() async {
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(widget.user.uid)
        .get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _Notice(
            icon: Icons.wifi_off_rounded,
            title: "Vérification impossible",
            message: "Contrôlez votre connexion puis réessayez.",
            primaryLabel: "Réessayer",
            onPrimary: () => setState(() => _future = _isAdmin()),
          );
        }
        if (snap.data != true) {
          return _Notice(
            icon: Icons.gpp_bad_rounded,
            title: "Accès refusé",
            message:
                "Ce compte n'est pas administrateur.\nUID : ${widget.user.uid}",
            primaryLabel: "Se déconnecter",
            onPrimary: () => FirebaseAuth.instance.signOut(),
          );
        }
        return const MainPage();
      },
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 60, color: AppColors.accent(context)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SelectableText(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connexion de l'administrateur (e-mail + mot de passe Firebase).
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'user-disabled':
        return "Ce compte est désactivé.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "E-mail ou mot de passe incorrect.";
      case 'too-many-requests':
        return "Trop de tentatives. Réessayez plus tard.";
      case 'network-request-failed':
        return "Pas de connexion internet.";
      default:
        return "Connexion impossible (${e.code}).";
    }
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = "Saisissez l'e-mail et le mot de passe.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } catch (e) {
      if (mounted) setState(() => _error = "Erreur : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 64, color: accent),
                  const SizedBox(height: 12),
                  const Text(
                    "Item RDC Admin",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Connexion administrateur",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: "E-mail",
                      prefixIcon: const Icon(Icons.email_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text("Se connecter", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
