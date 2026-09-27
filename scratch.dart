import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

void main() {
  final words = ["test", "admin", "12345", "123456", "password", "000000", "NearKirana", "kirana", "shop", "999999"];
  for (String w in words) {
    final bytes = utf8.encode(w);
    final digest = sha256.convert(bytes);
    if (digest.toString().startsWith("8104727f04")) {
      debugPrint("Found! The PIN is: $w");
      return;
    }
  }
  debugPrint("Not found in common words");
}
