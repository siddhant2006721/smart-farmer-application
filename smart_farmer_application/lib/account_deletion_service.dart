import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_work_service.dart';
import 'market_price_service.dart';

class AccountDeletionCancelled implements Exception {}

/// Permanently deletes the signed-in farmer's data and Firebase Auth account.
/// Only touches `farmers/{currentUid}` and local storage for this device.
class AccountDeletionService {
  AccountDeletionService._();

  static bool inProgress = false;

  static const List<String> _farmerSubcollections = [
    'crops',
    'daily_work',
    'dailyWork',
    'notifications',
    'farm_mitra_chats',
    'farm_health',
    'disease_detections',
  ];

  static Future<void> deleteCurrentAccount({
    required Future<String?> Function() requestPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user',
      );
    }

    final uid = user.uid;
    if (uid.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Missing user id',
      );
    }

    inProgress = true;

    try {
      await _deleteFarmerFirestoreData(uid);
      await DailyWorkService.deleteAllForUid(uid);
      await _verifyDailyWorkDeleted(uid);
      await _clearLocalData();
      await _deleteAuthAccount(user, requestPassword);

      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      inProgress = false;
      rethrow;
    }
  }

  static Future<void> _deleteFarmerFirestoreData(String uid) async {
    final farmerRef =
        FirebaseFirestore.instance.collection('farmers').doc(uid);

    if (farmerRef.id != uid) {
      throw StateError('Refusing to delete data for a different user.');
    }

    for (final name in _farmerSubcollections) {
      await DailyWorkService.deleteCollectionRecursively(
        farmerRef.collection(name),
      );
    }

    final farmerSnap = await farmerRef.get(
      const GetOptions(source: Source.server),
    );
    if (farmerSnap.exists) {
      await DailyWorkService.deleteDocumentRecursively(farmerRef);
    }
  }

  static Future<void> _verifyDailyWorkDeleted(String uid) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final remaining = await DailyWorkService.collectionForUid(uid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (remaining.docs.isEmpty) return;

      if (kDebugMode) {
        debugPrint(
          'Daily Work still present at farmers/$uid/daily_work '
          '(attempt ${attempt + 1})',
        );
      }
      await DailyWorkService.deleteAllForUid(uid);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'daily-work-delete-failed',
      message: 'Unable to delete Daily Work data. Please try again.',
    );
  }

  static Future<void> _deleteAuthAccount(
    User user,
    Future<String?> Function() requestPassword,
  ) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }

      final password = await requestPassword();
      if (password == null || password.isEmpty) {
        throw AccountDeletionCancelled();
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Missing email for re-authentication',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await user.delete();
    }
  }

  static Future<void> _clearLocalData() async {
    try {
      await DailyWorkService.clearLocalData();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Daily Work local clear failed: $e');
      }
    }

    try {
      MarketPriceService.clearMemoryCache();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Memory cache clear failed: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SharedPreferences clear failed: $e');
      }
      rethrow;
    }
  }
}
