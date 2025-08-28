// lib/services/auth_service.dart
import 'dart:async';
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

  // Ensure a user profile doc exists (auto-heal if signup write failed).
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

  // Map Firebase user -> AppUser by reading the user doc.
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

  /// Create a Firebase Auth user and a matching Firestore profile.
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
    print('🔥 Attempting Firestore write for $uid');

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

    print('✅ Firestore user profile written for $uid');
  } on FirebaseException catch (e) {
    print('❌ Firestore write failed: ${e.code} - ${e.message}');
    throw Exception('Firestore write failed: ${e.code} ${e.message}');
  }

  return uid;
}

  Future<void> signInBlind({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  // Guardian bits (stub until OTC is wired).
  Future<bool> verifyGuardianOneTimeCode(String code) async => true;
  bool get isGuardian => _currentUser?.role == UserRole.guardian;
  bool get guardianVerified => _currentUser?.otcVerified ?? false;
}
