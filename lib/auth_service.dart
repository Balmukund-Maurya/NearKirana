import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_utils.dart';
import 'crash_reporting_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static FirebaseAuth? _customAuth;
  static FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;
  static void setAuth(FirebaseAuth mock) {
    _customAuth = mock;
  }

  User? get currentUser => auth.currentUser;
  String? get currentUid => auth.currentUser?.uid;
  bool get isAuthenticated => auth.currentUser != null;

  /// Ensures a Firebase Auth session exists.
  /// If the user is not signed in, signs in anonymously to establish request.auth.
  Future<User?> ensureAuthenticated() async {
    try {
      if (auth.currentUser != null) {
        return auth.currentUser;
      }
      final cred = await auth.signInAnonymously();
      debugPrint('AuthService: Signed in anonymously with UID: ${cred.user?.uid}');
      return cred.user;
    } catch (e) {
      debugPrint('AuthService error in ensureAuthenticated: $e');
      return null;
    }
  }

  /// Synchronizes user role, phone, and optional shopId into Firestore `users/{uid}`.
  /// This document is what Firestore Security Rules evaluate to enforce RBAC.
  Future<void> syncUserProfile({
    required String phone,
    required String role, // 'customer', 'shop_owner', 'super_admin'
    String? shopId,
    String? name,
  }) async {
    try {
      final user = await ensureAuthenticated();
      if (user == null) {
        debugPrint('AuthService: Unable to sync profile because no user is authenticated.');
        return;
      }

      String sanitizedPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (sanitizedPhone.length > 10) {
        sanitizedPhone = sanitizedPhone.substring(sanitizedPhone.length - 10);
      }

      final Map<String, dynamic> data = {
        'uid': user.uid,
        'phone': sanitizedPhone,
        'role': role,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (name != null && name.isNotEmpty) {
        data['name'] = name;
      }

      if (shopId != null && shopId.isNotEmpty) {
        data['shop_id'] = shopId;
      }

      final docRef = FirebaseUtils.firestore.collection('users').doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        data['created_at'] = FieldValue.serverTimestamp();
        await docRef.set(data);
      } else {
        await docRef.set(data, SetOptions(merge: true));
      }

      debugPrint('AuthService: Successfully synced user profile for $sanitizedPhone as $role');
      CrashReportingService().setUser(
        uid: user.uid,
        role: role,
        phone: sanitizedPhone,
        shopId: shopId,
      );
    } catch (e) {
      debugPrint('AuthService: Error syncing user profile: $e');
    }
  }

  /// Computes SHA-256 hash of a string
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  // Pre-computed SHA-256 hash of the administrative master PIN
  // (Prevents plaintext master PIN exposure in client code)
  static const String _defaultAdminPinHash =
      '937377f056160fc4b15e0b770c67136a5f03c15205b4d3bf918268fefa2c6d0a';

  /// Verifies Super Admin PIN using cryptographic hash
  Future<bool> verifySuperAdminPin(String pin) async {
    if (pin.trim().isEmpty) return false;
    final hashed = hashPin(pin);

    // 1. Check if a dynamic hash is configured in Firestore super_admins/_config
    try {
      final doc = await FirebaseUtils.firestore
          .collection('super_admins')
          .doc('_config')
          .get();
      if (doc.exists && doc.data()?['pin_hash'] != null) {
        return doc.data()!['pin_hash'] == hashed;
      }
    } catch (_) {}

    // 2. Compare against default cryptographic hash
    return hashed == _defaultAdminPinHash;
  }

  /// Checks if current session is an authorized super admin
  Future<bool> isSuperAdmin() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      final adminDoc = await FirebaseUtils.firestore
          .collection('super_admins')
          .doc(user.uid)
          .get();
      if (adminDoc.exists) return true;

      final userDoc = await FirebaseUtils.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data()?['role'] == 'super_admin';
    } catch (e) {
      debugPrint('AuthService: Error checking super_admin: $e');
      return false;
    }
  }

  /// Elevates session to Super Admin after verified Super Admin login
  Future<void> elevateToSuperAdmin() async {
    try {
      final user = await ensureAuthenticated();
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('global_phone') ?? '';

      // Update users collection
      await FirebaseUtils.firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        if (phone.isNotEmpty) 'phone': phone,
        'role': 'super_admin',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also register in super_admins collection
      await FirebaseUtils.firestore.collection('super_admins').doc(user.uid).set({
        'uid': user.uid,
        if (phone.isNotEmpty) 'phone': phone,
        'granted_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('AuthService: Elevated UID ${user.uid} to super_admin');
    } catch (e) {
      debugPrint('AuthService: Error elevating to super_admin: $e');
    }
  }

  /// Clear session
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Error signing out: $e');
    }
  }
}
