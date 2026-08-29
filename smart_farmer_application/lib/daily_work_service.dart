import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyWorkItem {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String dateKey;
  final DateTime? createdAt;

  const DailyWorkItem({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.dateKey,
    this.createdAt,
  });

  factory DailyWorkItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseCreated(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return DailyWorkItem(
      id: doc.id,
      name: (data['name'] ?? '').toString().trim(),
      startTime: (data['startTime'] ?? '').toString().trim(),
      endTime: (data['endTime'] ?? '').toString().trim(),
      durationMinutes: (data['durationMinutes'] is num)
          ? (data['durationMinutes'] as num).toInt()
          : 0,
      dateKey: (data['dateKey'] ?? '').toString().trim(),
      createdAt: parseCreated(data['createdAt']),
    );
  }

  TimeOfDay? get startTimeOfDay => DailyWorkService.parseTime(startTime);
  TimeOfDay? get endTimeOfDay => DailyWorkService.parseTime(endTime);
}

class DailyWorkService {
  DailyWorkService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat displayDateFormat = DateFormat('d MMMM yyyy');
  static final DateFormat timeFormat = DateFormat('h:mm a');

  static CollectionReference<Map<String, dynamic>>? _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return collectionForUid(uid);
  }

  static CollectionReference<Map<String, dynamic>> collectionForUid(String uid) {
    return _firestore.collection('farmers').doc(uid).collection('daily_work');
  }

  static const List<String> nestedCollectionNames = [
    'items',
    'work_items',
    'workItems',
    'entries',
    'tasks',
    'work',
  ];

  static String dateKeyFor(DateTime date) => dateKeyFormat.format(date);

  static String formatDisplayDate(DateTime date) => displayDateFormat.format(date);

  static String formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return timeFormat.format(dt);
  }

  static TimeOfDay? parseTime(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    try {
      return TimeOfDay.fromDateTime(timeFormat.parse(raw));
    } catch (_) {}

    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')),
        );
      }
    } catch (_) {}
    return null;
  }

  static int durationMinutes(TimeOfDay start, TimeOfDay end) {
    final startMins = start.hour * 60 + start.minute;
    var endMins = end.hour * 60 + end.minute;
    if (endMins <= startMins) {
      endMins += 24 * 60;
    }
    return endMins - startMins;
  }

  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return hours == 1 ? '1h' : '${hours}h';
    return '${mins}m';
  }

  static String formatTotalDuration(int minutes) {
    if (minutes <= 0) return '0 minutes';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'} $mins min';
    }
    if (hours > 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$mins minutes';
  }

  static Stream<List<DailyWorkItem>> watchForDate(String dateKey) {
    final col = _collection();
    if (col == null) return Stream.value([]);

    return col.where('dateKey', isEqualTo: dateKey).snapshots().map((snapshot) {
      final items =
          snapshot.docs.map(DailyWorkItem.fromFirestore).toList();
      items.sort((a, b) {
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aCreated.compareTo(bCreated);
      });
      return items;
    });
  }

  static Future<void> saveWork({
    String? workId,
    required String name,
    required TimeOfDay start,
    required TimeOfDay end,
    required DateTime date,
  }) async {
    final col = _collection();
    if (col == null) {
      throw StateError('Please log in to save daily work.');
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'startTime': formatTimeOfDay(start),
      'endTime': formatTimeOfDay(end),
      'durationMinutes': durationMinutes(start, end),
      'dateKey': dateKeyFor(date),
    };

    if (workId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await col.add(data);
    } else {
      await col.doc(workId).update(data);
    }
  }

  static Future<void> deleteWork(String workId) async {
    final col = _collection();
    if (col == null || workId.isEmpty) return;
    try {
      await col.doc(workId).delete();
    } catch (e) {
      debugPrint('DailyWorkService delete error: $e');
      rethrow;
    }
  }

  /// Deletes every Daily Work document for [uid] only.
  /// Path: farmers/{uid}/daily_work/{docId} (and any nested subcollections).
  static Future<void> deleteAllForUid(String uid) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != uid || uid.isEmpty) {
      throw StateError('Daily Work deletion is limited to the signed-in user.');
    }

    final farmerRef = _firestore.collection('farmers').doc(uid);
    if (farmerRef.id != uid) {
      throw StateError('Refusing to delete Daily Work for a different user.');
    }

    // Current app path, plus a camelCase alias in case older writes used it.
    for (final name in const ['daily_work', 'dailyWork']) {
      await deleteCollectionRecursively(farmerRef.collection(name));
    }
  }

  static Future<void> deleteCollectionRecursively(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    const pageSize = 50;
    while (true) {
      final snapshot = await collection.limit(pageSize).get(
        const GetOptions(source: Source.server),
      );
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        await deleteDocumentRecursively(doc.reference);
      }
    }
  }

  static Future<void> deleteDocumentRecursively(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    for (final nested in nestedCollectionNames) {
      await deleteCollectionRecursively(docRef.collection(nested));
    }
    await docRef.delete();
  }

  static Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) {
        final lower = key.toLowerCase();
        return lower.contains('daily_work') ||
            lower.contains('dailywork') ||
            lower.contains('datekey') ||
            lower.contains('work_item') ||
            lower.contains('workitem');
      }).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('DailyWorkService local clear failed: $e');
    }
  }
}
