import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';

class FirebaseUtils {
  static FirebaseFirestore? _customFirestore;
  
  static FirebaseFirestore get firestore {
    return _customFirestore ?? FirebaseFirestore.instance;
  }
  
  static void setFirestore(FirebaseFirestore mock) {
    _customFirestore = mock;
  }
}
