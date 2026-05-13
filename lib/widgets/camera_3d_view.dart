import 'dart:math';
import 'package:flutter/material.dart';
import '../models/drone_state.dart';

class Camera3DView extends StatelessWidget {
  final DroneState state;
  final double viewDistance;

  const Camera3DView({super.key, required this.state, this.viewDistance = 200.0});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF1A2450),
              const Color(0xFF2D3A6A),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _Camera3DPainter(state: state, viewDistance: viewDistance),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Camera3DPainter extends CustomPainter {
  final DroneState state;
  final double viewDistance;

  _Camera3DPainter({required this.state, required this.viewDistance});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.shortestSide / 8;

    canvas.save();
    // Camera follows drone from behind (based on heading)
    final camAngle = (state.hdg + 180) * pi / 180;
    final camPitch = -20 * pi / 180; // looking down from behind
    final camDist = viewDistance / 20;
    final camX = cx + cos(camAngle) * camDist;
    final camY = cy + sin(camAngle) * camDist;

    // === Sky gradient ===
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFF05081A), const Color(0xFF162050)],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGradient.createShader(skyRect));

    // === Ground grid ===
    final gridPaint = Paint()
      ..color = const Color(0xFF4ECDC4).withOpacity(0.15)
      ..strokeWidth = 0.5;
    final gridSize = 20;
    for (int i = -gridSize; i <= gridSize; i++) {
      final x1 = _projectX(cx, cy, scale, camAngle, camPitch, i.toDouble(), -gridSize.toDouble(), 0);
      final y1 = _projectY(cx, cy, scale, camAngle, camPitch, i.toDouble(), -gridSize.toDouble(), 0);
      final x2 = _projectX(cx, cy, scale, camAngle, camPitch, i.toDouble(), gridSize.toDouble(), 0);
      final y2 = _projectY(cx, cy, scale, camAngle, camPitch, i.toDouble(), gridSize.toDouble(), 0);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), gridPaint);
      final x3 = _projectX(cx, cy, scale, camAngle, camPitch, -gridSize.toDouble(), i.toDouble(), 0);
      final y3 = _projectY(cx, cy, scale, camAngle, camPitch, -gridSize.toDouble(), i.toDouble(), 0);
      final x4 = _projectX(cx, cy, scale, camAngle, camPitch, gridSize.toDouble(), i.toDouble(), 0);
      final y4 = _projectY(cx, cy, scale, camAngle, camPitch, gridSize.toDouble(), i.toDouble(), 0);
      canvas.drawLine(Offset(x3, y3), Offset(x4, y4), gridPaint);
    }

    // === Drone 3D model ===
    canvas.save();
    canvas.translate(
      _projectX(cx, cy, scale, camAngle, camPitch, 0, 0, state.alt * 0.05),
      _projectY(cx, cy, scale, camAngle, camPitch, 0, 0, state.alt * 0.05),
    );

    final rollRad = state.roll * pi / 180;
    final pitchRad = state.pitch * pi / 180;
    final hdgRad = state.hdg * pi / 180;

    // Drone body (cross shape)
    final bodyPaint = Paint()..color = const Color(0xFF4ECDC4);
    final bodyPaintDark = Paint()..color = const Color(0xFF2A9D8F);
    final bodyPaintRed = Paint()..color = const Color(0xFFE63946);
    final bodyPaintGreen = Paint()..color = const Color(0xFF2ECC40);

    final bodySize = 20.0;
    final armLen = 20.0;

    // Apply attitude transform
    canvas.rotate(rollRad);

    // Arms (X pattern)
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 + pi / 4 + hdgRad;
      final ex = cos(angle) * armLen;
      final ey = sin(angle) * armLen;
      canvas.drawLine(Offset(0, 0), Offset(ex, ey), Paint()
        ..color = const Color(0xFF7FDBFF).withOpacity(0.6)
        ..strokeWidth = 2);
      // Motor indicators
      canvas.drawCircle(Offset(ex, ey), 3, i < 2 ? bodyPaintGreen : bodyPaintRed);
    }

    // Center body
    canvas.drawCircle(Offset(0, 0), 6, bodyPaint);
    canvas.drawCircle(Offset(0, 0), 4, Paint()..color = const Color(0xFF00D4FF));

    // Nose indicator
    final noseAngle = hdgRad;
    canvas.drawLine(
      Offset(0, 0),
      Offset(cos(noseAngle) * 12, sin(noseAngle) * 12),
      Paint()..color = Colors.white..strokeWidth = 2,
    );

    canvas.restore();

    // === Altitude line ===
    if (state.alt > 0) {
      final altLinePaint = Paint()
        ..color = const Color(0xFF4ECDC4).withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final groundX = _projectX(cx, cy, scale, camAngle, camPitch, 0, 0, 0);
      final groundY = _projectY(cx, cy, scale, camAngle, camPitch, 0, 0, 0);
      final droneX = _projectX(cx, cy, scale, camAngle, camPitch, 0, 0, state.alt * 0.05);
      final droneY = _projectY(cx, cy, scale, camAngle, camPitch, 0, 0, state.alt * 0.05);
      canvas.drawLine(Offset(groundX, groundY), Offset(droneX, droneY), altLinePaint);
    }

    // === HUD overlays ===
    final textStyle = TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace');
    _drawText(canvas, 'ALT: ${state.alt.toStringAsFixed(1)}m', 8, size.height - 28, textStyle);
    _drawText(canvas, 'HDG: ${state.hdg.toStringAsFixed(1)}°', 8, size.height - 14, textStyle);
    _drawText(canvas, 'SPD: ${state.spd.toStringAsFixed(1)}m/s', 8, size.height - 42, textStyle);

    // Mode label
    _drawText(canvas, state.mode, size.width / 2 - 20, 8, TextStyle(
      color: const Color(0xFF4ECDC4), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace',
    ));

    canvas.restore();
  }

  double _projectX(double cx, double cy, double scale, double camAngle, double camPitch, double x, double y, double z) {
    final cosA = cos(camAngle), sinA = sin(camAngle);
    final cosP = cos(camPitch), sinP = sin(camPitch);
    // Rotate by camera angle
    final rx = x * cosA - y * sinA;
    final ry = x * sinA + y * cosA;
    final rz = z;
    // Simple perspective
    final perspective = 500.0 / (500.0 + ry + 100);
    return cx + rx * scale * perspective;
  }

  double _projectY(double cx, double cy, double scale, double camAngle, double camPitch, double x, double y, double z) {
    final cosA = cos(camAngle), sinA = sin(camAngle);
    final cosP = cos(camPitch), sinP = sin(camPitch);
    final rx = x * cosA - y * sinA;
    final ry = x * sinA + y * cosA;
    final rz = z * 0.5;
    final perspective = 500.0 / (500.0 + ry + 100);
    return cy - ry * 0.5 * scale * perspective + rz * scale * perspective;
  }

  void _drawText(Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_Camera3DPainter old) => old.state != state;
}
