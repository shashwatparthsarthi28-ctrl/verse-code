import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_controller.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'services/backend.dart';
import 'services/firebase_backend.dart';
import 'services/local_backend.dart';
import 'widgets/ludo_art.dart';

Future<GameBackend> _pickBackend() async {
  // Try Firebase first. If firebase_options.dart is still the placeholder (or the
  // project is unreachable) fall back to the local simulation so the app always runs.
  try {
    final fb = FirebaseBackend();
    await fb.init();
    return fb;
  } catch (e) {
    debugPrint('Firebase unavailable, using local simulation: $e');
    final local = LocalBackend();
    await local.init();
    return local;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Gx.bgBottom,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const LudoXApp());
}

class LudoXApp extends StatefulWidget {
  const LudoXApp({super.key});

  @override
  State<LudoXApp> createState() => _LudoXAppState();
}

class _LudoXAppState extends State<LudoXApp> {
  @override
  void initState() {
    super.initState();
    app.addListener(_rebuild);
    _pickBackend().then((b) => app.bootstrap(b));
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    app.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!app.ready) {
      home = const _Splash();
    } else if (!app.signedIn) {
      home = const AuthScreen();
    } else {
      home = const Shell();
    }
    return MaterialApp(
      title: 'LUDO X',
      debugShowCheckedModeBanner: false,
      theme: Gx.theme(),
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: KeyedSubtree(key: ValueKey(home.runtimeType), child: home)),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const GxScaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: LudoLogoHero()),
          SizedBox(height: 28),
          SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Gx.goldLight, strokeWidth: 3.5)),
        ]),
      ),
    );
  }
}
