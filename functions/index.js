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

/**
 * 커뮤니티 일일 알림 (하루 한 번 "누가 게시글을 공유했어요").
 *
 * 사용자별로 알림 시간(HH:MM, KST 기준)을 user doc 의
 * `dailyCommunityNotifSlot` (= hour*60 + minute) 에 저장한다.
 * 이 cron 은 5분마다 돌면서 현재 KST 슬롯에 해당하는(±5분 윈도우) 사용자들을
 * 찾아 최근 24시간 내 새 게시물 1개를 골라 FCM 으로 발송한다.
 *
 * 멱등성: user doc 의 `dailyCommunityLastSentSlot` (YYYYMMDDHHMM 의 정수) 가
 * 오늘 이 슬롯에 이미 보냈는지 확인 — 한 번 보내면 같은 날 같은 슬롯에 다시
 * 보내지 않는다 (cron 이 중첩 실행돼도 안전).
 *
 * 한국 사용자 중심 서비스라 KST(UTC+9) 로 고정 — 글로벌 확장 시 user.tz 추가 필요.
 *
 * 필요한 Firestore 복합 인덱스 (firestore.indexes.json):
 *   users: dailyCommunityNotifEnabled ASC, dailyCommunityNotifSlot ASC
 *   community_posts: createdAt DESC
 */
exports.dailyCommunityRecap = functions
  .region('us-central1')
  .pubsub
  .schedule('every 5 minutes')
  .timeZone('Asia/Seoul')
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();
    // KST 시각 직접 계산 — timeZone 옵션은 cron 트리거 시점만 KST 로 해석하고,
    // Date 객체는 UTC 라 슬롯 매칭은 우리가 KST 로 보정해야 한다.
    const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const kstHour = kstNow.getUTCHours();
    const kstMin = kstNow.getUTCMinutes();
    const currentSlot = kstHour * 60 + kstMin;
    const windowStart = currentSlot;
    // 5분 cron + 약간의 지연 여유. 익일 자정 경계는 신경 안 써도 됨 — 23:55~23:59
    // 슬롯은 다음 cron 인 00:00 KST 에는 이미 지나가 있으므로 자연 만료.
    const windowEnd = currentSlot + 5;

    // 오늘 슬롯 토큰 (멱등성 키). YYYYMMDD * 10000 + slot.
    const ymd =
      kstNow.getUTCFullYear() * 10000 +
      (kstNow.getUTCMonth() + 1) * 100 +
      kstNow.getUTCDate();
    const slotToken = ymd * 10000 + currentSlot;

    // 1) 후보 사용자 — 이 슬롯에 알림 받기로 한 사람들
    let usersSnap;
    try {
      usersSnap = await db
        .collection('users')
        .where('dailyCommunityNotifEnabled', '==', true)
        .where('dailyCommunityNotifSlot', '>=', windowStart)
        .where('dailyCommunityNotifSlot', '<', windowEnd)
        .get();
    } catch (e) {
      console.error('[dailyCommunityRecap] user query failed', e);
      return;
    }
    if (usersSnap.empty) {
      console.info(`[dailyCommunityRecap] no users in slot ${currentSlot}`);
      return;
    }

    // 2) 최근 24h 게시물 목록 — 사용자마다 다른 게시물을 보내려고 5개 정도 캐싱.
    //    본인 게시물은 제외해서 매번 새로 필터링한다.
    const since = admin.firestore.Timestamp.fromMillis(
      now.getTime() - 24 * 60 * 60 * 1000,
    );
    let postsSnap;
    try {
      postsSnap = await db
        .collection('community_posts')
        .where('createdAt', '>=', since)
        .orderBy('createdAt', 'desc')
        .limit(20)
        .get();
    } catch (e) {
      console.error('[dailyCommunityRecap] posts query failed', e);
      return;
    }
    const recentPosts = postsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    if (recentPosts.length === 0) {
      console.info('[dailyCommunityRecap] no recent posts, skip');
      return;
    }

    // 3) 사용자별 발송
    let sent = 0;
    let skipped = 0;
    await Promise.all(
      usersSnap.docs.map(async (userDoc) => {
        const uid = userDoc.id;
        const user = userDoc.data() || {};

        // 멱등성: 같은 슬롯에 이미 보냈는지 확인.
        if (user.dailyCommunityLastSentSlot === slotToken) {
          skipped++;
          return;
        }

        // 본인 글이 아닌 가장 최신 게시물 1개 선택.
        const pick = recentPosts.find((p) => p.authorUid !== uid);
        if (!pick) {
          skipped++;
          return;
        }

        const senderName = pick.isAnonymous
          ? '누군가'
          : (pick.authorNicknameSnapshot || '누군가');
        const rawTitle = (pick.title || '').toString().trim();
        const rawContent = (pick.content || '').toString().trim();
        const preview = (rawTitle.length > 0 ? rawTitle : rawContent)
          .replace(/\s+/g, ' ')
          .trim();
        const previewShort = preview.length > 60
          ? `${preview.slice(0, 60)}…`
          : preview;
        const notifTitle = `${senderName} 님이 새 게시글을 공유했어요`;
        const notifBody = previewShort.length > 0
          ? previewShort
          : '커뮤니티에서 확인해 보세요';
        const payloadKey = `comment:${pick.id}`; // 게시물 상세로 라우팅 (기존 핸들러 재사용)

        // inbox 적재 — 푸시 토글/토큰 상태와 무관하게 항상 기록.
        try {
          const inboxRef = db.collection(`users/${uid}/notifications`).doc();
          await inboxRef.set({
            id: inboxRef.id,
            type: 'community_recap',
            title: notifTitle,
            body: notifBody,
            payload: payloadKey,
            postId: pick.id,
            postTitle: rawTitle || null,
            senderName,
            isAnonymous: !!pick.isAnonymous,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          });
        } catch (e) {
          console.error(`[dailyCommunityRecap] inbox write failed for ${uid}`, e);
        }

        // 슬롯 토큰 갱신 — 푸시 실패해도 같은 슬롯 중복 발송은 방지.
        try {
          await userDoc.ref.update({
            dailyCommunityLastSentSlot: slotToken,
          });
        } catch (_) {/* 멱등성 보조 — 실패해도 다음 cron 에서 다시 시도 */}

        const token = user.fcmToken;
        if (!token) {
          skipped++;
          return;
        }

        try {
          await admin.messaging().send({
            token,
            notification: { title: notifTitle, body: notifBody },
            data: { payload: payloadKey, postId: pick.id },
            android: {
              priority: 'high',
              notification: { channelId: 'dearlog_community' },
            },
            apns: { payload: { aps: { sound: 'default' } } },
          });
          sent++;
        } catch (e) {
          const code = e && e.errorInfo && e.errorInfo.code;
          if (code === 'messaging/registration-token-not-registered'
              || code === 'messaging/invalid-registration-token') {
            try {
              await userDoc.ref.update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
            } catch (_) { /* swallow */ }
          }
          console.error(`[dailyCommunityRecap] FCM send failed for ${uid}`, e);
        }
      }),
    );

    console.info(
      `[dailyCommunityRecap] slot=${currentSlot} candidates=${usersSnap.size} sent=${sent} skipped=${skipped}`,
    );
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

// ─────────────────────────────────────────────────────────────────────────
// 랭킹 시스템 — user_stats/{uid} 자동 갱신
// ─────────────────────────────────────────────────────────────────────────
//
// 일기 doc(`users/{uid}/diaries/{diaryId}`) 의 create/update/delete 마다 트리거되어
// 다음 통계를 다시 계산해서 `user_stats/{uid}` 에 set 한다:
//   - diaryCount: 작성된 일기들의 KST 자정 기준 고유 날짜 수
//   - currentStreak: 가장 최근 일기일을 기준으로 한 연속 일수 (유예 1일 허용)
//   - longestStreak: 역대 최장 연속 일수
//   - lastDiaryDate: 가장 최근 일기일 (KST 자정)
//
// 일기 doc 의 `date` 필드는 평문 ISO8601 문자열로 저장되므로 (KMS 암호화 대상이 아님)
// 함수에서 별도 복호화 없이 즉시 읽을 수 있다.
//
// 유예 규칙: 한 줄의 스트릭 안에서 1일짜리 갭을 단 한 번만 허용. 두 번 이상 빠지거나
// 한 번에 2일 이상 빠지면 그 지점에서 끊긴다.

/// KST(UTC+9) 자정 기준의 'YYYY-MM-DD' 문자열을 뽑는다.
/// 사용자가 동일 날짜에 여러 일기를 써도 같은 키로 묶여 dedup 된다.
function _toKstDayKey(isoOrDate) {
  let ms;
  if (isoOrDate instanceof Date) {
    ms = isoOrDate.getTime();
  } else if (typeof isoOrDate === 'string') {
    const hasTz = /Z$|[+-]\d{2}:?\d{2}$/.test(isoOrDate);
    if (hasTz) {
      ms = new Date(isoOrDate).getTime();
    } else {
      // 타임존 명시가 없으면 클라이언트(주로 KST)의 wall time 으로 간주.
      // 즉, isoOrDate 의 'YYYY-MM-DD' 부분이 곧 사용자 기준 작성 날짜.
      return isoOrDate.slice(0, 10);
    }
  } else {
    return null;
  }
  if (Number.isNaN(ms)) return null;
  const kst = new Date(ms + 9 * 3600 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, '0');
  const d = String(kst.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/// 'YYYY-MM-DD' 문자열을 해당 KST 자정의 UTC ms 로 변환.
function _dayKeyToMs(key) {
  const [y, m, d] = key.split('-').map(Number);
  // KST 자정 = UTC 자정 − 9시간
  return Date.UTC(y, m - 1, d) - 9 * 3600 * 1000;
}

function _diffDays(aMs, bMs) {
  return Math.round((aMs - bMs) / 86400000);
}

/// 오름차순 정렬된 day key 배열에서 유예 1일 허용 하에 최장 연속 길이를 구한다.
function _longestStreakAsc(keysAsc) {
  if (keysAsc.length === 0) return 0;
  let longest = 1;
  let current = 1;
  let graceUsed = false;
  let prevMs = _dayKeyToMs(keysAsc[0]);
  for (let i = 1; i < keysAsc.length; i++) {
    const curMs = _dayKeyToMs(keysAsc[i]);
    const gap = _diffDays(curMs, prevMs) - 1;
    if (gap === 0) {
      current += 1;
    } else if (gap === 1 && !graceUsed) {
      graceUsed = true;
      current += 1;
    } else {
      current = 1;
      graceUsed = false;
    }
    if (current > longest) longest = current;
    prevMs = curMs;
  }
  return longest;
}

/// 가장 최근 day 부터 역행하면서 유예 1일 허용 하에 연속 길이를 구한다.
/// 가장 최근 day 가 오늘에서 2일 이상 지났으면 0 (스트릭 끊김).
function _currentStreakFromDesc(keysDesc, todayMs) {
  if (keysDesc.length === 0) return 0;
  const latestMs = _dayKeyToMs(keysDesc[0]);
  const sinceLatest = _diffDays(todayMs, latestMs);
  if (sinceLatest > 1) return 0;
  let streak = 1;
  let graceUsed = false;
  let prevMs = latestMs;
  for (let i = 1; i < keysDesc.length; i++) {
    const curMs = _dayKeyToMs(keysDesc[i]);
    const gap = _diffDays(prevMs, curMs) - 1;
    if (gap === 0) {
      streak += 1;
      prevMs = curMs;
    } else if (gap === 1 && !graceUsed) {
      graceUsed = true;
      streak += 1;
      prevMs = curMs;
    } else {
      break;
    }
  }
  return streak;
}

/// 사용자의 전체 일기 컬렉션을 스캔해서 user_stats 를 다시 계산하고 저장한다.
/// onWrite 트리거와 백필 callable 모두에서 재사용.
async function _recomputeUserStats(db, userId) {
  const diariesSnap = await db.collection(`users/${userId}/diaries`).get();
  const dayKeys = new Set();
  diariesSnap.forEach((d) => {
    const data = d.data() || {};
    const key = _toKstDayKey(data.date);
    if (key) dayKeys.add(key);
  });

  const statsRef = db.doc(`user_stats/${userId}`);
  const existingSnap = await statsRef.get();
  const existing = existingSnap.exists ? existingSnap.data() || {} : {};
  const prevLongest = Number(existing.longestStreak || 0);

  if (dayKeys.size === 0) {
    // 모든 일기가 지워진 상태 — 통계 비움. longestStreak 도 더 이상 의미 없으므로 0 으로.
    await statsRef.set({
      diaryCount: 0,
      currentStreak: 0,
      longestStreak: 0,
      lastDiaryDate: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { diaryCount: 0, currentStreak: 0, longestStreak: 0 };
  }

  const keysDesc = Array.from(dayKeys).sort().reverse();
  const keysAsc = [...keysDesc].slice().reverse();

  const todayKey = _toKstDayKey(new Date());
  const todayMs = _dayKeyToMs(todayKey);

  const currentStreak = _currentStreakFromDesc(keysDesc, todayMs);
  const longestThisRun = _longestStreakAsc(keysAsc);
  const longestStreak = Math.max(prevLongest, longestThisRun, currentStreak);

  const latestKey = keysDesc[0];
  const latestMs = _dayKeyToMs(latestKey);

  await statsRef.set({
    diaryCount: dayKeys.size,
    currentStreak,
    longestStreak,
    lastDiaryDate: admin.firestore.Timestamp.fromMillis(latestMs),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {
    diaryCount: dayKeys.size,
    currentStreak,
    longestStreak,
  };
}

exports.recomputeUserStatsOnDiaryWrite = functions
  .region('us-central1')
  .firestore
  .document('users/{userId}/diaries/{diaryId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    try {
      const result = await _recomputeUserStats(admin.firestore(), userId);
      console.info(
        `[user_stats] uid=${userId} count=${result.diaryCount} streak=${result.currentStreak} longest=${result.longestStreak}`,
      );
    } catch (e) {
      console.error(`[user_stats] recompute failed uid=${userId}`, e);
    }
  });

/// 모든 사용자의 user_stats 를 일기 컬렉션 기준으로 1회 재계산.
///
/// 호출 권한:
///   functions config 에 등록된 `admin.uids` 화이트리스트의 사용자만 호출 가능.
///     firebase functions:config:set admin.uids="<uid1>,<uid2>"
///
/// 멱등성: 일기 데이터를 변형하지 않고 user_stats 만 덮어쓰므로 여러 번 실행해도 안전.
/// 대규모 사용자 처리에 대비해 50명씩 끊어서 순차 처리(메모리/타임아웃 안정).
/// 디버그 전용 — 호출한 사용자의 user_stats 를 임의 값으로 덮어쓴다.
///
/// 랭크 배지/스트릭 글로우/축하 연출 UI 를 빠르게 검증하려고 만든 도구.
/// 호출자는 admin.uids 화이트리스트에 등록된 사용자여야 한다.
///
/// 동작:
///   - diaryCount, currentStreak 를 클램프(>= 0) 후 그대로 set.
///   - longestStreak 는 max(기존, currentStreak) 로 자동 보정.
///   - lastDiaryDate 는 오늘(KST 자정) 으로 — 그래야 클라이언트 liveCurrentStreak
///     보정이 0 으로 떨어뜨리지 않는다.
///
/// 주의: 실제 일기를 작성/삭제하면 onWrite 트리거가 user_stats 를 실제 데이터로
/// 다시 덮어쓴다. 디버그 값은 그때까지만 유지된다 — 정상 동작.
exports.debugSetUserStats = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    const uid = _requireAuth(context);
    const allow = (functions.config().admin && functions.config().admin.uids) || '';
    const adminUids = allow.split(',').map((s) => s.trim()).filter(Boolean);
    if (!adminUids.includes(uid)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        '디버그 권한이 없어요.',
      );
    }

    const rawCount = Number(data && data.diaryCount);
    const rawStreak = Number(data && data.currentStreak);
    if (!Number.isFinite(rawCount) || !Number.isFinite(rawStreak)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'diaryCount, currentStreak (숫자) 가 필요해요.',
      );
    }
    const diaryCount = Math.max(0, Math.floor(rawCount));
    const currentStreak = Math.max(0, Math.floor(rawStreak));

    const db = admin.firestore();
    const statsRef = db.doc(`user_stats/${uid}`);
    const existingSnap = await statsRef.get();
    const existing = existingSnap.exists ? existingSnap.data() || {} : {};
    const longestStreak = Math.max(
      Number(existing.longestStreak || 0),
      currentStreak,
    );

    // 오늘(KST) 자정 — liveCurrentStreak 가 살아있게.
    const todayKey = _toKstDayKey(new Date());
    const lastDiaryDateMs = currentStreak > 0
      ? _dayKeyToMs(todayKey)
      : null;

    await statsRef.set({
      diaryCount,
      currentStreak,
      longestStreak,
      lastDiaryDate: lastDiaryDateMs == null
        ? null
        : admin.firestore.Timestamp.fromMillis(lastDiaryDateMs),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { diaryCount, currentStreak, longestStreak };
  });

exports.backfillAllUserStats = functions
  .region('us-central1')
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .https.onCall(async (data, context) => {
    const uid = _requireAuth(context);
    const allow = (functions.config().admin && functions.config().admin.uids) || '';
    const adminUids = allow.split(',').map((s) => s.trim()).filter(Boolean);
    if (!adminUids.includes(uid)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        '백필 권한이 없어요. admin.uids 화이트리스트를 확인하세요.',
      );
    }

    const db = admin.firestore();
    const usersSnap = await db.collection('users').get();
    const totalUsers = usersSnap.size;

    let processed = 0;
    let failed = 0;
    const batchSize = 50;
    const docs = usersSnap.docs;

    for (let i = 0; i < docs.length; i += batchSize) {
      const slice = docs.slice(i, i + batchSize);
      await Promise.all(
        slice.map(async (userDoc) => {
          try {
            await _recomputeUserStats(db, userDoc.id);
            processed += 1;
          } catch (e) {
            failed += 1;
            console.error(`[backfill] uid=${userDoc.id} failed`, e);
          }
        }),
      );
    }

    console.info(
      `[backfill] done totalUsers=${totalUsers} processed=${processed} failed=${failed}`,
    );
    return { totalUsers, processed, failed };
  });
