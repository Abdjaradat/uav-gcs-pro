import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/licensing_service.dart';
import 'screens/marketing_screen.dart';
import 'screens/simulator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final lic = LicensingService();
  await lic.init();

  runApp(
    ChangeNotifierProvider.value(value: lic, child: const UavGcsApp()),
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
