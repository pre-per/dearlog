# Dearlog 나의 행성 & Nova 구현 메모

## 배치
- 하단 탭바의 `마이` 탭에 배치합니다.
- `나의 행성`은 프로필성/성장형 기능으로 처리합니다.

## 렌더링 구조
1. 행성 기본 배경 또는 우주 배경
2. `planet_base`
3. `planet_rings`
4. `planet_stars`
5. `planet_clouds`
6. `planet_objects`
7. `nova_base_or_pose`
8. `nova_antenna`
9. `nova_bag`
10. `nova_prop`
11. UI 버튼/통계/공개 설정 오버레이

## Nova 커스터마이징 슬롯
- base: Nova 기본형
- pose: 기본/인사/떠있는 포즈
- face: 행복/졸림/신남/슬픔/하트
- antenna: 기본 별/반짝 별/꼬마 달/하트
- bag: 기본 가방/별 패치/달 장식/꿈 구름
- prop: 별 오브/별 지팡이/NOVA 인형/나의 다이어리

## 개발 참고
- 모든 Nova PNG는 투명 배경입니다.
- 앱에서는 `manifest.json`의 `file`, `slot`, `canvas_px`를 기준으로 불러오면 됩니다.
- 실제 구현 시 좌표는 화면 내 행성 중심점을 기준으로 scale 적용해 주세요.
