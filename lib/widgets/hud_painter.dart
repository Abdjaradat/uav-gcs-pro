import 'dart:math';
import 'package:flutter/material.dart';
import '../models/drone_state.dart';

class HudPainter extends CustomPainter {
  final DroneState S;

  HudPainter(this.S);

  @override
  void paint(Canvas c, Size size) {
    double w = size.width, h = size.height;
    double cx = w / 2, cy = h / 2;

    // Background
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0x99000820));

    // Pitch ladder
    double pitchDeg = S.pitch * 180 / pi;
    double rollDeg = S.roll * 180 / pi;

    c.save();
    c.translate(cx, cy);
    c.rotate(-rollDeg * pi / 180);

    double pitchScale = h / 60;
    for (int deg = -90; deg <= 90; deg += 5) {
      double y = (pitchDeg - deg) * pitchScale;
      if (y < -cy - 20 || y > cy + 20) continue;
      bool isMain = deg % 10 == 0;
      double lineW = isMain ? 60 : 30;
      Paint p = Paint()
        ..color = deg == 0 ? const Color(0xFF00D4FF) : const Color(0x8800D4FF)
        ..strokeWidth = isMain ? 1.5 : 0.8;
      c.drawLine(Offset(-lineW, y), Offset(lineW, y), p);
      if (isMain) {
        TextPainter tp = TextPainter(
          text: TextSpan(text: '${deg.abs()}°', style: const TextStyle(color: Color(0xAA00D4FF), fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(-lineW - 22, y - 6));
        tp.paint(c, Offset(lineW + 6, y - 6));
      }
    }
    c.restore();

    // Roll indicator
    c.save();
    c.translate(cx, 20);
    c.rotate(rollDeg * pi / 180);
    Paint rp = Paint()..color = const Color(0xFF00D4FF)..strokeWidth = 1.5;
    c.drawLine(const Offset(-20, 0), const Offset(-8, 0), rp);
    c.drawLine(const Offset(8, 0), const Offset(20, 0), rp);
    c.drawLine(const Offset(0, -2), const Offset(0, 10), rp);
    c.restore();

    // Center crosshair
    Paint ch = Paint()..color = const Color(0xFF00D4FF)..strokeWidth = 1;
    c.drawLine(Offset(cx - 30, cy), Offset(cx - 10, cy), ch);
    c.drawLine(Offset(cx + 10, cy), Offset(cx + 30, cy), ch);
    c.drawLine(Offset(cx, cy - 20), Offset(cx, cy - 8), ch);
    c.drawLine(Offset(cx, cy + 8), Offset(cx, cy + 20), ch);

    // Airspeed tape (left)
    double spd = S.speed;
    _drawTape(c, Offset(10, cy), 80, 100, spd, 0, 80, 'm/s');

    // Altitude tape (right)
    _drawTape(c, Offset(w - 12, cy), 80, 100, S.alt, 0, 500, 'm');

    // Mode text
    _drawText(c, w / 2, 4, S.mode, const Color(0xFF00FF88), 14);

    // Speed & Alt values
    _drawText(c, 70, h - 14, 'SPD ${spd.toStringAsFixed(1)}', const Color(0xFF00FF88), 11);
    _drawText(c, w - 70, h - 14, 'ALT ${S.alt.toStringAsFixed(1)}', const Color(0xFF00D4FF), 11);

    // HUD corner data
    _drawText(c, 4, 40, 'HDG ${S.hdgDeg.toStringAsFixed(1)}°', const Color(0xFF00D4FF), 10);
    _drawText(c, 4, 54, 'BAT ${S.bat.toStringAsFixed(0)}%', _batColor(), 10);
    _drawText(c, 4, 68, 'SIG ${S.sig.toStringAsFixed(0)}%', const Color(0xFF00FF88), 10);

    // Crosshair center dot
    c.drawCircle(Offset(cx, cy), 2, Paint()..color = const Color(0xFF00D4FF));
  }

  void _drawTape(Canvas c, Offset pos, double len, double range, double val, double min, double max, String unit) {
    Paint p = Paint()..color = const Color(0x5500D4FF)..strokeWidth = 1;
    c.drawLine(pos, Offset(pos.dx, pos.dy + len), p);
    double step = (max - min) / 10;
    for (double v = min; v <= max; v += step) {
      double y = pos.dy + ((val - v) / range) * len;
      if (y < pos.dy - 10 || y > pos.dy + len + 10) continue;
      bool main = (v % (step * 2)).abs() < 0.01;
      double x = main ? 8 : 4;
      c.drawLine(Offset(pos.dx - x, y), Offset(pos.dx, y), Paint()..color = const Color(0x6600D4FF)..strokeWidth = main ? 1 : 0.5);
    }
  }

  Color _batColor() {
    if (S.bat > 50) return const Color(0xFF00FF88);
    if (S.bat > 20) return const Color(0xFFFFAA00);
    return const Color(0xFFFF3333);
  }

  void _drawText(Canvas c, double x, double y, String t, Color color, double size) {
    TextPainter tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant HudPainter o) => true;
}
