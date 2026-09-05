# Tutorial Guide — 카피·오버레이 스펙 (감수 통과)

**sample_id:** `tutorial_guide` · **이름:** 튜토리얼 가이드  
**브랜드:** 「3스텝+운전」또는 「첫 놀이」· UI 토글은 **「튜토리얼」** (「3스텝」단독 금지 — Drive가 빠짐)  
**범위:** 카피·스텝·아이콘 키·오버레이 배치. **코드/`scripts/ui` 미수정** — Catalog Art·Interface는 Day1 P0(모바일 HUD) 이후.  
**톤:** 한국어 우선 · 한 줄 · HUD `help_label`과 같은 짧기.

앵커: `/workspace/design-day1/SAMPLE_SPAWN_ENTRIES_DAY1.md`

---

## 플로우 (4비트)

| # | step_id | name_ko | icon_key | 완료 조건 (예정) |
|---|---------|---------|----------|------------------|
| 1 | `tut_grab` | 집기 | `icon_tut_grab` | 부품을 잡아 드래그 시작 |
| 2 | `tut_rotate` | 회전 | `icon_tut_rotate` | 회전으로 90° 1회 |
| 3 | `tut_snap` | 스냅 | `icon_tut_snap` | 커넥터 스냅 1회 성공 |
| 4 | `tut_drive` | 운전 | `icon_tut_drive` | Drive 모드 진입 또는 스로틀 1회 |

- **「스냅」용어 유지** (게임 내 통일)
- 스킵: 오버레이 닫기 / 「건너뛰기」 · 재시작: 샘플 줄 「튜토리얼」 토글

---

## 카피 (KO 확정 · EN 보조)

| step_id | title_ko | body_ko | title_en | body_en |
|---------|----------|---------|----------|---------|
| `tut_grab` | 집기 | 부품을 눌러 끌어 보세요 | Grab | Tap and drag a part |
| `tut_rotate` | 회전 | 회전으로 90° 돌려 보세요 | Rotate | Rotate 90° |
| `tut_snap` | 스냅 | 구멍에 맞추면 붙어요 | Snap | Align to a hole — it snaps |
| `tut_drive` | 운전 | 운전 모드로 움직여 보세요 | Drive | Switch to Drive and move |

완료 한 줄: `좋아요! 다음` · 전체 끝: `준비 끝 — 조립해 보세요`  
HUD 토글 라벨: `튜토리얼`

---

## 오버레이 배치 (Interface · P0 이후)

- **위치:** 화면 하단 중앙 카드 (컴팩트 세로에서 도구바·카탈로그와 비겹침)
- **구성:** `icon_key` · `title_ko` · `body_ko` · 진행 점 `●○○○` · [다음] / [건너뛰기]
- **아이콘 경로(예정):** `res://assets/catalog/tutorial/{icon_key}.png` — Catalog Art
- **입력:** 월드 드래그 방해 금지 · 터치 타깃 ≥ 44px
- **모드:** Build 1–3 · Drive 진입 시 4번 포커스

---

## 담당 경계

| 항목 | 담당 |
|------|------|
| 스텝 ID · KO 카피 · 이 스펙 | **Tutorial** |
| 아이콘 시안 `icon_tut_*` | Catalog Art (승인됨 · P0 이후) |
| 오버레이 UI · `scripts/ui` | Interface (P0 이후) |
| 샘플 스폰·조인트 | Assembly / Motion |
| 룩·메시 | Design / Part Art |

커넥터 `pos`/`axis`/`type` 변경 없음.

---

## 상태

- [x] 스텝·아이콘 키 잠금 · 총괄 승인 (`icon_tut_grab|rotate|snap|drive`)
- [x] KO body 감수 통과 (소수정)
- [ ] Catalog Art 시안 (P0 이후)
- [ ] Interface 오버레이 연결 (P0 이후)
