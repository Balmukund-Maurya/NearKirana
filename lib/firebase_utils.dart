import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseUtils {
  static FirebaseFirestore? _customFirestore;
  static FirebaseAuth? _customAuth;
  
  static FirebaseFirestore get firestore {
    return _customFirestore ?? FirebaseFirestore.instance;
  }
  
  static void setFirestore(FirebaseFirestore mock) {
    _customFirestore = mock;
  }

  static FirebaseAuth get auth {
    return _customAuth ?? FirebaseAuth.instance;
  }

  static void setAuth(FirebaseAuth mock) {
    _customAuth = mock;
  }
}
