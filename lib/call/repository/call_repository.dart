import 'package:cloud_firestore/cloud_firestore.dart';
import '../../call/models/conversation/call.dart';

class CallRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Call>> fetchCalls(String userId) async {
    try {
      final snapshot = await _firestore.collection('users/$userId/call').get();
      return snapshot.docs.map((doc) => Call.fromJson(doc.data())).toList();
    } catch (e, st) {
      print('🔥 fetchCalls error: $e');
      print(st);
      return [];
    }
  }

  Future<void> saveCall(String userId, Call call) async {
    try {
      await _firestore.doc('users/$userId/call/${call.callId}').set(call.toJson());
    } catch (e, st) {
      print('🔥 saveCall error: $e');
      print(st);
    }
  }

  Future<void> deleteCall(String userId, String callId) async {
    try {
      await _firestore.doc('users/$userId/call/$callId').delete();
    } catch (e, st) {
      print('🔥 deleteCall error: $e');
      print(st);
    }
  }
}