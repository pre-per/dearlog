import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/my_planet.dart';

/// `users/{uid}` 문서의 `planet` 필드 read/write.
///
/// 행성 설정은 화장 정보라 본인 문서에 평문으로 둔다(보안 규칙상 본인 문서는
/// 자유 read/write). 커뮤니티 방문(타인 행성 read)은 별도 공개 read 규칙이
/// 필요하므로 다음 단계에서 다룬다.
class PlanetRepository {
  final FirebaseFirestore firestore;

  PlanetRepository({required this.firestore});

  /// 내 행성 실시간 구독. 아직 만들지 않았으면 null emit.
  Stream<MyPlanet?> watchMyPlanet(String uid) {
    return firestore.doc('users/$uid').snapshots().map((snap) {
      final raw = snap.data()?['planet'];
      if (raw is Map<String, dynamic>) return MyPlanet.fromJson(raw);
      return null;
    });
  }

  /// 1회 조회.
  Future<MyPlanet?> fetchMyPlanet(String uid) async {
    final snap = await firestore.doc('users/$uid').get();
    final raw = snap.data()?['planet'];
    if (raw is Map<String, dynamic>) return MyPlanet.fromJson(raw);
    return null;
  }

  /// 행성 설정 저장. `planet` 필드만 merge 로 갱신(다른 사용자 필드 보존).
  Future<void> saveMyPlanet(String uid, MyPlanet planet) {
    return firestore.doc('users/$uid').set({
      'planet': planet.toJson(),
    }, SetOptions(merge: true));
  }
}
