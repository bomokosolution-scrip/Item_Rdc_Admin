import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:item_rdc_admin/pages/main_page.dart';
import 'theme_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeManager>(
      create: (context) => ThemeManager(),
      builder: (BuildContext innerContext, Widget? child) {
        final themeManager = Provider.of<ThemeManager>(innerContext);

        return MaterialApp(
          title: 'Item RDC Admin',
          debugShowCheckedModeBanner: false,
          theme: ThemeManager.lightTheme,
          darkTheme: ThemeManager.darkTheme,
          themeMode: themeManager.themeMode,
          // Adapté à chaque téléphone : taille du texte bornée pour éviter
          // les débordements quand le texte système est très grand.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.2,
                ),
              ),
              child: child!,
            );
          },
          home: const MainPage(), // Restauration de la version Admin
        );
      },
    );
  }
}
