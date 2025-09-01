// lib/services/auth_service.dart
import 'dart:async';
import 'dart:math'; // <- add for code generation
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { blind, guardian }

class AppUser {
  final String uid;
  final UserRole role;
  final bool otcVerified;
  AppUser(this.uid, this.role, {this.otcVerified = false});
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  // ------------ helper: ensure user doc exists ------------
  Future<void> _ensureUserDoc(User fbUser) async {
    final ref = _db.collection('users').doc(fbUser.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'role': 'blind',
        'email': fbUser.email,
        'otcVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ------------ auth state -> AppUser ------------
  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().asyncMap((fbUser) async {
        if (fbUser == null) {
          _currentUser = null;
          return null;
        }
        await _ensureUserDoc(fbUser);
        final snap = await _db.collection('users').doc(fbUser.uid).get();
        final data = snap.data() ?? {};
        final roleStr = (data['role'] as String?) ?? 'blind';
        final role = roleStr == 'guardian' ? UserRole.guardian : UserRole.blind;
        final otcVerified = (data['otcVerified'] as bool?) ?? false;
        _currentUser = AppUser(fbUser.uid, role, otcVerified: otcVerified);
        return _currentUser;
      });

  // ------------ guardian pairing code helpers ------------
  String _generate6Digit() {
    final r = Random();
    // 000000..999999 padded to 6 digits
    return (r.nextInt(1000000)).toString().padLeft(6, '0');
  }

  /// Generates a code and stores it in guardian_codes/{blindUid}.
  /// For demo simplicity, we don't guarantee global uniqueness; it's OK.
  Future<String> _createGuardianCodeForBlind(String blindUid) async {
    final code = _generate6Digit();
    await _db.collection('guardian_codes').doc(blindUid).set({
      'blindUid': blindUid,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true, // future-friendly if you want to rotate
    }, SetOptions(merge: true));
    return code;
  }

  /// Resolve a blindUid from a guardian code (for Guardian Mode UI).
  /// Returns the blindUid if found, else null.
  Future<String?> resolveBlindUidByGuardianCode(String inputCode) async {
    final q = await _db
        .collection('guardian_codes')
        .where('code', isEqualTo: inputCode)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return (q.docs.first.data()['blindUid'] as String?);
  }

  // ------------ signup ------------
  Future<String> signUpBlind({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? birthDate,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    try {
      // user profile
      await _db.collection('users').doc(uid).set({
        'role': 'blind',
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'birthDate': birthDate,
        'otcVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // persistent guardian pairing code in a separate collection
      final code = await _createGuardianCodeForBlind(uid);
      // (Optional) print/log for demo visibility:
      // print('👥 Guardian code for $uid is $code');
    } on FirebaseException catch (e) {
      throw Exception('Firestore write failed: ${e.code} ${e.message}');
    }

    return uid;
  }

  // ------------ sign in / out ------------
  Future<void> signInBlind({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  // Guardian bits (UI can call resolveBlindUidByGuardianCode and then navigate)
  Future<bool> verifyGuardianOneTimeCode(String code) async => true; // unused now
  bool get isGuardian => _currentUser?.role == UserRole.guardian;
  bool get guardianVerified => _currentUser?.otcVerified ?? false;
}
