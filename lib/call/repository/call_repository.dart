import 'package:cloud_firestore/cloud_firestore.dart';
import '../../call/models/conversation/call.dart';

/// Firestore 의 통화 기록 컬렉션 접근.
///
/// 정책: 실패 시 print + 빈 값 반환 같은 silent swallow 를 하지 않는다.
/// 호출자가 try/catch 로 처리하고 사용자에게 적절히 surface 하도록 한다.
class CallRepository {
  final FirebaseFirestore firestore;
  CallRepository({required this.firestore});

  Future<List<Call>> fetchCalls(String userId, {int limit = 50}) async {
    final snapshot = await firestore
        .collection('users/$userId/call')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => Call.fromJson(doc.data())).toList();
  }

  Future<Call?> getCallById(String userId, String callId) async {
    final doc = await firestore.doc('users/$userId/call/$callId').get();
    if (!doc.exists) return null;
    return Call.fromJson(doc.data()!);
  }

  Future<void> saveCall(String userId, Call call) async {
    await firestore.doc('users/$userId/call/${call.callId}').set(call.toJson());
  }

  Future<void> deleteCall(String userId, String callId) async {
    await firestore.doc('users/$userId/call/$callId').delete();
  }
}
