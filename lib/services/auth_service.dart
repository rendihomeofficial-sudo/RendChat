import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn(
      clientId: kIsWeb ? '1062003220328-evnrsoocba1h9gm98eccgrv89gagv9b2.apps.googleusercontent.com' : null,
      serverClientId: '1062003220328-evnrsoocba1h9gm98eccgrv89gagv9b2.apps.googleusercontent.com',
      scopes: [
        'email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ],
    );
    return _googleSignIn!;
  }

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = true;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
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

    final snap = await userRef.get();
    if (!snap.exists) {
      final newUser = AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? (user.email?.split('@').first ?? 'User'),
        photoURL: user.photoURL,
        statusMessage: 'Hey there! I am using Messenger.',
        online: true,
        lastSeen: DateTime.now(),
        fcmTokens: const [],
        createdAt: DateTime.now(),
      );
      await userRef.set(newUser);
    } else {
      await userRef.update({
        'online': true,
        'lastSeen': Timestamp.now(),
      });
    }
  }

  Future<void> _fetchAppUser(String uid) async {
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
  }

  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserCredential> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(displayName.trim());
        await _syncUserToFirestore(cred.user!);
      }
      return cred;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        return await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignInInstance.signIn();
        if (googleUser == null) {
          return null; // user cancelled
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _syncUserToFirestore(userCredential.user!);
        }
        return userCredential;
      }
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
      } catch (_) {}
    }
    if (!kIsWeb) {
      await _googleSignInInstance.signOut();
    }
    await _auth.signOut();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? statusMessage, String? photoURL}) async {
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
}
