import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/licensing_service.dart';

class MarketingScreen extends StatefulWidget {
  final VoidCallback onEnterSim;
  const MarketingScreen({super.key, required this.onEnterSim});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  final _keyCtrl = TextEditingController();
  String _msg = '';

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lic = context.watch<LicensingService>();
    return Scaffold(
      backgroundColor: const Color(0xFF060C14),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 60),
          // Hero
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(children: [
              const Text('UAV GCS PRO', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                  color: Color(0xFF4ECDC4))),
              const SizedBox(height: 12),
              const Text('Professional Ground Control Station', style: TextStyle(fontSize: 16, color: Color(0xFF8892B0))),
              const SizedBox(height: 8),
              Text(lic.isPro ? 'PRO ACTIVE' : lic.isSub ? 'SUBSCRIPTION ACTIVE' : 'DEMO MODE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                      color: lic.isPro || lic.isSub ? const Color(0xFF00FF88) : const Color(0xFFFFAA00))),
              const SizedBox(height: 30),
              _buildButton('ENTER SIMULATOR', () => widget.onEnterSim(), const Color(0xFF4ECDC4)),
            ]),
          ),
          // Features
          _section('Features', [
            '3 flight modes: MANUAL, STABILIZE, ALT HOLD',
            'Auto Waypoint navigation (PRO/SUB)',
            '5 mission types: Orbit, Figure-8, Spiral, Grid',
            'RTL (Return to Launch) with home point',
            'Real-time HUD with pitch ladder',
            'Camera simulation (Day/Thermal/NVG)',
          ]),
          // Activate
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x264ECDC4)),
            ),
            child: Column(children: [
              const Text('Activate License', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: Color(0xFF4ECDC4))),
              const SizedBox(height: 16),
              TextField(
                controller: _keyCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Enter license key',
                  hintStyle: const TextStyle(color: Color(0xFF5A8A9E)),
                  filled: true, fillColor: const Color(0xFF08111E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (_) => _activate(),
              ),
              const SizedBox(height: 12),
              if (_msg.isNotEmpty) Text(_msg, style: TextStyle(
                  color: _msg.contains('✓') ? const Color(0xFF00FF88) : const Color(0xFFFF3333),
                  fontSize: 13)),
              const SizedBox(height: 12),
              _buildButton('ACTIVATE', () => _activate(), const Color(0xFF4ECDC4)),
              const SizedBox(height: 8),
              const Text('PRO: UAV-PRO-TEST123456', style: TextStyle(fontSize: 11, color: Color(0xFF5A8A9E))),
              const Text('SUB: UAV-SUB-TEST123456789', style: TextStyle(fontSize: 11, color: Color(0xFF5A8A9E))),
            ]),
          ),
          // Tiers
          _section('Tiers', [
            'DEMO: Basic flight, 5 waypoints, 30 m/s max',
            'PRO: All features, unlimited waypoints',
            'SUB: All PRO features + priority support',
          ]),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  void _activate() {
    final lic = context.read<LicensingService>();
    if (lic.activate(_keyCtrl.text.trim())) {
      setState(() => _msg = '✓ License activated');
    } else {
      setState(() => _msg = '✗ Invalid key');
    }
  }

  Widget _buildButton(String text, VoidCallback onTap, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF0A0A1A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x264ECDC4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4ECDC4))),
        const SizedBox(height: 12),
        ...items.map((s) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.check, color: Color(0xFF4ECDC4), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(s, style: const TextStyle(color: Color(0xFF8892B0), fontSize: 13))),
            ]))),
      ]),
    );
  }
}
