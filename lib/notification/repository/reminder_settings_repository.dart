import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_reminder_settings.dart';

class ReminderSettingsRepository {
  final FirebaseFirestore _db;
  ReminderSettingsRepository(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid)
          .collection('notification_settings').doc('daily_diary_reminder');

  Future<DiaryReminderSettings?> getSettings(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return DiaryReminderSettings.fromJson(snap.data()!);
  }

  Future<void> upsertSettings(String uid, DiaryReminderSettings settings) async {
    await _doc(uid).set(settings.toJson(), SetOptions(merge: true));
  }
}
