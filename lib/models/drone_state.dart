import 'dart:math';

class DroneState {
  double x, y, alt;
  double vx, vy, vz;
  double hdg, pitch, roll;
  double thr, tAlt, tHdg;
  double bat, sig;
  double wSpd, wDir, temp;
  double gF, rpm;
  bool armed, wpNav, goToMode, inNFZ;
  int wpI;
  double fT;
  double goToX, goToY, goToAlt;
  String mode;
  double hX, hY;
  double takeoffX, takeoffY;
  double spd;

  DroneState()
      : x = 0, y = 0, alt = 0, vx = 0, vy = 0, vz = 0,
        hdg = 0, pitch = 0, roll = 0, thr = 0, tAlt = 50, tHdg = 0,
        bat = 100, sig = 95, wSpd = 3.2, wDir = 2.36, temp = 22,
        gF = 1, rpm = 0, armed = false, wpNav = false, goToMode = false,
        inNFZ = false, wpI = 0, fT = 0, goToX = 0, goToY = 0, goToAlt = 50,
        mode = 'MANUAL', hX = 0, hY = 0, takeoffX = 0, takeoffY = 0, spd = 0;

  double get speed => sqrt(vx * vx + vy * vy);
  double get hdgDeg => ((hdg * 180 / pi) % 360 + 360) % 360;
}
