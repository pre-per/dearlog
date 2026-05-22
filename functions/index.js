/**
 * Cloud Functions for dearlog.
 *
 * 현재 트리거:
 * - notifyOnNewComment: 누군가 공개 게시물에 댓글을 달면 게시물 작성자에게 FCM 푸시.
 * - wrapDek / unwrapDek / unwrapDeks: 일기·편지·통화 본문의 KMS envelope 암호화 wrap/unwrap.
 *   사용자별 UID 를 AAD(Additional Authenticated Data) 로 묶어 다른 사용자의
 *   wrappedDek 으로는 절대 unwrap 되지 않게 한다.
 *
 * 1st gen (v1) 트리거를 사용. KMS API 호출은 Blaze 플랜 필요.
 *
 * 배포: 프로젝트 루트에서
 *   cd functions && npm install
 *   firebase deploy --only functions
 *
 * KMS 키 사전 준비 (한 번만):
 *   gcloud kms keyrings create dearlog --location global
 *   gcloud kms keys create user-content-key \
 *     --location global --keyring dearlog --purpose encryption
 *   # Functions 의 default service account 에 권한 부여
 *   gcloud kms keys add-iam-policy-binding user-content-key \
 *     --location global --keyring dearlog \
 *     --member "serviceAccount:${GCP_PROJECT}@appspot.gserviceaccount.com" \
 *     --role roles/cloudkms.cryptoKeyEncrypterDecrypter
 */

// firebase-functions 5.x: v1 트리거는 명시적으로 /v1 에서 import (backward-compatible).
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { KeyManagementServiceClient } = require('@google-cloud/kms');

admin.initializeApp();

// ── KMS 설정 ──
//
// 키 경로는 환경별로 다를 수 있어 functions.config() 에서 override 가능.
// override 가 없으면 기본 'global / dearlog / user-content-key' 사용.
//   firebase functions:config:set kms.keyring="dearlog" kms.key="user-content-key" kms.location="global"
const KMS_LOCATION =
  (functions.config().kms && functions.config().kms.location) || 'global';
const KMS_KEYRING =
  (functions.config().kms && functions.config().kms.keyring) || 'dearlog';
const KMS_KEY =
  (functions.config().kms && functions.config().kms.key) || 'user-content-key';

// 싱글톤 클라이언트 — 콜드스타트 비용을 한 번만 치름.
const kmsClient = new KeyManagementServiceClient();

function _kmsKeyName() {
  const projectId =
    admin.app().options.projectId || process.env.GCLOUD_PROJECT;
  if (!projectId) {
    throw new Error('GCLOUD_PROJECT not set — KMS path 결정 불가');
  }
  return kmsClient.cryptoKeyPath(
    projectId,
    KMS_LOCATION,
    KMS_KEYRING,
    KMS_KEY,
  );
}

/// b64 → Buffer / Buffer → b64 헬퍼.
function _b64ToBuf(b64) {
  if (typeof b64 !== 'string' || b64.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'base64 문자열이 필요해요',
    );
  }
  return Buffer.from(b64, 'base64');
}

function _bufToB64(buf) {
  return Buffer.from(buf).toString('base64');
}

/// 사용자 인증 + uid 확보. AAD 로 사용해 다른 사용자 DEK 를 unwrap 못 하게 함.
function _requireAuth(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '로그인이 필요해요',
    );
  }
  return context.auth.uid;
}

exports.wrapDek = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    const uid = _requireAuth(context);
    const dek = _b64ToBuf(data && data.dek);
    if (dek.length !== 32) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'DEK 는 32 bytes(AES-256) 이어야 해요',
      );
    }
    try {
      const [resp] = await kmsClient.encrypt({
        name: _kmsKeyName(),
        plaintext: dek,
        additionalAuthenticatedData: Buffer.from(uid, 'utf8'),
      });
      return { wrappedDek: _bufToB64(resp.ciphertext) };
    } catch (err) {
      console.error('[KMS] wrap 실패', err);
      throw new functions.https.HttpsError(
        'internal',
        '암호화 키 처리에 실패했어요',
      );
    }
  });

exports.unwrapDek = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    const uid = _requireAuth(context);
    const wrapped = _b64ToBuf(data && data.wrappedDek);
    try {
      const [resp] = await kmsClient.decrypt({
        name: _kmsKeyName(),
        ciphertext: wrapped,
        additionalAuthenticatedData: Buffer.from(uid, 'utf8'),
      });
      // KMS 가 평문 DEK 를 그대로 돌려준다 — caller(클라이언트) 가 즉시 메모리에서만 사용 후 폐기해야 함.
      return { dek: _bufToB64(resp.plaintext) };
    } catch (err) {
      console.error('[KMS] unwrap 실패', err);
      throw new functions.https.HttpsError(
        'permission-denied',
        '복호화 권한이 없거나 데이터가 손상됐어요',
      );
    }
  });

/// 다이어리 목록처럼 한 번에 여러 doc 을 읽을 때 KMS 호출을 병렬로 묶어준다.
/// 입력 순서대로 deks 배열을 반환. 일부가 실패하면 errors[i] 에 메시지가 들어간다.
exports.unwrapDeks = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    const uid = _requireAuth(context);
    const inputs = (data && data.wrappedDeks) || [];
    if (!Array.isArray(inputs)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'wrappedDeks 는 배열이어야 해요',
      );
    }
    const keyName = _kmsKeyName();
    const aad = Buffer.from(uid, 'utf8');

    const results = await Promise.all(
      inputs.map(async (b64) => {
        try {
          const [resp] = await kmsClient.decrypt({
            name: keyName,
            ciphertext: _b64ToBuf(b64),
            additionalAuthenticatedData: aad,
          });
          return { dek: _bufToB64(resp.plaintext) };
        } catch (err) {
          console.error('[KMS] batch unwrap 일부 실패', err);
          return { dek: null, error: err.message || 'unwrap failed' };
        }
      }),
    );
    return { results };
  });

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
