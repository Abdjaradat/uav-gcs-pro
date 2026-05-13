import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectivityService extends ChangeNotifier {
  bool _firestoreConnected = false;
  bool _checking = true;

  bool get isConnected => _firestoreConnected;
  bool get isChecking => _checking;

  ConnectivityService() {
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    _checking = true;
    notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('_health_').doc('_check_').get();
      _firestoreConnected = true;
    } catch (_) {
      _firestoreConnected = false;
    }
    _checking = false;
    notifyListeners();
  }

  Future<void> refresh() => _checkConnection();
}
