import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/drone_state.dart';

class MavlinkMessage {
  final int msgId;
  final int sysId;
  final int compId;
  final Map<String, dynamic> fields;
  final Uint8List raw;
  MavlinkMessage({required this.msgId, required this.sysId, required this.compId, required this.fields, required this.raw});
}

enum MavlinkState { disconnected, connecting, connected, lost }

class MavlinkService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _sub;

  String _host = '127.0.0.1';
  int _port = 14550;
  int _targetSysId = 1;
  int _targetCompId = 1;

  MavlinkState _state = MavlinkState.disconnected;
  MavlinkState get state => _state;

  String get host => _host;
  int get port => _port;

  DateTime? _lastHeartbeat;
  int _seq = 0;

  final StreamController<MavlinkMessage> _msgController = StreamController<MavlinkMessage>.broadcast();
  Stream<MavlinkMessage> get messages => _msgController.stream;

  DroneState? _lastState;
  DroneState? get lastState => _lastState;

  void configure({String host = '127.0.0.1', int port = 14550, int sysId = 1, int compId = 1}) {
    _host = host;
    _port = port;
    _targetSysId = sysId;
    _targetCompId = compId;
  }

  Future<void> connect() async {
    if (_state == MavlinkState.connected) return;
    _setState(MavlinkState.connecting);
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _sub = _socket!.listen(_onPacket, cancelOnError: false);
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sendHeartbeat());
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnection());
      _setState(MavlinkState.connected);
    } catch (e) {
      debugPrint('MAVLink connect error: $e');
      _setState(MavlinkState.disconnected);
    }
  }

  void disconnect() {
    _sub?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.close();
    _socket = null;
    _setState(MavlinkState.disconnected);
  }

  void _setState(MavlinkState s) {
    _state = s;
    notifyListeners();
  }

  void _onPacket(dynamic event) {
    if (event == RawSocketEvent.read) {
      final dp = _socket!.receive();
      if (dp != null) {
        _parseBuffer(dp.data);

      }
    }
  }

  // --- MAVLink 2.0 Frame Parsing ---
  void _parseBuffer(Uint8List data) {
    int i = 0;
    while (i < data.length - 1) {
      // Find STX (MAVLink 2.0: 0xFD)
      if (data[i] == 0xFD && i + 12 < data.length) {
        final len = data[i + 1];
        final incompatFlags = data[i + 2];
        final compatFlags = data[i + 3];
        final seq = data[i + 4];
        final sysId = data[i + 5];
        final compId = data[i + 6];
        final msgId = data[i + 7] | (data[i + 8] << 8) | (data[i + 9] << 16);
        final payloadLen = len;
        final frameLen = 10 + payloadLen + 2; // header + payload + CRC
        if (i + frameLen <= data.length) {
          final payload = data.sublist(i + 10, i + 10 + payloadLen);
          final crc1 = data[i + 10 + payloadLen];
          final crc2 = data[i + 10 + payloadLen + 1];
          final fields = _decodeMessage(msgId, payload);
          if (fields != null) {
            final msg = MavlinkMessage(
              msgId: msgId,
              sysId: sysId,
              compId: compId,
              fields: fields,
              raw: data.sublist(i, i + frameLen),
            );
            _onMessage(msg);
            _msgController.add(msg);
          }
          i += frameLen;
          continue;
        }
      }
      i++;
    }
  }

  void _onMessage(MavlinkMessage msg) {
    if (msg.msgId == 0) _lastHeartbeat = DateTime.now(); // HEARTBEAT
    if (msg.msgId == 33 || msg.msgId == 30 || msg.msgId == 74) {
      _updateDroneState(msg);
    }
  }

  void _updateDroneState(MavlinkMessage msg) {
    _lastState ??= DroneState();
    final s = _lastState!;
    switch (msg.msgId) {
      case 30: // ATTITUDE
        s.pitch = (msg.fields['pitch'] as num?)?.toDouble() ?? s.pitch;
        s.roll = (msg.fields['roll'] as num?)?.toDouble() ?? s.roll;
        s.hdg = (msg.fields['yaw'] as num?)?.toDouble() ?? s.hdg;
        break;
      case 33: // GLOBAL_POSITION_INT
        s.x = ((msg.fields['lat'] as num?)?.toDouble() ?? s.x) / 1e7;
        s.y = ((msg.fields['lon'] as num?)?.toDouble() ?? s.y) / 1e7;
        s.alt = (msg.fields['relative_alt'] as num?)?.toDouble() ?? s.alt;
        s.hdg = (msg.fields['hdg'] as num?)?.toDouble() ?? s.hdg;
        break;
      case 74: // VFR_HUD
        s.spd = (msg.fields['groundspeed'] as num?)?.toDouble() ?? s.spd;
        s.alt = (msg.fields['alt'] as num?)?.toDouble() ?? s.alt;
        s.hdg = (msg.fields['heading'] as num?)?.toDouble() ?? s.hdg;
        break;
      case 1: // SYS_STATUS
        s.bat = (msg.fields['battery_remaining'] as num?)?.toDouble() ?? s.bat;
        break;
      case 24: // GPS_RAW_INT
        s.sig = (msg.fields['satellites_visible'] as num?)?.toDouble() ?? s.sig;
        break;
    }
  }

  void _checkConnection() {
    if (_lastHeartbeat != null && DateTime.now().difference(_lastHeartbeat!).inSeconds > 10) {
      _setState(MavlinkState.lost);
    }
  }

  // --- MAVLink Message Decoding ---
  Map<String, dynamic>? _decodeMessage(int msgId, Uint8List payload) {
    final bb = ByteData.view(payload.buffer, payload.offsetInBytes, payload.length);
    try {
      switch (msgId) {
        case 0: // HEARTBEAT
          return {
            'type': bb.getUint8(0),
            'autopilot': bb.getUint8(1),
            'base_mode': bb.getUint8(2),
            'custom_mode': bb.getUint32(3, Endian.little),
            'system_status': bb.getUint8(7),
            'mavlink_version': bb.getUint8(8),
          };
        case 30: // ATTITUDE
          return {
            'roll': bb.getFloat32(0, Endian.little),
            'pitch': bb.getFloat32(4, Endian.little),
            'yaw': bb.getFloat32(8, Endian.little),
            'rollspeed': bb.getFloat32(12, Endian.little),
            'pitchspeed': bb.getFloat32(16, Endian.little),
            'yawspeed': bb.getFloat32(20, Endian.little),
          };
        case 33: // GLOBAL_POSITION_INT
          return {
            'lat': bb.getInt32(0, Endian.little),
            'lon': bb.getInt32(4, Endian.little),
            'alt': bb.getInt32(8, Endian.little) / 1000.0,
            'relative_alt': bb.getInt32(12, Endian.little) / 1000.0,
            'vx': bb.getInt16(16, Endian.little) / 100.0,
            'vy': bb.getInt16(18, Endian.little) / 100.0,
            'vz': bb.getInt16(20, Endian.little) / 100.0,
            'hdg': bb.getUint16(22, Endian.little) / 100.0,
          };
        case 74: // VFR_HUD
          return {
            'airspeed': bb.getFloat32(0, Endian.little),
            'groundspeed': bb.getFloat32(4, Endian.little),
            'heading': bb.getInt16(8, Endian.little),
            'throttle': bb.getUint16(10, Endian.little),
            'alt': bb.getFloat32(12, Endian.little),
            'climb': bb.getFloat32(16, Endian.little),
          };
        case 1: // SYS_STATUS
          return {
            'battery_remaining': bb.getInt8(18).toDouble(),
          };
        case 24: // GPS_RAW_INT
          return {
            'satellites_visible': bb.getUint8(17).toDouble(),
          };
      }
    } catch (_) {}
    return null;
  }

  // --- MAVLink Heartbeat Encoding ---
  void _sendHeartbeat() {
    if (_socket == null) return;
    final payload = Uint8List(9);
    final bb = ByteData.view(payload.buffer);
    bb.setUint8(0, 2); // MAV_TYPE_QUADROTOR
    bb.setUint8(1, 8); // MAV_AUTOPILOT_GENERIC
    bb.setUint8(2, 0x81); // base_mode: MANUAL + ARMED
    bb.setUint32(3, 0, Endian.little); // custom_mode
    bb.setUint8(7, 4); // MAV_STATE_ACTIVE
    bb.setUint8(8, 2); // mavlink_version
    _sendFrame(0, payload);
  }

  void sendCommand(int command, Map<String, int> params) {
    // MAVLink COMMAND_LONG (msgId 76)
    final payload = Uint8List(35);
    final bb = ByteData.view(payload.buffer);
    bb.setUint8(0, 0); // target_sys
    bb.setUint8(1, 0); // target_comp
    bb.setUint16(2, command, Endian.little);
    bb.setUint8(4, 1); // confirmation
    bb.setFloat32(5, (params['param1'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(9, (params['param2'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(13, (params['param3'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(17, (params['param4'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(21, (params['param5'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(25, (params['param6'] ?? 0).toDouble(), Endian.little);
    bb.setFloat32(29, (params['param7'] ?? 0).toDouble(), Endian.little);
    _sendFrame(76, payload);
  }

  void _sendFrame(int msgId, Uint8List payload) {
    if (_socket == null) return;
    final len = payload.length;
    final frame = Uint8List(12 + len + 2);
    final bb = ByteData.view(frame.buffer);
    bb.setUint8(0, 0xFD); // STX
    bb.setUint8(1, len);
    bb.setUint8(2, 0); // incompat
    bb.setUint8(3, 0); // compat
    bb.setUint8(4, _seq++);
    bb.setUint8(5, 255); // sysId (GCS)
    bb.setUint8(6, 0); // compId
    bb.setUint8(7, msgId & 0xFF);
    bb.setUint8(8, (msgId >> 8) & 0xFF);
    bb.setUint8(9, (msgId >> 16) & 0xFF);
    frame.setRange(10, 10 + len, payload);
    // CRC placeholder
    final addr = InternetAddress.tryParse(_host);
    if (addr != null) {
      _socket!.send(frame, addr, _port);
    }
  }

  @override
  void dispose() {
    disconnect();
    _msgController.close();
    super.dispose();
  }
}
