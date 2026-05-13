import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/drone_state.dart';
import '../models/waypoint.dart';
import '../services/simulator_engine.dart';
import '../services/licensing_service.dart';
import '../services/tile_providers.dart';
import '../services/mavlink_service.dart';
import '../services/flight_recorder.dart';
import '../widgets/hud_painter.dart';
import '../widgets/camera_3d_view.dart';

class SimulatorScreen extends StatefulWidget {
  final LicensingService lic;
  const SimulatorScreen({super.key, required this.lic});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> with TickerProviderStateMixin {
  final SimulatorEngine _eng = SimulatorEngine();
  final MavlinkService _mav = MavlinkService();
  final FlightRecorder _rec = FlightRecorder();
  Timer? _timer;

  static const double _bc = 32.551, _bl = 35.8559;
  final MapController _mapCtrl = MapController();

  // UI state
  String _logText = '';
  final List<String> _logLines = [];
  final Set<String> _keys = {};
  String _wpNavStatus = '';
  MapType _currentMap = MapType.osm;
  bool _show3D = false;
  String _mavHost = '127.0.0.1';
  final _mavPortCtrl = TextEditingController(text: '14550');
  final _mavHostCtrl = TextEditingController(text: '127.0.0.1');
  bool _useMavlink = false;

  // Recorder
  String _recName = 'Flight ${DateTime.now().toString().substring(0, 16)}';
  FlightRecording? _selectedRecording;

  // Playback
  Timer? _playbackTimer;
  DroneState _pbState = DroneState();

  @override
  void initState() {
    super.initState();
    _eng.S.hX = _eng.S.x;
    _eng.S.hY = _eng.S.y;
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_useMavlink && _mav.lastState != null) {
        _eng.S.x = _mav.lastState!.x;
        _eng.S.y = _mav.lastState!.y;
        _eng.S.alt = _mav.lastState!.alt;
        _eng.S.spd = _mav.lastState!.spd;
        _eng.S.hdg = _mav.lastState!.hdg;
        _eng.S.pitch = _mav.lastState!.pitch;
        _eng.S.roll = _mav.lastState!.roll;
        _eng.S.bat = _mav.lastState!.bat;
        _eng.S.sig = _mav.lastState!.sig;
      }
      _eng.update(0.033);
      _updateWpStatus();
      if (_rec.isRecording) _rec.recordFrame(_eng.S);
      if (_rec.isPlaying) _processPlayback();
      _mav.notifyListeners(); // keep mavlink state flowing
      setState(() {});
    });
    _rec.loadRecordings();
    _mav.addListener(_onMavChange);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playbackTimer?.cancel();
    _mav.disconnect();
    _mav.removeListener(_onMavChange);
    _mav.dispose();
    _mavPortCtrl.dispose();
    _mavHostCtrl.dispose();
    super.dispose();
  }

  void _onMavChange() => setState(() {});

  void _log(String msg) {
    _logLines.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    if (_logLines.length > 100) _logLines.removeAt(0);
    _logText = _logLines.join('\n');
  }

  void _updateWpStatus() {
    if (_eng.S.mode == 'WAYPOINT' && _eng.S.wpNav) {
      _wpNavStatus = 'WP ${_eng.S.wpI + 1}/${_eng.wps.length}';
    } else {
      _wpNavStatus = '';
    }
  }

  LatLng _toLL(double x, double y) {
    const double scale = 0.0002;
    return LatLng(_bc + y * scale, _bl + x * scale);
  }

  (double, double) _toLocal(double lat, double lon) {
    const double scale = 1 / 0.0002;
    return ((lon - _bl) * scale, (lat - _bc) * scale);
  }

  void _addWP() {
    double a = _eng.S.hdg;
    _eng.wps.add(Waypoint(
      x: _eng.S.x + sin(a) * 50,
      y: _eng.S.y - cos(a) * 50,
      alt: _eng.S.alt > 0 ? _eng.S.alt : 50,
    ));
    _log('WP ${_eng.wps.length} added');
  }

  void _processPlayback() {
    final frame = _rec.getPlaybackFrame();
    if (frame != null) {
      _pbState.x = frame['x'];
      _pbState.y = frame['y'];
      _pbState.alt = frame['alt'];
      _pbState.spd = frame['spd'];
      _pbState.hdg = frame['hdg'];
      _pbState.pitch = frame['pitch'];
      _pbState.roll = frame['roll'];
    }
  }

  // ===== MAVLink =====
  Future<void> _connectMav() async {
    _mav.configure(host: _mavHostCtrl.text, port: int.tryParse(_mavPortCtrl.text) ?? 14550);
    await _mav.connect();
    _log('MAVLink: ${_mav.state == MavlinkState.connected ? "connected" : "failed"}');
  }

  void _disconnectMav() {
    _mav.disconnect();
    _log('MAVLink disconnected');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060C14),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: Row(children: [
            _buildLeftPanel(),
            Expanded(child: _buildCenter()),
            _buildRightPanel(),
          ])),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 42,
      color: const Color(0xFF0A1628),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        _dot(_eng.S.armed ? const Color(0xFF00FF88) : const Color(0xFFFF3333)),
        const SizedBox(width: 8),
        Text(_eng.S.armed ? 'ARMED' : 'DISARMED',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                color: _eng.S.armed ? const Color(0xFF00FF88) : const Color(0xFFFF3333))),
        const SizedBox(width: 16),
        Text(_eng.S.mode, style: const TextStyle(fontSize: 11, color: Color(0xFF00D4FF))),
        const SizedBox(width: 12),

        // MAVLink status
        if (_useMavlink) ...[
          _dot(_mav.state == MavlinkState.connected
              ? const Color(0xFF00FF88)
              : _mav.state == MavlinkState.lost
                  ? const Color(0xFFFF3333)
                  : const Color(0xFFFFAA00)),
          const SizedBox(width: 4),
          Text('MAV ${_mav.state.name}',
              style: TextStyle(fontSize: 10, color: _mav.state == MavlinkState.connected
                  ? const Color(0xFF00FF88) : const Color(0xFFFFAA00))),
        ],

        const Spacer(),

        // Recording indicator
        if (_rec.isRecording) ...[
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3333)),
          ),
          const SizedBox(width: 4),
          const Text('REC', style: TextStyle(fontSize: 10, color: Color(0xFFFF3333), fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
        ],

        if (_wpNavStatus.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 12),
              child: Text(_wpNavStatus, style: const TextStyle(fontSize: 10, color: Color(0xFF00FF88)))),
        Text('BAT ${_eng.S.bat.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: _batColor())),
      ]),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      width: 200,
      color: const Color(0xFF08111E),
      child: SingleChildScrollView(child: Column(children: [
        _panelTitle('CONTROLS'),
        _ctrlBtn('ARM/\nDISARM', _eng.S.armed ? const Color(0xFF00FF88) : const Color(0xFFFFAA00), () {
          _eng.S.armed ? _eng.disarm() : _eng.setMode('LOITER'); _eng.arm();
        }),
        _ctrlBtn('LAND', const Color(0xFFFF3333), () => _eng.setMode('LAND')),
        _ctrlBtn('RTL', const Color(0xFFFFAA00), () => _eng.setMode('RTL')),
        _ctrlBtn('LOITER', const Color(0xFF00D4FF), () => _eng.setMode('LOITER')),

        _panelTitle('MODE'),
        Wrap(spacing: 4, runSpacing: 4, children: [
          _modeBtn('MANUAL'), _modeBtn('STABILIZE'), _modeBtn('ALT_HOLD'),
        ]),

        _panelTitle('MISSIONS'),
        _ctrlBtn('ORBIT', const Color(0xFF00D4FF), () => _eng.startMission(1)),
        _ctrlBtn('FIGURE-8', const Color(0xFF00D4FF), () => _eng.startMission(2)),
        _ctrlBtn('SPIRAL', const Color(0xFF00D4FF), () => _eng.startMission(3)),
        _ctrlBtn('GRID', const Color(0xFF00D4FF), () => _eng.startMission(4)),
        _ctrlBtn('STOP', const Color(0xFFFF3333), () => _eng.stopMission()),

        // === MAP TYPE ===
        _panelTitle('MAP TYPE'),
        Padding(
          padding: const EdgeInsets.all(4),
          child: DropdownButton<MapType>(
            value: _currentMap,
            dropdownColor: const Color(0xFF0A1628),
            style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 11),
            isExpanded: true,
            items: mapTypes.map((m) => DropdownMenuItem(
              value: m.type, child: Text(m.label, style: const TextStyle(fontSize: 10)),
            )).toList(),
            onChanged: (v) => setState(() => _currentMap = v ?? MapType.osm),
          ),
        ),

        // === 3D VIEW TOGGLE ===
        _panelTitle('3D CAMERA'),
        _ctrlBtn(_show3D ? 'HIDE 3D' : 'SHOW 3D',
            _show3D ? const Color(0xFFFF3333) : const Color(0xFF4ECDC4),
            () => setState(() => _show3D = !_show3D)),

        // === MAVLINK ===
        _panelTitle('MAVLINK'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _mavHostCtrl,
            style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 10),
            decoration: const InputDecoration(
              labelText: 'Host', labelStyle: TextStyle(color: Color(0xFF5A8A9E), fontSize: 10),
              isDense: true, border: InputBorder.none,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _mavPortCtrl,
            style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 10),
            decoration: const InputDecoration(
              labelText: 'Port', labelStyle: TextStyle(color: Color(0xFF5A8A9E), fontSize: 10),
              isDense: true, border: InputBorder.none,
            ),
          ),
        ),
        Row(children: [
          Expanded(
            child: _ctrlBtn(
              _mav.state == MavlinkState.connected ? 'DISCONNECT' : 'CONNECT',
              _mav.state == MavlinkState.connected ? const Color(0xFFFF3333) : const Color(0xFF00FF88),
              _mav.state == MavlinkState.connected ? _disconnectMav : _connectMav,
            ),
          ),
        ]),
        Row(children: [
          _tinyBtn('USE MAV', _useMavlink, () => setState(() => _useMavlink = !_useMavlink)),
        ]),

        // === RECORDER ===
        _panelTitle('RECORDER'),
        if (!_rec.isRecording) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 10),
              decoration: const InputDecoration(
                labelText: 'Name', labelStyle: TextStyle(color: Color(0xFF5A8A9E), fontSize: 10),
                isDense: true, border: InputBorder.none,
              ),
              onChanged: (v) => _recName = v,
              controller: TextEditingController(text: _recName),
            ),
          ),
          _ctrlBtn('START REC', const Color(0xFFFF3333), () {
            _rec.startRecording(_recName);
            _log('Recording started: $_recName');
          }),
        ] else
          _ctrlBtn('STOP REC', const Color(0xFFFFAA00), () async {
            await _rec.stopRecording();
            _log('Recording saved');
          }),

        // === PLAYBACK ===
        if (_rec.recordings.isNotEmpty) ...[
          _panelTitle('PLAYBACK'),
          SizedBox(
            height: 80,
            child: ListView.builder(
              itemCount: _rec.recordings.length,
              itemBuilder: (_, i) {
                final r = _rec.recordings[i];
                final isPlaying = _rec.isPlaying && _rec.playbackRecording?.id == r.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRecording = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _selectedRecording?.id == r.id ? const Color(0x0D00D4FF) : null,
                      border: isPlaying ? Border.all(color: const Color(0xFF00FF88), width: 1) : null,
                    ),
                    child: Row(children: [
                      Expanded(child: Text('${r.name} (${r.frameCount}f)',
                          style: const TextStyle(color: Color(0xFF5A8A9E), fontSize: 8, fontFamily: 'monospace'))),
                      if (!isPlaying)
                        GestureDetector(
                          onTap: () { _rec.startPlayback(r); _log('Playback: ${r.name}'); },
                          child: const Icon(Icons.play_arrow, color: Color(0xFF00D4FF), size: 14),
                        )
                      else
                        GestureDetector(
                          onTap: () { _rec.stopPlayback(); _log('Playback stopped'); },
                          child: const Icon(Icons.stop, color: Color(0xFFFF3333), size: 14),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ])),
    );
  }

  Widget _buildCenter() {
    return Stack(children: [
      // Map
      if (!_show3D)
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _toLL(_eng.S.x, _eng.S.y),
            initialZoom: 16,
            onTap: (tap, ll) {
              if (_eng.wps.length < (widget.lic.isPro || widget.lic.isSub ? 999 : 5)) {
                var loc = _toLocal(ll.latitude, ll.longitude);
                _eng.wps.add(Waypoint(x: loc.$1, y: loc.$2, alt: _eng.pAlt));
                _log('WP ${_eng.wps.length} added');
              }
            },
          ),
          children: [
            mapTypes.firstWhere((m) => m.type == _currentMap).builder(false),
            if (_eng.wps.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                  points: _eng.wps.map((w) => _toLL(w.x, w.y)).toList(),
                  color: const Color(0x8800D4FF),
                  strokeWidth: 1.5,
                ),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: _toLL(_eng.S.x, _eng.S.y),
                width: 24, height: 24,
                child: Transform.rotate(
                  angle: _eng.S.hdgDeg * pi / 180,
                  child: Icon(Icons.north, color: _eng.S.armed ? const Color(0xFFFF2255) : const Color(0xFF5A8A9E), size: 24),
                ),
              ),
              Marker(
                point: _toLL(_eng.S.hX, _eng.S.hY),
                width: 20, height: 20,
                child: const Text('H', style: TextStyle(color: Color(0xFFFFAA00), fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ..._eng.wps.asMap().entries.map((e) => Marker(
                point: _toLL(e.value.x, e.value.y),
                width: 22, height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: e.value.reached ? const Color(0xFF00FF88) : const Color(0xFF00D4FF)),
                    color: e.value.reached ? const Color(0x4400FF88) : const Color(0x2200D4FF),
                  ),
                  child: Center(child: Text('${e.key + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'))),
                ),
              )),
            ]),
          ],
        ),

      // 3D Camera View
      if (_show3D)
        Positioned.fill(
          child: _rec.isPlaying
              ? Camera3DView(state: _pbState)
              : Camera3DView(state: _eng.S),
        ),

      // HUD overlay (always on top)
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: HudPainter(_eng.S)))),

      // Waypoint target indicator
      if (_eng.S.mode == 'WAYPOINT' && _eng.S.wpNav && _eng.S.wpI < _eng.wps.length)
        Positioned(
          bottom: 4, left: 4,
          child: Text('→ WP${_eng.S.wpI + 1}', style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 11, fontFamily: 'monospace')),
        ),
    ]);
  }

  Widget _buildRightPanel() {
    return Container(
      width: 200,
      color: const Color(0xFF08111E),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _panelTitle('POSITION'),
        _dataRow('ALT', '${_eng.S.alt.toStringAsFixed(1)} m'),
        _dataRow('SPD', '${_eng.S.speed.toStringAsFixed(1)} m/s'),
        _dataRow('HDG', '${_eng.S.hdgDeg.toStringAsFixed(1)}°'),
        _dataRow('V/S', '${_eng.S.vz.toStringAsFixed(1)} m/s'),
        _dataRow('DIST', '${sqrt((_eng.S.x - _eng.S.hX) * (_eng.S.x - _eng.S.hX) + (_eng.S.y - _eng.S.hY) * (_eng.S.y - _eng.S.hY)).toStringAsFixed(0)} m'),

        _panelTitle('WAYPOINTS'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            _wpBtn('Add', () => _addWP()),
            _wpBtn('Fly', () => _eng.flyWPs()),
            _wpBtn('Go Seq', () => _eng.goToNextWP()),
            _wpBtn('Skip', () => _eng.skipWP()),
            _wpBtn('Clear', () => _eng.clearWPs()),
          ]),
        ),

        _panelTitle('LOG'),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(4),
            child: SingleChildScrollView(
              child: Text(_logText, style: const TextStyle(color: Color(0xFF5A8A9E), fontSize: 9, fontFamily: 'monospace')),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _panelTitle(String t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: const Color(0x0D00D4FF),
      child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
          color: Color(0xFF00D4FF), letterSpacing: 1.5)),
    );
  }

  Widget _ctrlBtn(String t, Color c, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: c,
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ),
    );
  }

  Widget _tinyBtn(String t, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: active ? const Color(0xFF00FF88) : const Color(0xFF0D2D4A)),
          color: active ? const Color(0x1500FF88) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(t, style: TextStyle(fontSize: 8, color: active ? const Color(0xFF00FF88) : const Color(0xFF5A8A9E))),
      ),
    );
  }

  Widget _modeBtn(String m) {
    bool act = _eng.S.mode == m;
    bool allowed = widget.lic.canUseMode(m);
    return GestureDetector(
      onTap: allowed ? () => _eng.setMode(m) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: act ? const Color(0xFF00D4FF) : const Color(0xFF0D2D4A)),
          color: act ? const Color(0x1500D4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(m, style: TextStyle(fontSize: 9, color: allowed ? const Color(0xFF5A8A9E) : const Color(0xFF3A5A6E))),
      ),
    );
  }

  Widget _wpBtn(String t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0D2D4A)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(t, style: const TextStyle(fontSize: 9, color: Color(0xFF00D4FF))),
      ),
    );
  }

  Widget _dataRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF5A8A9E), fontFamily: 'monospace')),
        Text(val, style: const TextStyle(fontSize: 11, color: Color(0xFF00FF88), fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Color _batColor() {
    if (_eng.S.bat > 50) return const Color(0xFF00FF88);
    if (_eng.S.bat > 20) return const Color(0xFFFFAA00);
    return const Color(0xFFFF3333);
  }
}
