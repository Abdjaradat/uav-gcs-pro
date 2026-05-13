import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/licensing_service.dart';
import 'services/cloud_service.dart';
import 'services/connectivity_service.dart';
import 'screens/marketing_screen.dart';
import 'screens/simulator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final lic = LicensingService();
  await lic.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: lic),
        Provider(create: (_) => CloudService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
      child: const UavGcsApp(),
    ),
  );
}

class UavGcsApp extends StatelessWidget {
  const UavGcsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UAV GCS PRO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4ECDC4),
          secondary: Color(0xFF00D4FF),
        ),
      ),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  bool _showSim = false;

  @override
  Widget build(BuildContext context) {
    return _showSim
        ? SimulatorScreen(lic: context.read<LicensingService>())
        : MarketingScreen(onEnterSim: () => setState(() => _showSim = true));
  }
}
