// lib/services/auth_service.dart
import 'dart:async';

enum UserRole { blind, guardian }

class AppUser {
  final String uid;
  final UserRole role;
  AppUser(this.uid, this.role);
}

// Simple stub service for now. Swap with Firebase later.
class AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;                       // 👈 hold last value
  AppUser? get currentUser => _currentUser;    // 👈 sync getter

  Stream<AppUser?> get authStateChanges => _controller.stream;

  AuthService() {
    Future.microtask(() {
      _currentUser = null;
      _controller.add(null);
    });
  }

  void signInAsBlind() {
    _currentUser = AppUser('123', UserRole.blind);
    _controller.add(_currentUser);
  }

  void signInAsGuardian() {
    _currentUser = AppUser('456', UserRole.guardian);
    _controller.add(_currentUser);
  }

  void signOut() {
    _currentUser = null;
    _controller.add(null);
  }

  static final instance = AuthService();
}