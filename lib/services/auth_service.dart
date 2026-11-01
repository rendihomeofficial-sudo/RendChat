import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Service autentikasi RenChat.
///
/// Seluruh alur masuk/daftar memakai akun Google. Form email/password
/// sudah dihapus sepenuhnya agar tidak ada akun lama yang tersisa.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Client ID Web (OAuth 2.0) dari project Firebase.
  static const String _webClientId =
      '1062003220328-evnrsoocba1h9gm98eccgrv89gagv9b2.apps.googleusercontent.com';

  /// Server client ID (Web application type) dipakai untuk bertukar idToken
  /// menjadi kredensial Firebase di platform Android/iOS.
  static const String _serverClientId =
      '1062003220328-evnrsoocba1h9gm98eccgrv89gagv9b2.apps.googleusercontent.com';

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = true;
  bool _googleReady = false;

  AuthService() {
    _initGoogle();
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _initGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? _webClientId : null,
        serverClientId: kIsWeb ? null : _serverClientId,
      );
      _googleReady = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal menginisialisasi Google Sign-In: $e');
    }
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _firebaseUser != null;
  String? get currentUid => _firebaseUser?.uid;

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      await _syncUserToFirestore(user);
      await _fetchAppUser(user.uid);
    } else {
      _appUser = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _syncUserToFirestore(User user) async {
    final userRef = _firestore
        .collection('users')
        .doc(user.uid)
        .withConverter<AppUser>(
          fromFirestore: AppUser.fromFirestore,
          toFirestore: (u, _) => u.toFirestore(),
        );

    try {
      final snap = await userRef.get();
      final defaultName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'User');

      if (!snap.exists) {
        final newUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: defaultName,
          photoURL: user.photoURL,
          statusMessage: 'Hey there! I am using Messenger.',
          online: true,
          lastSeen: DateTime.now(),
          fcmTokens: const [],
          createdAt: DateTime.now(),
        );
        await userRef.set(newUser);
      } else {
        final existing = snap.data();
        await userRef.update({
          'online': true,
          'lastSeen': Timestamp.now(),
          if (existing?.displayName == null || existing!.displayName.isEmpty || existing.displayName == 'User')
            if (user.displayName != null && user.displayName!.trim().isNotEmpty)
              'displayName': user.displayName!.trim(),
          if (existing?.photoURL == null || existing!.photoURL!.isEmpty)
            if (user.photoURL != null && user.photoURL!.isNotEmpty)
              'photoURL': user.photoURL,
        });
      }
    } catch (e) {
      debugPrint('Gagal sinkronkan profil ke Firestore: $e');
    }
  }

  Future<void> _fetchAppUser(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .withConverter<AppUser>(
            fromFirestore: AppUser.fromFirestore,
            toFirestore: (u, _) => u.toFirestore(),
          )
          .get();

      if (snap.exists) {
        _appUser = snap.data();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Gagal memuat profil pengguna: $e');
    }
  }

  /// Masuk / daftar dengan akun Google.
  ///
  /// Mengembalikan `null` bila pengguna membatalkan dialog.
  Future<UserCredential?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          _firebaseUser = userCredential.user;
          await _syncUserToFirestore(userCredential.user!);
          await _fetchAppUser(userCredential.user!.uid);
        }
        return userCredential;
      }

      if (!_googleReady) {
        await _initGoogle();
      }

      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled ||
            e.code == GoogleSignInExceptionCode.interrupted) {
          debugPrint('Pengguna membatalkan login Google: ${e.code}');
          return null;
        }
        rethrow;
      }

      final GoogleSignInAuthentication auth = googleUser.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Gagal memperoleh token autentikasi Google. Silakan coba lagi.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _firebaseUser = userCredential.user;
        await _syncUserToFirestore(userCredential.user!);
        await _fetchAppUser(userCredential.user!.uid);
      }
      return userCredential;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_firebaseUser != null) {
      try {
        await _firestore.collection('users').doc(_firebaseUser!.uid).update({
          'online': false,
          'lastSeen': Timestamp.now(),
        });
      } catch (_) {
        // Abaikan: dokumen mungkin sudah tidak ada / rules menolak.
      }
    }
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? displayName,
    String? statusMessage,
    String? photoURL,
  }) async {
    if (_firebaseUser == null) return;
    final Map<String, dynamic> updates = {};
    if (displayName != null) {
      updates['displayName'] = displayName.trim();
      await _firebaseUser!.updateDisplayName(displayName.trim());
    }
    if (statusMessage != null) updates['statusMessage'] = statusMessage.trim();
    if (photoURL != null) {
      updates['photoURL'] = photoURL;
      await _firebaseUser!.updatePhotoURL(photoURL);
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updates);
      await _fetchAppUser(_firebaseUser!.uid);
    }
  }

  /// Menghapus akun pengguna sepenuhnya secara nyata dari Firestore & Firebase Auth
  Future<void> deleteAccount() async {
    final user = _firebaseUser;
    if (user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Hapus dokumen profil pengguna di Firestore
      await _firestore.collection('users').doc(user.uid).delete();
    } catch (e) {
      debugPrint('Gagal menghapus dokumen pengguna di Firestore: $e');
    }

    try {
      // 2. Putuskan Google Sign-In
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}

    try {
      // 3. Hapus akun Firebase Auth
      await user.delete();
    } catch (e) {
      debugPrint('Gagal menghapus user di Firebase Auth: $e');
      // Jika butuh re-autentikasi, logout agar aman
      await _auth.signOut();
    }

    _firebaseUser = null;
    _appUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
