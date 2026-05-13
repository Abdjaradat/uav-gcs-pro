import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/drone_state.dart';

class FlightRecording {
  final String id;
  final String name;
  final DateTime startTime;
  DateTime endTime;
  final List<Map<String, dynamic>> frames;
  int? currentPlaybackIndex;

  FlightRecording({
    required this.id,
    required this.name,
    required this.startTime,
    DateTime? endTime,
    List<Map<String, dynamic>>? frames,
    this.currentPlaybackIndex,
  }) : endTime = endTime ?? startTime,
       frames = frames ?? [];

  Duration get duration => endTime.difference(startTime);
  int get frameCount => frames.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'frames': frames,
      };

  factory FlightRecording.fromJson(Map<String, dynamic> json) => FlightRecording(
        id: json['id'],
        name: json['name'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        frames: List<Map<String, dynamic>>.from(json['frames']),
      );
}

class FlightRecorder extends ChangeNotifier {
  List<FlightRecording> _recordings = [];
  FlightRecording? _activeRecording;
  bool _isRecording = false;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  FlightRecording? _playbackRecording;

  List<FlightRecording> get recordings => _recordings;
  FlightRecording? get activeRecording => _activeRecording;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _playbackSpeed;
  FlightRecording? get playbackRecording => _playbackRecording;
  int? get playbackIndex => _playbackRecording?.currentPlaybackIndex;

  set playbackSpeed(double v) {
    _playbackSpeed = v.clamp(0.1, 10.0);
    notifyListeners();
  }

  Future<void> loadRecordings() async {
    final dir = await _getDir();
    if (!await dir.exists()) return;
    final files = await dir.list().toList();
    _recordings = [];
    for (final f in files) {
      if (f.path.endsWith('.json')) {
        try {
          final content = await File(f.path).readAsString();
          _recordings.add(FlightRecording.fromJson(jsonDecode(content)));
        } catch (_) {}
      }
    }
    _recordings.sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();
  }

  Future<Directory> _getDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/flight_recordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void startRecording(String name) {
    _activeRecording = FlightRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      startTime: DateTime.now(),
    );
    _isRecording = true;
    notifyListeners();
  }

  void recordFrame(DroneState state) {
    if (!_isRecording || _activeRecording == null) return;
    _activeRecording!.frames.add({
      'time': DateTime.now().difference(_activeRecording!.startTime).inMilliseconds,
      'x': state.x,
      'y': state.y,
      'alt': state.alt,
      'spd': state.spd,
      'hdg': state.hdg,
      'pitch': state.pitch,
      'roll': state.roll,
      'vx': state.vx,
      'vy': state.vy,
      'vz': state.vz,
      'bat': state.bat,
      'mode': state.mode,
    });
  }

  Future<void> stopRecording() async {
    if (_activeRecording == null) return;
    _activeRecording!.endTime = DateTime.now();
    _isRecording = false;
    _recordings.insert(0, _activeRecording!);
    await _saveRecording(_activeRecording!);
    _activeRecording = null;
    notifyListeners();
  }

  Future<void> _saveRecording(FlightRecording rec) async {
    final dir = await _getDir();
    final file = File('${dir.path}/${rec.id}.json');
    await file.writeAsString(jsonEncode(rec.toJson()));
  }

  Future<void> deleteRecording(String id) async {
    _recordings.removeWhere((r) => r.id == id);
    final dir = await _getDir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  Future<String> exportKml(FlightRecording rec) async {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buf.writeln('  <Document>');
    buf.writeln('    <name>${rec.name}</name>');
    buf.writeln('    <Placemark>');
    buf.writeln('      <LineString>');
    buf.writeln('        <coordinates>');
    for (final f in rec.frames) {
      buf.writeln('          ${f['y']},${f['x']},${f['alt']}');
    }
    buf.writeln('        </coordinates>');
    buf.writeln('      </LineString>');
    buf.writeln('    </Placemark>');
    buf.writeln('  </Document>');
    buf.writeln('</kml>');
    final dir = await _getDir();
    final file = File('${dir.path}/${rec.id}.kml');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  // --- Playback ---
  void startPlayback(FlightRecording rec) {
    _playbackRecording = rec;
    _playbackRecording!.currentPlaybackIndex = 0;
    _isPlaying = true;
    notifyListeners();
  }

  Map<String, dynamic>? getPlaybackFrame() {
    if (!_isPlaying || _playbackRecording == null) return null;
    final idx = _playbackRecording!.currentPlaybackIndex;
    if (idx == null || idx >= _playbackRecording!.frames.length) {
      stopPlayback();
      return null;
    }
    final frame = _playbackRecording!.frames[idx];
    _playbackRecording!.currentPlaybackIndex = idx + 1;
    notifyListeners();
    return frame;
  }

  void stopPlayback() {
    _isPlaying = false;
    _playbackRecording = null;
    notifyListeners();
  }

  void seekPlayback(int frameIndex) {
    if (_playbackRecording == null) return;
    _playbackRecording!.currentPlaybackIndex = frameIndex.clamp(0, _playbackRecording!.frames.length);
    notifyListeners();
  }
}
