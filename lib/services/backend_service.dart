import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/waypoint.dart';

class BackendService {
  static const String _defaultUrl = 'http://10.0.2.2:10000';
  String _baseUrl;

  BackendService([String? url]) : _baseUrl = url ?? _defaultUrl;

  set baseUrl(String url) => _baseUrl = url;

  Map<String, String> _headers() => {'Content-Type': 'application/json'};

  Future<String?> _getIdToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMissions(String uid) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/missions?uid=$uid'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load missions: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> saveMission({
    required String uid,
    required String name,
    required List<Waypoint> waypoints,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/missions'),
      headers: _headers(),
      body: jsonEncode({
        'uid': uid,
        'name': name,
        'waypoints': waypoints
            .map((wp) => {'x': wp.x, 'y': wp.y, 'alt': wp.alt, 'reached': wp.reached})
            .toList(),
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to save mission: ${res.statusCode}');
  }

  Future<void> sendTelemetry(Map<String, dynamic> data) async {
    final token = await _getIdToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/telemetry'),
      headers: {
        ..._headers(),
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception('Telemetry send failed: ${res.statusCode}');
    }
  }
}
