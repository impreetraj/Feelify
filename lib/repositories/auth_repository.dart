import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel> signUp({required String email, required String password}) async {
    try {
      final UserCredential credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
      
     
      final username = email.split('@')[0];

      final userModel = UserModel(
        uid: user.uid,
        email: email,
        username: username,
      );

    
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      
      return userModel;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserModel> signIn({required String email, required String password}) async {
    try {
      final UserCredential credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
    
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception("User data not found in Firestore.");
      }
      
      final userModel = UserModel.fromMap(doc.data()!);

      return userModel;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserModel> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: '245812861960-jfdrbqtmm7snq2lihffe6dqdlr70i77b.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        throw Exception("Google sign in aborted");
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user!;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      UserModel userModel;

      if (!doc.exists || doc.data() == null) {
        final username = user.email?.split('@')[0] ?? 'user_${user.uid.substring(0, 5)}';
        userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          username: username,
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      } else {
        userModel = UserModel.fromMap(doc.data()!);
      }

      return userModel;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid');
    final email = prefs.getString('user_email');
    final username = prefs.getString('user_name');

    if (uid != null && email != null && username != null) {
      return UserModel(uid: uid, email: email, username: username);
    }
    return null;
  }

  Future<void> saveUserLocal(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_uid', user.uid);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_name', user.username);
  }
}
