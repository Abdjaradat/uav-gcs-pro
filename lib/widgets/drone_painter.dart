import 'dart:math';
import 'package:flutter/material.dart';

class DroneMarkerPainter extends CustomPainter {
  final bool armed;
  final double heading;
  final double size;

  DroneMarkerPainter({this.armed = false, this.heading = 0, this.size = 24});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = min(size.width, size.height) / 2 - 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(heading * pi / 180);

    // Drop shadow
    final shadow = Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(1, 1), s * 0.65, shadow);

    // Glow effect when armed
    if (armed) {
      final glow = Paint()
        ..color = const Color(0x30FF2255)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(0, 0), s * 1.1, glow);
    }

    // Main body - hexagon shape
    final bodyPaint = Paint()
      ..color = armed ? const Color(0xFFE63946) : const Color(0xFF5A8A9E)
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = armed ? const Color(0xFFFF2255) : const Color(0xFF7F8C9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 2;
      final px = cos(angle) * s * 0.5;
      final py = sin(angle) * s * 0.5;
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, bodyStroke);

    // Arms (4 arms in X pattern)
    final armPaint = Paint()
      ..color = armed ? const Color(0xFFE63946) : const Color(0xFF5A8A9E)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 + pi / 4;
      final ex = cos(angle) * s * 0.8;
      final ey = sin(angle) * s * 0.8;
      canvas.drawLine(Offset(0, 0), Offset(ex, ey), armPaint);
      // Motor
      final motorColor = i < 2 ? const Color(0xFF2ECC40) : const Color(0xFFFF4136);
      canvas.drawCircle(Offset(ex, ey), s * 0.15, Paint()..color = motorColor);
      // Propeller arc
      final propPaint = Paint()
        ..color = motorColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawCircle(Offset(ex, ey), s * 0.3, propPaint);
    }

    // Center dot
    canvas.drawCircle(Offset(0, 0), s * 0.12, Paint()..color = armed ? Colors.white : const Color(0xFFCCCCCC));

    // Nose direction triangle
    final nosePaint = Paint()
      ..color = armed ? const Color(0xFFFF2255) : const Color(0xFFCCCCCC);
    final nosePath = Path()
      ..moveTo(0, -s * 0.85)
      ..lineTo(-s * 0.15, -s * 0.4)
      ..lineTo(s * 0.15, -s * 0.4)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(DroneMarkerPainter old) =>
      old.armed != armed || old.heading != heading;
}

class HomeMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = min(size.width, size.height) / 2 - 2;

    // House shape
    final housePaint = Paint()..color = const Color(0xFFFFAA00);
    final strokePaint = Paint()
      ..color = const Color(0xFFFF8800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Roof (triangle)
    final roofPath = Path()
      ..moveTo(cx, cy - s * 0.8)
      ..lineTo(cx - s * 0.7, cy - s * 0.1)
      ..lineTo(cx + s * 0.7, cy - s * 0.1)
      ..close();
    canvas.drawPath(roofPath, housePaint);
    canvas.drawPath(roofPath, strokePaint);

    // Walls (square)
    final wallPath = Path()
      ..addRect(Rect.fromLTWH(cx - s * 0.55, cy - s * 0.1, s * 1.1, s * 0.7));
    canvas.drawPath(wallPath, housePaint);
    canvas.drawPath(wallPath, strokePaint);

    // Door
    final doorPaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + s * 0.25), width: s * 0.25, height: s * 0.35), doorPaint);

    // "H" label
    final tp = TextPainter(
      text: TextSpan(text: 'H', style: TextStyle(color: Colors.white, fontSize: s * 0.45, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - s * 0.35));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaypointMarkerPainter extends CustomPainter {
  final int number;
  final bool reached;

  WaypointMarkerPainter({this.number = 0, this.reached = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = min(size.width, size.height) / 2 - 2;
    final color = reached ? const Color(0xFF00FF88) : const Color(0xFF00D4FF);

    // Outer ring
    final ringPaint = Paint()
      ..color = color.withOpacity(reached ? 0.3 : 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), s * 0.85, ringPaint);

    // Inner circle
    final innerPaint = Paint()
      ..color = color.withOpacity(reached ? 0.6 : 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), s * 0.6, innerPaint);

    // Border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), s * 0.6, borderPaint);

    // Number
    final tp = TextPainter(
      text: TextSpan(text: '$number', style: TextStyle(color: color, fontSize: s * 0.7, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(WaypointMarkerPainter old) =>
      old.number != number || old.reached != reached;
}

class TargetArrowPainter extends CustomPainter {
  final int wpNumber;

  TargetArrowPainter({this.wpNumber = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final s = min(size.width, size.height) / 2 - 2;

    // Arrow pointing right
    final arrowPaint = Paint()
      ..color = const Color(0xFFFFAA00)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx - s * 0.3, cy - s * 0.4)
      ..lineTo(cx + s * 0.5, cy)
      ..lineTo(cx - s * 0.3, cy + s * 0.4)
      ..close();
    canvas.drawPath(path, arrowPaint);

    final stroke = Paint()
      ..color = const Color(0xFFFF8800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, stroke);

    final tp = TextPainter(
      text: TextSpan(text: 'WP$wpNumber', style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - s * 0.65));
  }

  @override
  bool shouldRepaint(TargetArrowPainter old) => old.wpNumber != wpNumber;
}
