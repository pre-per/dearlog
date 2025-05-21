import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/conversation.dart';

class ConversationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveConversation(String userId, Conversation convo) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(convo.conversationId)
        .set(convo.toJson());
  }

  Future<List<Conversation>> fetchConversations(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => Conversation.fromJson(doc.data())).toList();
  }
}
