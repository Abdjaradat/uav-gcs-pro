import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/waypoint.dart';

class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authState => _auth.authStateChanges();

  // --- Email/Password ---
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpWithEmail(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user?.updateDisplayName(name);
    return cred;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // --- Anonymous ---
  Future<UserCredential> signInAnonymously() =>
      _auth.signInAnonymously();

  // --- Phone ---
  Future<void> verifyPhone({
    required String phoneNumber,
    required PhoneVerificationCompleted onCompleted,
    required PhoneVerificationFailed onFailed,
    required PhoneCodeSent onCodeSent,
    required PhoneCodeAutoRetrievalTimeout onTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onCompleted,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onTimeout,
    );
  }

  Future<UserCredential> signInWithPhone({
    required String verificationId,
    required String smsCode,
  }) async {
    final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    return _auth.signInWithCredential(cred);
  }

  // --- Google ---
  Future<UserCredential> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    return _auth.signInWithPopup(googleProvider);
  }

  // --- Apple ---
  Future<UserCredential> signInWithApple() async {
    final appleProvider = AppleAuthProvider();
    return _auth.signInWithPopup(appleProvider);
  }

  // --- GitHub ---
  Future<UserCredential> signInWithGitHub() async {
    final githubProvider = GithubAuthProvider();
    return _auth.signInWithPopup(githubProvider);
  }

  // --- Microsoft ---
  Future<UserCredential> signInWithMicrosoft() async {
    final provider = OAuthProvider('microsoft.com');
    return _auth.signInWithPopup(provider);
  }

  // --- Yahoo ---
  Future<UserCredential> signInWithYahoo() async {
    final provider = OAuthProvider('yahoo.com');
    return _auth.signInWithPopup(provider);
  }

  // --- Generic OAuth ---
  Future<UserCredential> signInWithOAuth(String providerId) async {
    final provider = OAuthProvider(providerId);
    return _auth.signInWithPopup(provider);
  }

  // --- Sign Out ---
  Future<void> signOut() => _auth.signOut();

  // --- Delete Account ---
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  // --- Missions ---
  Future<DocumentReference> saveMission({
    required String name,
    required List<Waypoint> waypoints,
    String? uid,
  }) async {
    final ownerId = uid ?? _auth.currentUser?.uid ?? 'anonymous';
    return _db.collection('missions').add({
      'uid': ownerId,
      'name': name,
      'waypoints': waypoints
          .map((wp) => {'x': wp.x, 'y': wp.y, 'alt': wp.alt, 'reached': wp.reached})
          .toList(),
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> uploadTelemetry({
    required double lat,
    required double lng,
    required double alt,
    required double speed,
    required double heading,
    required double battery,
    required String mode,
    String? missionId,
  }) async {
    await _db.collection('telemetry').add({
      'uid': _auth.currentUser?.uid ?? 'anonymous',
      'missionId': missionId,
      'lat': lat,
      'lng': lng,
      'alt': alt,
      'speed': speed,
      'heading': heading,
      'battery': battery,
      'mode': mode,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMissions({String? uid}) {
    final ownerId = uid ?? _auth.currentUser?.uid;
    if (ownerId == null) return const Stream.empty();
    return _db
        .collection('missions')
        .where('uid', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteMission(String docId) async {
    await _db.collection('missions').doc(docId).delete();
  }
}
