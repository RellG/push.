import 'package:cloud_firestore/cloud_firestore.dart';

/// The Firestore references owned by a single signed-in user.
///
/// Layout: `users/{uid}` holds the profile document, with `days` (keyed by
/// the `yyyy-MM-dd` local date) and `sets` (auto-id) subcollections.
class UserFirestore {
  const UserFirestore(this.firestore, this.uid);

  final FirebaseFirestore firestore;

  final String uid;

  DocumentReference<Map<String, dynamic>> get profileDoc =>
      firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get days =>
      profileDoc.collection('days');

  CollectionReference<Map<String, dynamic>> get sets =>
      profileDoc.collection('sets');
}
