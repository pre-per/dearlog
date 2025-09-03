import 'package:cloud_firestore/cloud_firestore.dart';
import '../../call/models/conversation/call.dart';

class CallRepository {
  final FirebaseFirestore firestore;
  CallRepository({required this.firestore});

  Future<List<Call>> fetchCalls(String userId) async {
    try {
      final snapshot = await firestore.collection('users/$userId/call').get();
      return snapshot.docs.map((doc) => Call.fromJson(doc.data())).toList();
    } catch (e, st) {
      print('🔥 fetchCalls error: $e\n$st');
      return [];
    }
  }

  Future<Call?> getCallById(String userId, String callId) async {
    try {
      final doc = await firestore.doc('users/$userId/call/$callId').get();
      if (!doc.exists) return null;
      return Call.fromJson(doc.data()!);
    } catch (e, st) {
      print('🔥 getCallById error: $e\n$st');
      return null;
    }
  }

  Future<void> saveCall(String userId, Call call) async {
    try {
      await firestore.doc('users/$userId/call/${call.callId}').set(call.toJson());
    } catch (e, st) {
      print('🔥 saveCall error: $e\n$st');
    }
  }

  Future<void> deleteCall(String userId, String callId) async {
    try {
      await firestore.doc('users/$userId/call/$callId').delete();
    } catch (e, st) {
      print('🔥 deleteCall error: $e\n$st');
    }
  }
}
