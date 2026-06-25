import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:dearlog/diary/models/diary_entry.dart';

import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../models/community_report.dart';
import '../models/nlp_filter_snapshot.dart';

/// 커뮤니티 피드를 페이지 단위로 가져온 결과.
class CommunityFeedPage {
  final List<CommunityPost> posts;

  /// 다음 페이지 요청 시 `startAfter` 로 넘길 마지막 문서 스냅샷. 더 없으면 null.
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  /// 받은 페이지가 가득 찼는지 여부 (false 면 더 로드해도 빈 결과).
  final bool hasMore;

  const CommunityFeedPage({
    required this.posts,
    required this.lastDoc,
    required this.hasMore,
  });

  static const empty = CommunityFeedPage(
    posts: [],
    lastDoc: null,
    hasMore: false,
  );
}

/// 커뮤니티 게시물/댓글/좋아요/신고를 다루는 단일 진입점.
///
/// 보안 규칙은 `firestore.rules` 에 정의돼 있으며, 이 클래스는 그 규칙이
/// 허용하는 동작만 수행한다 (예: 좋아요는 `userId` 가 곧 문서 id, 게시물 삭제는
/// 작성자만 등).
class CommunityRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  // ===== Collection refs =====

  CollectionReference<Map<String, dynamic>> _postsCol() =>
      firestore.collection('community_posts');

  DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _postsCol().doc(postId);

  CollectionReference<Map<String, dynamic>> _commentsCol(String postId) =>
      _postRef(postId).collection('comments');

  CollectionReference<Map<String, dynamic>> _likesCol(String postId) =>
      _postRef(postId).collection('likes');

  CollectionReference<Map<String, dynamic>> _reportsCol() =>
      firestore.collection('community_reports');

  // ===== Posts =====

  /// 일기를 커뮤니티에 공개한다.
  ///
  /// - 이미지를 `community_posts/{postId}/image_*.png` 로 복사해서 원본과 분리
  /// - 닉네임은 게시 시점 값으로 동결 저장
  /// - `override*` 가 주어지면 그 값으로 덮어쓴다 (사용자가 미리보기에서 다듬거나
  ///   특정 정보를 제외하기로 선택한 경우)
  ///
  /// 호출자는 이 메서드를 부르기 전에 [findPostByDiaryId] 로 같은 일기가 이미
  /// 공개돼 있지 않은지 확인해야 한다 (1 일기 = 1 게시물 정책).
  Future<CommunityPost> publishDiary({
    required String authorUid,
    required String authorNickname,
    required bool isAnonymous,
    required DiaryEntry diary,
    String? overrideTitle,
    String? overrideContent,
    String? overrideEmotion,
    List<String>? overrideImageSources,
    DateTime? overrideDiaryDate,
    List<NlpFilterSnapshot> nlpFilters = const [],
    bool showRankIfAnonymous = false,
  }) async {
    final postRef = _postsCol().doc();
    final postId = postRef.id;

    final sources = overrideImageSources ?? diary.imageUrls;
    final List<String> copiedUrls = [];
    for (int i = 0; i < sources.length; i++) {
      final src = sources[i];
      try {
        final newUrl = await _copyImageToCommunity(
          sourceUrl: src,
          postId: postId,
          index: i,
        );
        copiedUrls.add(newUrl);
      } catch (e) {
        // 이미지 한 장 실패가 게시 자체를 막지 않게 한다. 실패한 건 그냥 빠짐.
        // ignore: avoid_print
        debugPrint('[publishDiary] image copy failed ($src): $e');
      }
    }

    final post = CommunityPost(
      id: postId,
      authorUid: authorUid,
      authorNicknameSnapshot: authorNickname,
      isAnonymous: isAnonymous,
      originalDiaryId: diary.id,
      title: overrideTitle ?? diary.title,
      content: overrideContent ?? diary.content,
      emotion: overrideEmotion ?? diary.emotion,
      imageUrls: copiedUrls,
      diaryDate: overrideDiaryDate ?? diary.date,
      createdAt: DateTime.now(),
      nlpFilters: nlpFilters,
      showRankIfAnonymous: showRankIfAnonymous,
    );

    await postRef.set(post.toJson());
    return post;
  }

  Future<String> _copyImageToCommunity({
    required String sourceUrl,
    required String postId,
    required int index,
  }) async {
    final res = await http.get(Uri.parse(sourceUrl));
    if (res.statusCode != 200) {
      throw Exception('image download failed: ${res.statusCode}');
    }
    final Uint8List bytes = res.bodyBytes;

    final ref = storage.ref('community_posts/$postId/image_$index.png');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public,max-age=31536000',
      ),
    );
    return await ref.getDownloadURL();
  }

  /// 일기 없이 커뮤니티에 직접 작성하는 게시물 — 이미지 첨부 X (v1).
  ///
  /// `originalDiaryId` 가 빈 문자열이면 standalone 으로 간주한다 ([CommunityPost.isFromDiary]).
  Future<CommunityPost> createStandalonePost({
    required String authorUid,
    required String authorNickname,
    required bool isAnonymous,
    required String title,
    required String content,
    required String emotion,
    bool showRankIfAnonymous = false,
  }) async {
    final postRef = _postsCol().doc();
    final now = DateTime.now();
    final post = CommunityPost(
      id: postRef.id,
      authorUid: authorUid,
      authorNicknameSnapshot: authorNickname,
      isAnonymous: isAnonymous,
      originalDiaryId: '', // standalone — 일기 출신 아님
      title: title,
      content: content,
      emotion: emotion,
      imageUrls: const [],
      diaryDate: now, // 일기 없음 — 게시 시각으로 대체
      createdAt: now,
      showRankIfAnonymous: showRankIfAnonymous,
    );
    await postRef.set(post.toJson());
    return post;
  }

  /// 게시물 본문 수정 (작성자 본인만 — 보안 규칙이 강제).
  /// `title/content/emotion/isAnonymous` 만 변경 허용.
  /// (`authorUid/originalDiaryId/createdAt` 등 식별 필드는 rules 가 거부)
  Future<void> editPost({
    required String postId,
    String? title,
    String? content,
    String? emotion,
    bool? isAnonymous,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (emotion != null) updates['emotion'] = emotion;
    if (isAnonymous != null) updates['isAnonymous'] = isAnonymous;
    if (updates.isEmpty) return;
    await _postRef(postId).update(updates);
  }

  /// 게시물 내림 (작성자만).
  ///
  /// 서브컬렉션은 자동 삭제되지 않으므로 순서대로 정리한다:
  ///   1) 좋아요 모두 삭제 (게시물 작성자 권한으로)
  ///   2) 댓글 모두 삭제
  ///   3) 스토리지 이미지 삭제
  ///   4) 마지막에 게시물 문서 삭제 (이전에 삭제하면 위 단계의 권한 체크가 깨진다)
  Future<void> takeDownPost(String postId) async {
    // 1) likes
    try {
      final likes = await _likesCol(postId).get();
      for (final doc in likes.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
    } catch (_) {}

    // 2) comments
    try {
      final comments = await _commentsCol(postId).get();
      for (final doc in comments.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
    } catch (_) {}

    // 3) storage images
    try {
      final folder = storage.ref('community_posts/$postId');
      final list = await folder.listAll();
      for (final item in list.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (_) {}

    // 4) post doc
    await _postRef(postId).delete();
  }

  /// 최신순 피드. 페이지 단위 (기본 20개).
  /// [emotions] 가 비어있지 않으면 그 감정들 중 하나에 해당하는 게시물만 필터링.
  /// (예: '슬픔' 그룹이면 ['슬픔','외로움','우울'] 식으로 호출)
  Future<CommunityFeedPage> fetchFeed({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    List<String>? emotions,
  }) async {
    Query<Map<String, dynamic>> q = _postsCol();
    if (emotions != null && emotions.isNotEmpty) {
      if (emotions.length == 1) {
        q = q.where('emotion', isEqualTo: emotions.first);
      } else {
        // Firestore whereIn 은 최대 30개. 우리 그룹은 한 그룹당 ≤ 3개라 충분.
        q = q.where('emotion', whereIn: emotions);
      }
    }
    q = q.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final posts =
        snap.docs.map((d) => CommunityPost.fromJson(d.data())).toList();
    return CommunityFeedPage(
      posts: posts,
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  /// 단일 게시물 라이브 구독 (좋아요/댓글 카운트 변화 감지).
  Stream<CommunityPost?> watchPost(String postId) {
    return _postRef(postId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CommunityPost.fromJson(snap.data()!);
    });
  }

  /// 특정 일기에 대해 이미 공개된 게시물이 있는지 조회.
  /// 같은 일기는 한 번에 하나의 공개 게시물만 가질 수 있다.
  Future<CommunityPost?> findPostByDiaryId({
    required String authorUid,
    required String diaryId,
  }) async {
    final snap = await _postsCol()
        .where('authorUid', isEqualTo: authorUid)
        .where('originalDiaryId', isEqualTo: diaryId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CommunityPost.fromJson(snap.docs.first.data());
  }

  /// 특정 사용자가 게시한 글 목록 (마이페이지용).
  Stream<List<CommunityPost>> watchUserPosts(String authorUid) {
    return _postsCol()
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CommunityPost.fromJson(d.data())).toList());
  }

  // ===== Comments =====

  /// 새 댓글/답글 생성.
  ///
  /// [parentCommentId] 가 주어지면 그 댓글에 달리는 1단계 답글이다.
  /// [parentNicknameSnapshot] 은 답글 카드에서 "@xxx" 멘션을 보여주기 위해
  /// 게시 시점의 부모 닉네임을 함께 동결 저장한다 (부모가 익명이면 '익명').
  ///
  /// 답글도 게시물의 commentCount 에 포함된다 (총 소통량 관점).
  Future<CommunityComment> addComment({
    required String postId,
    required String authorUid,
    required String authorNickname,
    required bool isAnonymous,
    required String content,
    String? parentCommentId,
    String? parentNicknameSnapshot,
    bool showRankIfAnonymous = false,
  }) async {
    final ref = _commentsCol(postId).doc();
    final comment = CommunityComment(
      id: ref.id,
      postId: postId,
      authorUid: authorUid,
      authorNicknameSnapshot: authorNickname,
      isAnonymous: isAnonymous,
      content: content,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
      parentNicknameSnapshot: parentNicknameSnapshot,
      showRankIfAnonymous: showRankIfAnonymous,
    );

    final batch = firestore.batch();
    batch.set(ref, comment.toJson());
    batch.update(_postRef(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();

    return comment;
  }

  Future<void> editComment({
    required String postId,
    required String commentId,
    required String newContent,
  }) async {
    await _commentsCol(postId).doc(commentId).update({
      'content': newContent,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final batch = firestore.batch();
    batch.delete(_commentsCol(postId).doc(commentId));
    batch.update(_postRef(postId), {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  /// 게시물의 모든 댓글 라이브 구독. 최신순.
  Stream<List<CommunityComment>> watchComments(String postId) {
    return _commentsCol(postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommunityComment.fromJson(d.data()))
            .toList());
  }

  // ===== Likes =====

  /// 좋아요 토글. 이미 눌렀으면 취소, 아니면 누른다.
  ///
  /// 좋아요 문서 id 를 [userId] 로 두기 때문에 한 사용자는 한 게시물에 단 하나의
  /// 좋아요만 가진다 — 이중 호출이 들어와도 정합성이 유지된다.
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final likeRef = _likesCol(postId).doc(userId);
    final snap = await likeRef.get();

    final batch = firestore.batch();
    if (snap.exists) {
      batch.delete(likeRef);
      batch.update(_postRef(postId), {
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      batch.set(likeRef, {
        'userId': userId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      batch.update(_postRef(postId), {
        'likeCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  /// 현재 사용자가 이 게시물을 좋아요 했는지 라이브 구독.
  Stream<bool> watchLikedByMe({
    required String postId,
    required String userId,
  }) {
    return _likesCol(postId).doc(userId).snapshots().map((s) => s.exists);
  }

  // ===== Reports =====

  Future<void> reportPost({
    required String postId,
    required String reporterUid,
    required String reason,
  }) async {
    final ref = _reportsCol().doc();
    final report = CommunityReport(
      id: ref.id,
      reporterUid: reporterUid,
      targetType: ReportTargetType.post,
      targetId: postId,
      postId: postId,
      reason: reason,
      createdAt: DateTime.now(),
    );

    final batch = firestore.batch();
    batch.set(ref, report.toJson());
    batch.update(_postRef(postId), {
      'reportCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reporterUid,
    required String reason,
  }) async {
    final ref = _reportsCol().doc();
    final report = CommunityReport(
      id: ref.id,
      reporterUid: reporterUid,
      targetType: ReportTargetType.comment,
      targetId: commentId,
      postId: postId,
      reason: reason,
      createdAt: DateTime.now(),
    );
    await ref.set(report.toJson());
  }
}
