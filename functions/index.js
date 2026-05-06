/**
 * Cloud Functions for dearlog.
 *
 * 현재 트리거:
 * - notifyOnNewComment: 누군가 공개 게시물에 댓글을 달면 게시물 작성자에게 FCM 푸시.
 *
 * 1st gen (v1) 트리거를 사용 — Spark(무료) 플랜에서도 배포 가능.
 * (2nd gen 으로 마이그레이션하면 Blaze 플랜이 필요하다.)
 *
 * 배포: 프로젝트 루트에서
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

// firebase-functions 5.x: v1 트리거는 명시적으로 /v1 에서 import (backward-compatible).
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

exports.notifyOnNewComment = functions
  .region('us-central1')
  .firestore
  .document('community_posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const comment = snap.data() || {};
    const { postId } = context.params;

    const db = admin.firestore();

    // 1) 게시물 조회
    const postRef = db.doc(`community_posts/${postId}`);
    const postSnap = await postRef.get();
    if (!postSnap.exists) {
      console.info(`post ${postId} not found, skip`);
      return;
    }
    const post = postSnap.data() || {};

    // 본인이 자기 글에 단 댓글이면 알림 보내지 않는다.
    if (!post.authorUid) return;
    if (post.authorUid === comment.authorUid) return;

    // 2) 게시물 작성자 정보 조회
    const authorSnap = await db.doc(`users/${post.authorUid}`).get();
    if (!authorSnap.exists) {
      console.info(`author ${post.authorUid} not found, skip`);
      return;
    }
    const authorData = authorSnap.data() || {};

    // 3) 알림 메시지 구성 (inbox + push 양쪽에서 사용)
    const senderName = comment.isAnonymous
      ? '익명'
      : (comment.authorNicknameSnapshot || '익명');
    const rawBody = (comment.content || '').toString();
    const body = rawBody.length > 80 ? `${rawBody.slice(0, 80)}…` : rawBody;
    const postTitle = (post.title || '').toString().trim();
    const titleSuffix = postTitle.length > 0
      ? ` ('${postTitle.length > 20 ? `${postTitle.slice(0, 20)}…` : postTitle}')`
      : '';
    const notifTitle = `${senderName} 님이 댓글을 남겼어요${titleSuffix}`;
    const payloadKey = `comment:${postId}`;

    // 4) 알림 보관함(Firestore) 적재 — 푸시 토글/토큰 상태와 무관하게 항상 기록.
    //    토글 OFF 사용자도 보관함에서 인앱으로 확인할 수 있게.
    try {
      const inboxRef = db
        .collection(`users/${post.authorUid}/notifications`)
        .doc();
      await inboxRef.set({
        id: inboxRef.id,
        type: 'comment',
        title: notifTitle,
        body,
        payload: payloadKey,
        postId,
        postTitle: postTitle || null,
        senderName,
        isAnonymous: !!comment.isAnonymous,
        commentId: snap.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
      });
    } catch (e) {
      console.error('inbox write failed', e);
    }

    // 5) 푸시 게이트 — 토글 OFF or 토큰 없음이면 여기서 종료.
    if (authorData.commentNotifEnabled === false) {
      console.info(`author ${post.authorUid} disabled comment notifications, skip push`);
      return;
    }
    const token = authorData.fcmToken;
    if (!token) {
      console.info(`author ${post.authorUid} has no fcmToken, skip push`);
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: notifTitle,
          body,
        },
        data: {
          // 클라이언트 NotificationPayload 와 매칭됨 — main.dart 의 핸들러가 사용.
          payload: payloadKey,
          postId,
        },
        android: {
          priority: 'high',
          notification: {
            // 클라이언트 LocalNotificationService.communityChannelId 와 동일해야 함.
            channelId: 'dearlog_community',
          },
        },
        apns: {
          payload: { aps: { sound: 'default' } },
        },
      });
      console.info(`pushed comment notif → ${post.authorUid}`);
    } catch (e) {
      // 토큰이 만료되었거나 등록 해제된 경우 — 다음 로그인에 자동 갱신되니 정리만 시도.
      const code = e && e.errorInfo && e.errorInfo.code;
      if (code === 'messaging/registration-token-not-registered'
          || code === 'messaging/invalid-registration-token') {
        try {
          await db.doc(`users/${post.authorUid}`).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        } catch (_) { /* swallow */ }
      }
      console.error('FCM send failed', e);
    }
  });
