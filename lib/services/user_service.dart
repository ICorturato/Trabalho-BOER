import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../model/user_model.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Coleção principal
  CollectionReference get _usersRef => _firestore.collection('users');

  Future<void> createUser({
    required UserModel user,
    required String password,
  }) async {
    // Cria a conta no Firebase Auth
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: user.email,
      password: password,
    );

    String? uid = credential.user?.uid;

    if (uid != null) {
      // Cria o documento no Firestore com o mesmo ID (UID) do Auth
      await _usersRef.doc(uid).set(user.toMap());
    }
  }

  Future<UserModel?> getCurrentUserProfile() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    DocumentSnapshot doc = await _usersRef.doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Stream<UserModel?> streamUserProfile() {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _usersRef.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  Future<void> updateUserProfile({
    required String phone,
  }) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("Usuário não autenticado");

    await _usersRef.doc(uid).update({
      'phone': phone,
      'updatedAt': DateTime.now(),
    });
  }

  Future<void> updatePassword(String password) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Usuário não autenticado");

    await currentUser.updatePassword(password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Remove o documento do Firestore
    await _usersRef.doc(currentUser.uid).delete();

    // Remove a conta de acesso do Firebase Auth
    await currentUser.delete();
  }
}
