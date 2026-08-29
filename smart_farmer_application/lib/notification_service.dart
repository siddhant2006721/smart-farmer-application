import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// NOTIFICATION MODEL
// ============================================================

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'weather', 'market', 'crop', 'disease', 'scheme', 'general'
  final DateTime createdAt;
  final bool isRead;
  final String? targetPage; // 'weather', 'market_prices', 'my_crops', 'government_schemes', 'farm_mitra'

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'general',
    required this.createdAt,
    this.isRead = false,
    this.targetPage,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return NotificationModel(
      id: doc.id,
      title: (data['title'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim(),
      type: (data['type'] ?? 'general').toString().trim().toLowerCase(),
      createdAt: parseDate(data['createdAt']),
      isRead: data['isRead'] == true,
      targetPage: (data['targetPage'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'targetPage': targetPage,
    };
  }
}

// ============================================================
// NOTIFICATION SERVICE (FIRESTORE REAL-TIME)
// ============================================================

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference _userNotifications(String userId) {
    return _firestore.collection('farmers').doc(userId).collection('notifications');
  }

  // ----------------------------------------------------------
  // STREAM ALL NOTIFICATIONS FOR USER
  // ----------------------------------------------------------
  static Stream<List<NotificationModel>> getNotificationsStream(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return _userNotifications(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ----------------------------------------------------------
  // STREAM UNREAD COUNT
  // ----------------------------------------------------------
  static Stream<int> getUnreadCountStream(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Stream.value(0);
    }

    return _userNotifications(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ----------------------------------------------------------
  // MARK NOTIFICATION AS READ
  // ----------------------------------------------------------
  static Future<void> markAsRead(String? userId, String notificationId) async {
    if (userId == null || userId.isEmpty || notificationId.isEmpty) return;

    try {
      await _userNotifications(userId).doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('NotificationService markAsRead error: $e');
    }
  }

  // ----------------------------------------------------------
  // MARK ALL AS READ
  // ----------------------------------------------------------
  static Future<void> markAllAsRead(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    try {
      final snapshot = await _userNotifications(userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService markAllAsRead error: $e');
    }
  }

  // ----------------------------------------------------------
  // DELETE NOTIFICATION
  // ----------------------------------------------------------
  static Future<void> deleteNotification(String? userId, String notificationId) async {
    if (userId == null || userId.isEmpty || notificationId.isEmpty) return;

    try {
      await _userNotifications(userId).doc(notificationId).delete();
    } catch (e) {
      debugPrint('NotificationService delete error: $e');
    }
  }

  // ----------------------------------------------------------
  // ADD NOTIFICATION
  // ----------------------------------------------------------
  static Future<void> addNotification(
    String userId, {
    required String title,
    required String message,
    String type = 'general',
    String? targetPage,
  }) async {
    try {
      await _userNotifications(userId).add({
        'title': title,
        'message': message,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetPage': targetPage,
      });
    } catch (e) {
      debugPrint('NotificationService add error: $e');
    }
  }

  /// Adds a notification only if [dedupeKey] has not already been stored
  /// for this farmer. Used so weather/market refreshes do not spam the inbox.
  static Future<void> addUniqueNotification(
    String userId, {
    required String title,
    required String message,
    String type = 'general',
    String? targetPage,
    required String dedupeKey,
  }) async {
    if (userId.isEmpty || dedupeKey.isEmpty) return;

    try {
      final existing = await _userNotifications(userId)
          .where('dedupeKey', isEqualTo: dedupeKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;

      await _userNotifications(userId).add({
        'title': title,
        'message': message,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'targetPage': targetPage,
        'dedupeKey': dedupeKey,
      });
    } catch (e) {
      debugPrint('NotificationService addUnique error: $e');
    }
  }
}
