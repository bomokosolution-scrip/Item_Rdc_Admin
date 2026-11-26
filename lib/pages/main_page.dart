import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_arc_text/flutter_arc_text.dart';
import 'package:intl/intl.dart';
import 'package:item_rdc_admin/pages/users_info_page.dart';
import 'package:item_rdc_admin/widgets/app_ui.dart';
import 'home_page.dart';
import 'video_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:item_rdc_admin/theme_manager.dart';
import 'library_admin_page.dart';
import 'notifications_page.dart';
import 'publications_admin_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final uidController = TextEditingController();

  /// Date ET heure d'expiration du Premium (choisies via les sélecteurs).
  DateTime? _expiry;

  bool isPremium = false;
  bool _saving = false;

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fullFormat = DateFormat("dd/MM/yyyy 'at' HH:mm");

  @override
  void dispose() {
    uidController.dispose();
    super.dispose();
  }

  Future<void> updateUserPremium({
    required String uid,
    required DateTime premiumExpiryTime,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    await usersRef.doc(uid).update({
      'premiumBoughtTime': FieldValue.serverTimestamp(),
      'premiumExpiryTime': premiumExpiryTime,
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------ Date / heure

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _expiry ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 20, 12, 31),
      helpText: "Expiry date",
    );
    if (picked == null) return;

    setState(() {
      // Si aucune heure n'a encore été choisie : fin de journée par défaut.
      final hour = _expiry?.hour ?? 23;
      final minute = _expiry?.minute ?? 59;
      _expiry = DateTime(picked.year, picked.month, picked.day, hour, minute);
    });
  }

  Future<void> _pickTime() async {
    final base = _expiry ?? DateTime.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: "Expiry time",
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      _expiry = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  /// Raccourcis "essai" : l'expiration est calculée à partir de maintenant.
  void _applyQuick(DateTime Function(DateTime now) build) {
    setState(() => _expiry = build(DateTime.now()));
  }

  Future<void> _submit() async {
    final uid = uidController.text.trim();
    final expiry = _expiry;

    if (uid.isEmpty || expiry == null) {
      _snack("Please enter the UID and choose the expiry date and time");
      return;
    }

    setState(() => _saving = true);
    try {
      await updateUserPremium(uid: uid, premiumExpiryTime: expiry);
      _snack("Premium updated until ${_fullFormat.format(expiry)}");
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final currentThemeMode = themeManager.themeMode;

    IconData themeIcon;
    VoidCallback onThemeToggle;

    if (currentThemeMode == ThemeMode.dark) {
      themeIcon = Icons.light_mode_outlined;
      onThemeToggle = () => themeManager.toggleTheme(false);
    } else {
      themeIcon = Icons.dark_mode_outlined;
      onThemeToggle = () => themeManager.toggleTheme(true);
    }

    final Color primaryColor = Theme.of(context).primaryColor;
    final Color scaffoldBackgroundColor = Theme.of(
      context,
    ).scaffoldBackgroundColor;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color appBarForegroundColor =
        Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Item RDC Admin Panel"),
        actions: [
          IconButton(
            icon: Icon(themeIcon, color: appBarForegroundColor),
            onPressed: onThemeToggle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUpperPanel(
              primaryColor,
              scaffoldBackgroundColor,
              surfaceColor,
              appBarForegroundColor,
            ),
            const SizedBox(height: 24),
            _buildControls(
              primaryColor,
              scaffoldBackgroundColor,
              surfaceColor,
              appBarForegroundColor,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUpperPanel(
    Color primaryColor,
    Color scaffoldBackgroundColor,
    Color surfaceColor,
    Color appBarForegroundColor,
  ) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final expiry = _expiry;
    final isPast = expiry != null && expiry.isBefore(DateTime.now());

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(icon: Icons.workspace_premium_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Premium access",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            "Set the exact expiry date and time",
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
                const SizedBox(height: 20),
                _buildTextField(
                  "UID",
                  uidController,
                  primaryColor,
                  surfaceColor,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _pickerTile(
                        icon: Icons.calendar_month_rounded,
                        label: "Date",
                        value: expiry == null
                            ? "Choose"
                            : _dateFormat.format(expiry),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerTile(
                        icon: Icons.schedule_rounded,
                        label: "Time",
                        value: expiry == null
                            ? "Choose"
                            : _timeFormat.format(expiry),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "QUICK TRIAL",
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
                  runSpacing: 4,
                  children: [
                    _quickChip("+1 hour", (n) => n.add(const Duration(hours: 1))),
                    _quickChip("+24 hours", (n) => n.add(const Duration(hours: 24))),
                    _quickChip("+7 days", (n) => n.add(const Duration(days: 7))),
                    _quickChip(
                      "+1 month",
                      (n) => DateTime(n.year, n.month + 1, n.day, n.hour, n.minute),
                    ),
                    _quickChip(
                      "+1 year",
                      (n) => DateTime(n.year + 1, n.month, n.day, n.hour, n.minute),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: expiry == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : Container(
                          key: ValueKey(expiry),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: (isPast ? theme.colorScheme.error : accent)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPast
                                    ? Icons.warning_amber_rounded
                                    : Icons.event_available_rounded,
                                size: 18,
                                color: isPast ? theme.colorScheme.error : accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isPast
                                      ? "Date already passed: Premium will be disabled (${_fullFormat.format(expiry)})"
                                      : "Premium until ${_fullFormat.format(expiry)}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isPast
                                        ? theme.colorScheme.error
                                        : accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            left: 43,
            bottom: 70,
            child: GestureDetector(
              onTap: _saving ? null : _submit,
              child: SizedBox(
                width: 50,
                height: 50,
                child: ArcText(
                  radius: 40,
                  text: "Make some good day for him/her with only one click",
                  textStyle: TextStyle(
                    color: primaryColor.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                  startAngle: math.pi * 0.0,
                  direction: Direction.clockwise,
                  placement: Placement.outside,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 78,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(_saving ? "Saving..." : "Activate"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    return Material(
      color: theme.inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, DateTime Function(DateTime now) build) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.accent(context),
      ),
      backgroundColor: AppColors.accent(context).withValues(alpha: 0.10),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _applyQuick(build),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color primaryColor,
    Color surfaceColor,
  ) {
    // Boutons Coller et Effacer inclus (AppField).
    return AppField(
      controller: controller,
      label: label,
      icon: Icons.badge_outlined,
    );
  }

  Widget _buildControls(
    Color primaryColor,
    Color scaffoldBackgroundColor,
    Color surfaceColor,
    Color appBarForegroundColor,
  ) {
    final theme = Theme.of(context);

    final style = ToggleSwitchStyle(
      backgroundColor: surfaceColor,
      indicatorColor: primaryColor,
      borderRadius: 12,
      activeTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      inactiveTextStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color ?? Colors.black54,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CONTENT SPACE",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Applies to Home and Video",
            style: TextStyle(
              fontSize: 12.5,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 10),
          ToggleSwitch(
            labels: const ["General", "Premium"],
            style: style,
            height: 46,
            initialIndex: isPremium ? 1 : 0,
            onChanged: (i) {
              setState(() => isPremium = i == 1);
            },
          ),
          const SizedBox(height: 22),
          _navButton(
            "Home",
            "PDF folders and documents",
            Icons.folder_copy_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HomePage(isPremium: isPremium),
                ),
              );
            },
            primaryColor,
          ),
          const SizedBox(height: 12),
          _navButton(
            "Video",
            "Video folders and lessons",
            Icons.play_circle_fill_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPage(isPremium: isPremium),
                ),
              );
            },
            primaryColor,
          ),
          const SizedBox(height: 12),
          _navButton(
            "User info",
            "Accounts and Premium status",
            Icons.people_alt_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => UsersInfoPage(),
                ),
              );
            },
            primaryColor,
          ),
          const SizedBox(height: 12),
          _navButton(
            "Library",
            "University documents",
            Icons.menu_book_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => LibraryAdminPage(),
                ),
              );
            },
            primaryColor,
          ),
          const SizedBox(height: 12),
          _navButton(
            "Publications",
            "Review works submitted by users",
            Icons.fact_check_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const PublicationsAdminPage(),
                ),
              );
            },
            primaryColor,
          ),
          const SizedBox(height: 12),
          _navButton(
            "Notifications",
            "Send push messages to users",
            Icons.notifications_active_rounded,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const NotificationsPage(),
                ),
              );
            },
            primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _navButton(
    String text,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              IconBadge(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleSwitchStyle {
  final Color backgroundColor;
  final Color indicatorColor;
  final Color borderColor;
  final TextStyle activeTextStyle;
  final TextStyle inactiveTextStyle;
  final double borderRadius;
  final Duration duration;

  const ToggleSwitchStyle({
    this.backgroundColor = Colors.white,
    this.indicatorColor = Colors.green,
    this.borderColor = Colors.transparent,
    this.borderRadius = 30,
    this.duration = const Duration(milliseconds: 300),
    this.activeTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    this.inactiveTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  });
}

class ToggleSwitch extends StatefulWidget {
  final List<String> labels;
  final ValueChanged<int>? onChanged;
  final ToggleSwitchStyle style;
  final double height;
  final int initialIndex;

  const ToggleSwitch({
    super.key,
    required this.labels,
    this.onChanged,
    this.style = const ToggleSwitchStyle(),
    this.height = 50,
    this.initialIndex = 0,
  });

  @override
  State<ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<ToggleSwitch> {
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(style.borderRadius),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: index == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: style.duration,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: style.indicatorColor,
                  borderRadius: BorderRadius.circular(style.borderRadius),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(2, (i) {
              final active = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => index = i);
                    widget.onChanged?.call(i);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: style.duration,
                      style: active
                          ? style.activeTextStyle
                          : style.inactiveTextStyle,
                      child: Text(widget.labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
