# Nova 살아있는 캐릭터 — Rive 작업 가이드

목표: 마이페이지(나의 행성)의 Nova를 정적 PNG 합성에서 **살아 움직이는 Rive 캐릭터**로 전환.
현재 렌더: `lib/planet/widgets/nova_view.dart` → `layered_image_stack.dart` (정적 PNG 레이어 합성).

작업 분담:
- **디자이너/유저**: Rive 에디터에서 `.riv` 제작 (이 문서 = 그 작업 명세).
- **개발(Claude)**: `.riv`를 Flutter에 연결, 앱 상태(다이어리 감정/탭/TTS)와 input 바인딩.

---

## 0. 핵심 개념 (1분)

- `.riv` = 아트보드 + 이미지 + 애니메이션 + **상태머신(State Machine)**이 들어간 단일 파일. 작고(보통 수십 KB) 벡터/메시 기반이라 60fps.
- Flutter는 `rive` 패키지로 `.riv`를 로드하고 **input 값만 바꿔서** 캐릭터를 조종. (이 연결 코드는 개발이 담당)
- **input = 우리 사이의 계약.** 아래 4번의 input 이름/타입만 정확히 지켜주면, 그 안의 애니메이션을 어떻게 만들든 자유.
- PNG만 있어도 됨: Rive의 **Mesh + Bone**으로 평면 이미지를 변형. 분리된 레이어(표정 등)는 상태로 토글.

---

## 1. 준비할 자료 (파츠 리스트)

대부분 **이미 있음**. 풀캔버스(같은 1254² 캔버스에 제 위치로 그려진 투명 PNG)라서 Rive에 드래그하면 자동 정렬됩니다.

| 파츠 | 용도 | 상태 | 파일 |
|---|---|---|---|
| 몸(base) | 호흡/둥둥/스쿼시의 본체 | ✅ 있음 | `04_nova/nova_base.png` 또는 v2 `nova/base/*.png`, `nova/poses/*` |
| 표정 5종 | mood별 얼굴 (켜고/끄기) | ✅ 있음 | v2 `nova/expressions/expression_{happy,excited,heart,sad,sleepy}.png` |
| 손 | 탭 시 흔들기/제스처 | ✅ 있음 | `04_nova/hand_*.png` |
| 안테나 | 부차적 흔들림(생동감) | ✅ 있음 | `04_nova/antenna_*.png` |
| 의상/가방 | 꾸미기 연동(후순위) | ✅ 있음 | `04_nova/outfit_*.png`, `bag_*.png` |
| **눈 감은 표정** | 자연스러운 깜빡임 | ⬜ 선택 | 표정당 눈만 감은 버전 1장 (없으면 "눈 영역 Y축 눌림" 트릭으로 대체 가능) |
| **입 모양 2~3종** | 통화화면 TTS 말하기 | ⬜ 선택 | neutral/half/open (말하기 연출 원할 때만) |

**v1은 ⬜ 없이도 됩니다.** ✅ 항목만으로 호흡 + 둥둥 + 표정전환 + 탭반응 + (트릭)깜빡임까지 가능.

---

## 2. Rive 문서 구조 (에디터에서 만들 것)

```
Artboard "Nova"  (1000 x 1000, 정사각)
├─ Body        (nova_base / pose)    ← Mesh + Bone로 호흡·스쿼시
│   └─ Bone: Root(상하 bob) → Spine(좌우 sway)
├─ Face (group)                      ← mood로 하나만 visible
│   ├─ happy / excited / heart / sad / sleepy
├─ Hand_L / Hand_R                   ← 탭 시 회전(웨이브)  [선택]
├─ Antenna                           ← idle 중 살짝 흔들림  [선택]
└─ (Mouth)                           ← talking 시 루프      [선택]
```

타임라인(애니메이션) 4개:
- `idle` : 2~3초 루프. Body Y 위치 sine(둥둥) + 약한 scale 스쿼시(호흡) + 안테나 살짝.
- `blink`: ~0.15초. 눈 영역 Y로 눌렀다 펴기(또는 eyes-closed 레이어 토글). idle 안에서 주기적 자동 재생.
- `tap_react`: ~0.5초. 통통 튀고(스쿼시&스트레치) 손 흔들기 + 표정 잠깐 happy/heart.
- (선택) `talk`: 입 모양 루프.

---

## 3. 단계별 작업 순서 (Rive 에디터)

1. https://rive.app → 무료 가입 → **New File**.
2. Artboard 크기 **1000×1000**(정사각, 현재 캔버스 비율과 동일).
3. PNG 드래그 임포트: **base를 맨 아래**, 그 위에 표정 1개, 손/안테나. (풀캔버스라 위치 자동 정렬)
4. Body에 **Mesh** 추가 → 정점 찍고 → **Bone**(Root/Spine) 생성 → 정점에 weight 바인딩. (둥둥·호흡·sway용)
5. 표정들을 같은 위치에 겹쳐 **그룹 "Face"**. 기본은 happy만 visible.
6. 위 **타임라인 4개** 제작(`idle`/`blink`/`tap_react`/(talk)).
7. **State Machine 생성** → 이름 `NovaStateMachine` → 아래 4번의 input 추가 → 전이 연결:
   - Entry → `idle` (기본, 루프)
   - `mood`(Number) 값 → 해당 표정 visible 전환
   - `tap`(Trigger) → `tap_react` 재생 후 idle 복귀
   - `talking`(Boolean) true → `talk` 루프
   - `blink`은 idle 내부에서 자동(별도 input 불필요)
8. **Export → Download → Runtime (.riv)** 선택 → 파일명 `nova.riv`.

---

## 4. 개발과의 계약 (이 이름들 정확히)

`.riv` 내부에 아래를 **정확한 철자/타입**으로 만들어 주세요. 이게 Flutter 연결의 유일한 전제입니다.

- 파일 위치: 레포에 `asset/rive/nova.riv`
- Artboard 이름: `Nova`
- State Machine 이름: `NovaStateMachine`
- Inputs:
  | 이름 | 타입 | 값/의미 |
  |---|---|---|
  | `mood` | Number | 0 neutral · 1 happy · 2 excited · 3 heart · 4 sad · 5 sleepy |
  | `tap` | Trigger | 사용자가 Nova를 탭하면 발동(반응 연출) |
  | `talking` | Boolean | 통화화면 TTS 재생 중 true (말하기) — 후순위, 없어도 됨 |

> input 이름을 바꾸고 싶으면 바꿔도 됩니다. **최종 이름만 알려주세요.** 개발이 거기에 맞춥니다.

개발이 자동 연동할 앱 데이터:
- `mood` ← 최근 다이어리 감정 요약(`planet_emotion_summary.dart`)
- `tap` ← 마이페이지에서 Nova 탭
- `talking` ← 통화화면 TTS 재생 상태

---

## 5. 범위: v1(최소) vs v2(확장)

- **v1 (권장 시작, 새 아트 0):** base + 기존 표정 5종. → 둥둥/호흡/표정전환/탭 스쿼시 + 트릭 깜빡임.
- **v2:** 눈 감은 표정(진짜 깜빡임) + 분리된 팔(진짜 웨이브) + 입 모양(TTS 말하기).

먼저 v1 `.riv`만 넘겨주셔도 앱에 붙여서 "살아있는 Nova"를 바로 확인할 수 있습니다.

---

## 6. 넘겨줄 것 체크리스트

- [ ] `asset/rive/nova.riv`
- [ ] (제안과 다르면) Artboard / State Machine / input 최종 이름
- [ ] 실제로 리깅한 mood 목록 (예: happy/sad만 했으면 그렇게)
- [ ] (선택) 통화화면 talking 포함 여부
