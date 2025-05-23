import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/match/match.dart';

class MatchRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Match>> fetchMatches(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('matches')
        .orderBy('matchScore', descending: true)
        .get();

    return snapshot.docs.map((doc) => Match.fromJson(doc.data())).toList();
  }

  Future<void> saveMatch(String userId, Match match) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('matches')
        .doc(match.matchId)
        .set(match.toJson());
  }
}
