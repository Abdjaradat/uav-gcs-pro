import 'dart:math';
import '../models/drone_state.dart';
import '../models/waypoint.dart';

class PIDCtrl {
  double kp, ki, kd, i = 0, p = 0, o = 0;
  PIDCtrl(this.kp, this.ki, this.kd);

  double update(double sp, double mv, double dt) {
    if (dt <= 0) return o;
    double e = sp - mv;
    i = max(-80, min(80, i + e * dt));
    double d = (e - p) / dt;
    p = e;
    o = kp * e + ki * i + kd * d;
    return o;
  }
  void reset() { i = 0; p = 0; o = 0; }
}

double normalizeAngle(double a) {
  while (a > pi) a -= 2 * pi;
  while (a < -pi) a += 2 * pi;
  return a;
}

double angleDiff(double t, double c) {
  double d = t - c;
  while (d > pi) d -= 2 * pi;
  while (d < -pi) d += 2 * pi;
  return d;
}

class SimulatorEngine {
  DroneState S = DroneState();
  List<Waypoint> wps = [];
  bool autoTakeoff = false;
  double takeoffTarget = 0;
  String takeoffMode = 'LOITER';
  double simTime = 14 * 3600;
  double pSpd = 30, pAlt = 50;

  final PIDCtrl aPid = PIDCtrl(2.5, 0.4, 1.2);
  final PIDCtrl hPid = PIDCtrl(4, 0.15, 1.0);

  final List<Map<String, double>> trail = [];
  double mType = 0;
  double mStart = 0, mCX = 0, mCY = 0;
  double fTX = 0, fTY = 0, fTDir = 0;

  void update(double dt) {
    if (dt <= 0 || dt > 0.1) return;
    if (!S.armed) {
      S.vx *= 0.9; S.vy *= 0.9; S.vz = 0; S.thr = 0; S.rpm = 0;
      return;
    }
    S.fT += dt;
    simTime += dt * 60;
    S.temp = 22 + S.thr * 0.15 + sin(S.fT * 0.1) * 2;
    S.wSpd = max(0, min(20, S.wSpd + (Random().nextDouble() - 0.5) * 0.15));
    S.wDir += (Random().nextDouble() - 0.5) * 0.03;
    S.gF = 1 + sqrt(S.vx * S.vx + S.vy * S.vy) / 9.81 * 0.1 + S.vz.abs() * 0.02;

    // GoTo
    if (S.goToMode && S.armed && !S.wpNav) {
      double dx = S.goToX - S.x, dy = S.goToY - S.y, d = sqrt(dx * dx + dy * dy);
      if (d < 8) {
        S.goToMode = false;
        S.vx *= 0.3; S.vy *= 0.3;
        if (S.mode == 'GOTO') S.mode = 'LOITER';
      } else {
        _moveToward(dx, dy, d, S.goToAlt, pSpd, dt);
      }
    }

    // Waypoint (runs even during autoTakeoff - horizontal movement)
    if (S.mode == 'WAYPOINT' && S.wpNav && wps.isNotEmpty) {
      int idx = S.wpI;
      if (idx < wps.length) {
        var wp = wps[idx];
        double dx = wp.x - S.x, dy = wp.y - S.y, d = sqrt(dx * dx + dy * dy);
        if (d < 6) {
          wp.reached = true;
          S.wpI++;
          if (S.wpI >= wps.length) {
            S.wpNav = false;
            if (S.mode == 'WAYPOINT') S.mode = 'LOITER';
            S.wpI = 0;
          }
        } else {
          _moveToward(dx, dy, d, wp.alt, pSpd, dt);
        }
      }
    }

    // RTL
    if (S.mode == 'RTL') {
      double dx = S.hX - S.x, dy = S.hY - S.y, d = sqrt(dx * dx + dy * dy);
      if (d > 3) {
        _moveToward(dx, dy, d, max(20.0, pAlt), pSpd * 0.8, dt);
      } else {
        S.mode = 'LAND';
        S.vx = 0; S.vy = 0;
      }
    }

    // LAND
    if (S.mode == 'LAND') {
      S.vx *= (1 - 3 * dt);
      S.vy *= (1 - 3 * dt);
      S.tAlt = 0;
      S.vz = max(-2.0, S.vz - 1 * dt);
      if (S.alt < 0.5) {
        S.alt = 0; S.vz = 0; S.vx = 0; S.vy = 0;
        if (S.armed) S.armed = false;
      }
    }

    // LOITER
    if (S.mode == 'LOITER') {
      S.vx *= (1 - 2 * dt);
      S.vy *= (1 - 2 * dt);
    }

    // MANUAL/STABILIZE/ALT_HOLD
    if (S.mode == 'MANUAL' || S.mode == 'STABILIZE' || S.mode == 'ALT_HOLD') {
      S.tHdg = normalizeAngle(S.tHdg);
      double he = angleDiff(S.tHdg, S.hdg);
      double hc = hPid.update(0, -he, dt);
      S.hdg = normalizeAngle(S.hdg + max(-2.0, min(2.0, hc)) * dt);
      double ac = aPid.update(S.tAlt, S.alt, dt);
      S.vz += (max(-5.0, min(8.0, ac)) - S.vz) * 3 * dt;
      S.alt = max(0.0, S.alt + S.vz * dt);
      S.vx *= (1 - 3 * dt);
      S.vy *= (1 - 3 * dt);
    }

    // Missions
    if (mType > 0 && S.armed && S.mode != 'RTL' && S.mode != 'LAND') {
      _updateMission(dt);
    }

    // Thr & Battery
    S.thr = S.alt > 0 ? 20 : 0;
    if (S.mode == 'WAYPOINT' || S.mode == 'AUTO' || S.mode == 'RTL' || S.mode == 'GOTO') {
      S.thr = max(S.thr, 40);
    }
    S.rpm += (S.thr / 100 * 12000 - S.rpm) * 3 * dt;
    double drain = 0.00015 * (1 + S.thr / 120);
    S.bat = max(0.0, S.bat - drain);
    if (S.bat <= 0) S.armed = false;

    // Signal
    double dxH = S.x - S.hX, dyH = S.y - S.hY, hDist = sqrt(dxH * dxH + dyH * dyH);
    S.sig = max(0.0, 100 - hDist * 0.015 + sin(S.fT * 0.5) * 2);
    if (S.alt > 200) S.sig -= 10;

    // Trail
    if (S.alt > 0) trail.add({'x': S.x, 'y': S.y, 't': S.fT});
    if (trail.length > 1200) trail.removeAt(0);

    // Auto takeoff (at END - manages altitude only, doesn't change mode)
    if (autoTakeoff && S.armed) {
      if (S.alt < takeoffTarget - 2) {
        S.vz = 8;
        S.thr = 80;
        S.alt = max(0.0, S.alt + S.vz * dt);
        // DO NOT change S.mode - let WAYPOINT/GOTO navigation continue
      } else {
        autoTakeoff = false;
        // mode stays as-is (takeoffMode was already set before arm())
      }
    }
  }

  void _moveToward(double dx, double dy, double d, double tAlt, double spd, double dt) {
    S.tHdg = atan2(dx, -dy);
    S.tAlt = tAlt;
    double ns = d < 15 ? max(8.0, spd * (d / 15)) : spd;
    double tgtVx = (dx / d) * ns;
    double tgtVy = (dy / d) * ns;
    S.vx += (tgtVx - S.vx) * 5 * dt;
    S.vy += (tgtVy - S.vy) * 5 * dt;
    S.x += S.vx * dt;
    S.y += S.vy * dt;
    double he = angleDiff(S.tHdg, S.hdg);
    S.hdg = normalizeAngle(S.hdg + he * 4 * dt);
    double ac = aPid.update(S.tAlt, S.alt, dt);
    double tvz = max(-5.0, min(8.0, ac));
    S.vz += (tvz - S.vz) * 3 * dt;
    if (S.alt <= 0 && S.vz < 0) S.vz = 0;
    S.alt = max(0.0, S.alt + S.vz * dt);
    S.pitch += (-0.1 - S.pitch) * 3 * dt;
    S.roll += (0 - S.roll) * 3 * dt;
  }

  void _updateMission(double dt) {
    double mt = S.fT - mStart, tx = mCX, ty = mCY;
    if (mType == 1) { // orbit
      tx = mCX + 80 * sin(mt * 0.3);
      ty = mCY - 80 * cos(mt * 0.3);
    } else if (mType == 2) { // figure8
      tx = mCX + 60 * sin(mt * 0.25);
      ty = mCY - 60 * sin(mt * 0.5) * 0.5;
    } else if (mType == 3) { // spiral
      double r = 20 + mt * 5;
      tx = mCX + r * sin(mt * 0.3);
      ty = mCY - r * cos(mt * 0.3);
      S.tAlt = pAlt + mt * 2;
    } else if (mType == 4) { // grid
      double gs = 200, t = mt * 0.15, leg = t % 8, f = t - leg.floorToDouble(), hf = gs / 2;
      int l = leg.floor();
      if (l == 0) { tx = mCX - hf + f * gs; ty = mCY - hf; }
      else if (l == 1) { tx = mCX + hf; ty = mCY - hf + f * gs; }
      else if (l == 2) { tx = mCX + hf - f * gs; ty = mCY; }
      else if (l == 3) { tx = mCX - hf; ty = mCY + f * gs; }
      else if (l == 4) { tx = mCX - hf + f * gs; ty = mCY + hf; }
      else if (l == 5) { tx = mCX + hf; ty = mCY + hf - f * gs; }
      else { tx = mCX; ty = mCY; }
    }
    double dx = tx - S.x, dy = ty - S.y, dist = sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    S.tHdg = atan2(dx, -dy);
    double ms = dist < 20 ? max(8.0, pSpd * (dist / 20)) : pSpd;
    double tgtVx = ms * (dx / dist), tgtVy = ms * (dy / dist);
    S.vx += (tgtVx - S.vx) * 5 * dt;
    S.vy += (tgtVy - S.vy) * 5 * dt;
    double spd = sqrt(S.vx * S.vx + S.vy * S.vy);
    if (spd > 80) { double sc = 80 / spd; S.vx *= sc; S.vy *= sc; }
    S.x += S.vx * dt;
    S.y += S.vy * dt;
    double he = angleDiff(S.tHdg, S.hdg);
    S.hdg = normalizeAngle(S.hdg + he * 4 * dt);
  }

  void arm() {
    S.armed = true;
    S.alt = 0.1;
    S.takeoffX = S.x;
    S.takeoffY = S.y;
    if (S.hX == 0 && S.hY == 0) { S.hX = S.x; S.hY = S.y; }
    S.tAlt = pAlt;
    takeoffTarget = pAlt;
    takeoffMode = S.mode;
    autoTakeoff = true;
  }

  void disarm() {
    S.armed = false;
    S.thr = 0;
    S.rpm = 0;
  }

  void startMission(int type) {
    mType = type.toDouble();
    mCX = S.x;
    mCY = S.y;
    mStart = S.fT;
    if (!S.armed) { arm(); S.mode = 'AUTO'; takeoffMode = 'AUTO'; }
  }

  void stopMission() {
    mType = 0;
    S.mode = 'LOITER';
    fTX = 0; fTY = 0;
  }

  void flyWPs() {
    if (wps.isEmpty) return;
    S.wpNav = !S.wpNav;
    if (S.wpNav) {
      S.goToMode = false;
      S.mode = 'WAYPOINT';
      takeoffMode = 'WAYPOINT';
      S.wpI = 0;
      for (var w in wps) w.reached = false;
      if (!S.armed) arm();
    }
  }

  void goToNextWP() {
    if (wps.isEmpty) return;
    int nextI = -1;
    for (int i = 0; i < wps.length; i++) {
      if (!wps[i].reached) { nextI = i; break; }
    }
    if (nextI == -1) {
      for (var w in wps) w.reached = false;
      nextI = 0;
    }
    S.wpI = nextI;
    S.wpNav = true;
    S.goToMode = false;
    S.mode = 'WAYPOINT';
    takeoffMode = 'WAYPOINT';
    if (!S.armed) arm();
  }

  void skipWP() {
    if (S.mode != 'WAYPOINT' || !S.wpNav || S.wpI >= wps.length) return;
    wps[S.wpI].reached = true;
    S.wpI++;
    if (S.wpI >= wps.length) {
      S.wpNav = false;
      S.mode = 'LOITER';
      S.wpI = 0;
    }
  }

  void clearWPs() {
    wps.clear();
    S.wpI = 0;
    S.wpNav = false;
  }

  void setMode(String m) {
    S.mode = m;
    if (autoTakeoff) takeoffMode = m;
    S.goToMode = false;
    S.wpNav = false;
    mType = 0;
  }
}
