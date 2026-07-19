import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/prompt_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/conversation_library_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/pack_screen.dart';
import 'services/pack_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Window.initialize();
  await PromptService.instance.load('zh');
  await PackService.instance.scan();
  await Window.setEffect(
    effect: WindowEffect.acrylic,
    color: const Color(0xEE020008),
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AromaticApp());
}

class AromaticApp extends StatefulWidget {
  const AromaticApp({super.key});

  static void toggleTheme(BuildContext context) {
    final state = context.findAncestorStateOfType<_AromaticAppState>();
    state?.toggleTheme();
  }

  static void toggleAcrylic(BuildContext context) {
    final state = context.findAncestorStateOfType<_AromaticAppState>();
    state?.toggleAcrylic();
  }

  @override
  State<AromaticApp> createState() => _AromaticAppState();
}

class _AromaticAppState extends State<AromaticApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useAcrylic = true;
  String _locale = 'zh';

  bool get useAcrylic => _useAcrylic;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    _updateAcrylic();
  }

  void toggleAcrylic() {
    setState(() => _useAcrylic = !_useAcrylic);
    _updateAcrylic();
  }

  void setLocale(String newLocale) async {
    await PromptService.instance.reload(newLocale);
    setState(() => _locale = newLocale);
  }

  void _updateAcrylic() async {
    final isDark = _themeMode == ThemeMode.dark;
    if (_useAcrylic) {
      await Window.setEffect(
        effect: WindowEffect.acrylic,
        color: isDark ? const Color(0xEE020008) : const Color(0xDDB8A8D8),
      );
    } else {
      await Window.setEffect(
        effect: WindowEffect.disabled,
        color: isDark ? const Color(0xEE10081C) : const Color(0xEEF8F4FE),
      );
    }
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Aromatic",
      debugShowCheckedModeBanner: false,
      theme: AromaticTheme.lightTheme,
      darkTheme: AromaticTheme.darkTheme,
      themeMode: _themeMode,
      locale: Locale(_locale),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      initialRoute: "/",
      routes: {
        "/": (_) => HomeScreen(onToggleTheme: toggleTheme),
        "/settings": (_) => SettingsScreen(
          onToggleTheme: toggleTheme,
          useAcrylic: _useAcrylic,
          onToggleAcrylic: toggleAcrylic,
          currentLocale: _locale,
          onLocaleChanged: setLocale,
        ),
        "/conversations": (_) => const ConversationLibraryScreen(),
        "/terminal": (_) => const TerminalScreen(),
        "/packs": (_) => const PackScreen(),
      },
    );
  }
}
