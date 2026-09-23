import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseUtils {
  static FirebaseFirestore? _customFirestore;
  
  static FirebaseFirestore get firestore {
    if (_customFirestore == null) {
      print("WARNING: _customFirestore is null! Falling back to instance.");
    } else {
      print("SUCCESS: _customFirestore is not null! Returning fake.");
    }
    return _customFirestore ?? FirebaseFirestore.instance;
  }
  
  static void setFirestore(FirebaseFirestore mock) {
    print("setFirestore called!");
    _customFirestore = mock;
  }
}
