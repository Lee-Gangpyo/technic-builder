# Catalog part icons — P1 스펙 (Catalog Art)

Interface가 카탈로그 버튼에 붙일 에셋·색 계약. **`scripts/ui`는 Interface 소유 — 본 문서는 에셋/경로만.**

## 경로
```
res://assets/catalog/parts/{id}.png
```
- 해상도: **128×128** PNG, 불투명
- 배경: `#F5F7FA` (밝은 HUD 카드)
- id = `data/parts/*.json` 의 `id`와 동일

## 10종 팔레트 (JSON `color` 확정)

| id | KO | color | 실루엣 힌트 |
|----|-----|-------|-------------|
| `beam_5` | 리프트암 5홀 | `#E8B923` | 가로 암 + 원형 홀 5 |
| `beam_7` | 리프트암 7홀 | `#E8B923` | 가로 암 + 원형 홀 7 |
| `axle_5` | 액슬 5M | `#C0C0C0` | +단면 샤프트 · 팁 챔퍼 |
| `pin` | 커넥터 핀 | `#1E90FF` | 로브+스토퍼 링 |
| `bush` | 부싱 | `#333333` | 플랜지 + 보어/+ |
| `gear_8` | 스퍼 8T | `#888888` | 작은 톱니 · 허브 |
| `gear_16` | 스퍼 16T | `#888888` | 중형 톱니 · 허브 |
| `gear_24` | 스퍼 24T | `#888888` | 대형 톱니 · 허브 |
| `wheel` | 휠 | `#222222` | 타이어/림/허브 |
| `motor_m` | M 모터 | `#CC0000` | 쉘+그릴+출력 스텁 |

브랜드 팔레트 **카피 금지** — Technic **관례** 색만 (노랑 빔 / 회 액슬 / 청 핀 등).

## Interface 연동 (제안)
1. `PartCatalog.list()` 항목에 아이콘 로드: `load("res://assets/catalog/parts/%s.png" % id)`
2. 텍스트 라벨과 병행 가능 (아이콘 없으면 기존 텍스트 폴백)
3. JSON `icon` 필드 추가는 Parts Design P2 — 지금은 경로 규칙만으로 충분

## 비목표
- UI 코드 변경
- 튜토리얼 아이콘 (`assets/catalog/tutorial/`) — 별도
- 환경 썸네일 (`assets/catalog/environments/`) — 완료
