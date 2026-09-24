# Codex 인계장 — Technic Builder

> 작성: 2026-09-25 (Asia/Seoul)  
> 목적: Grok Bot 멀티에이전트 작업을 Codex로 이관하기 위한 상태 스냅샷  
> 레포: https://github.com/Lee-Gangpyo/technic-builder  
> 플레이: https://lee-gangpyo.github.io/technic-builder/

---

## 1. 한 줄 요약

Godot 4.3 웹(아이패드/아이폰 Safari)용 **레고 테크닉 스타일 조립 + 물리 운전** 미니게임.  
젤다 왕눈(Ultrahand)식 집기/회전/스냅 + 모터·기어·바퀴 시뮬.  
품질 목표: 수준 0→5 (가족용 최고 랭크 웹게임). **현재 level-1 게이트는 Drive P0에서 막힘.**

---

## 2. 스택·배포

| 항목 | 값 |
|------|-----|
| 엔진 | Godot **4.3** stable, GDScript only |
| 웹 렌더러 | `gl_compatibility` (`rendering_method.web`) |
| 웹 프리셋 | `Web (Safari/iPad)` — `variant/thread_support=false` (싱글스레드) |
| 셸 | `export/ipad_shell.html` |
| 폰트 | Noto Sans KR (`assets/fonts/`) — 웹 한글 깨짐 방지 |
| Pages | `gh-pages` 브랜치 → GitHub Pages |

### 로컬 실행

```bash
# Godot 4.3+ 로 project.godot 열기, scenes/main.tscn 실행
godot --path . --headless --quit-after 3
godot --path . --headless -s res://scripts/smoke_test.gd
```

### 웹 내보내기

```bash
godot --headless --path . --export-release "Web (Safari/iPad)" build/web/index.html
# 산출: build/web/ → gh-pages 배포
```

---

## 3. 현재 HEAD / 라이브

| 구분 | SHA | 비고 |
|------|-----|------|
| `main` tip | `da0e4e7` | Re-export Web build: #26 motor output axle |
| 라이브 web (Pages 기준) | `da0e4e7` / gh-pages `4a8feb2` | pck ≈ 6881984 |
| 포함 픽스 | PR **#17** starter joint graph + PR **#20** motor ramp + PR **#26** output-axle drive |

로컬 `main`은 `origin/main`과 동기.  
워킹트리: `build/web/*` 삭제 상태(D) + `scripts/_reg_main.gd` untracked — **커밋하지 말 것** (빌드 산출물/임시).

---

## 4. 캠페인·품질 게이트

- **5일 캠페인** (`docs` / 플랜: CAMPAIGN_5DAY): Day1 = 폰에서 선택·이동·회전·스냅·Drive가 안정적 → level 1.
- 수준 보고는 정수 단위로만 (0.2 → 1 → … → 5).
- **Design 트랙**은 gameplay level-1과 병렬; P0 메시는 닫힘, P1은 level-1 이후.

### Level-1 게이트 현황 (2026-09-09 마지막 상태)

| 리뷰어 | 결과 | 메모 |
|--------|------|------|
| Reviewer UX | PASS (~3.5) | ToolsBar≥44, rotate Y/X OK. catalog/env sheet는 이후 P1로 정리됨 |
| Reviewer Tech | 배포 무결성 OK / Drive 회귀는 FAIL 이력 | headless vs web 불일치 주의 |
| Reviewer Play | **Drive FAIL (P0)** | assemble→Drive→Motor ON→전진 ~5s에 차체/바퀴 붕괴 |
| Design P0 (메시) | **PASS** | PR #14, Pages af505b7 기준 B8/C4 닫음 |

**결론: level-1 미개방.** 블로커는 **웹에서 Starter Cart Drive 전진 시 붕괴** (headless는 #26 PASS, **웹 FAIL**).

---

## 5. Drive P0 타임라인 (핵심만)

1. Play: Motor ON 시 Starter Cart 붕괴 → Assembly/Motion.
2. **#17** merged: starter joint graph (평행 Z 액슬 + 섀시 베어링).
3. 여러 spawn topology PR **#18–#25** headless 폭발로 거부/닫힘. `#19`는 merge 후 revert.
4. **#20** merged: Drive 진입 시 motor ramp (웹 틱 위생).
5. 루트코즈 합의: 모터 **하우징**이 섀시에 6DOF 용접된 채 `_integrate_forces`가 본체 전체에 ω → **출력 액슬/로터만 구동**해야 함.
6. **#26** merged (`6b26ace`): housing ω=0, output axle만 구동. headless PASS → Pages `da0e4e7`.
7. **최신:** Motion/Play 웹 재검증 **FAIL** — Motor ON 후 전진 ~5초 붕괴. headless PASS ≠ web. Motion이 재조사 중이었음.

**정책:** spawn topology PR은 headless Motor ON PASS 증명 없이 머지 금지. Drive P0는 Motion 모터 API/솔버 쪽이 우선.

---

## 6. 파일 소유권 (이관 후에도 유지 권장)

| 영역 | 경로 | 구 담당 |
|------|------|---------|
| 부품 JSON·메시 팩토리 | `data/parts/`, `scripts/part_mesh_factory.gd` | Parts Design / Part Art |
| UI/터치/웹 HUD | `scripts/ui/` | Interface |
| 조립·스냅·카메라 | `assembly_manager*`, `snap_system*`, `camera_pivot*` | Assembly |
| 물리·모터·기어 | `scripts/physics/`, `technic_part.gd`, `docs/physics.md` | Motion Physics |
| 환경 프리셋 | environments 관련 assets/scripts | Environments (UI 피커는 Interface) |
| 튜토리얼 카피 | `docs/tutorial_3step.md` | Tutorial (UI는 Interface) |

커넥터 pos/axis/type 변경은 예전엔 Game builder 승인 테이블 후 커밋. Codex 단독 시에도 **starter/Drive 회귀**를 먼저 볼 것.

---

## 7. 완료된 것

- 공개 레포 + GitHub Pages 플레이 가능
- 부품 카탈로그·스냅·회전·Undo·Build/Drive 모드
- 스타터 카트 자동 스폰 + 카메라 프레이밍
- 터치 스킴 (빈곳 orbit / 부품 드래그 / 핀치 줌)
- iPhone 세로: 카탈로그 bottom sheet, ≥44–56pt 타깃
- Environments Day1 프리셋 + UI 피커 (merged)
- Catalog part icons (PR #12/#16), Part Art P0 meshes (PR #14)
- Sample templates: gear demo / mini crane skeletons
- Tutorial 3스텝 KO 카피 스펙 (`docs/tutorial_3step.md`)
- Drive 관련 #17+#20+#26 main에 포함

## 8. 미완 / 열린 이슈

1. **P0:** 웹 Drive 전진 안정화 (da0e4e7/#26 이후에도 ~5s collapse)
2. headless PASS vs web FAIL 원인 정리 (싱글스레드 틱, 조인트 residual, 마운트 계약)
3. 실기기 iPhone Safari 사용자 확인 (터치/Drive)
4. Design P1 (아이콘/팔레트 고도화) — level-1 이후
5. 튜토리얼 오버레이 UI 연결 (스펙만 있음)
6. Day2+ (핸드필, 챌린지, 세이브, 폴리시)

---

## 9. Codex가 바로 이어받을 다음 액션

1. **재현:** Pages `da0e4e7` 또는 로컬 웹 빌드에서  
   `assemble(또는 스타터) → Drive → Motor ON → 전진 5초` 붕괴 재현·로그/조인트 덤프.
2. **#26 이후 웹 전용 원인:** housing/output 분리 후에도 붕괴하는 조인트·충돌·기어 맞물림·월드 앵커 동결 여부 점검 (`docs/physics.md`, Motion regression 바: last≤0.05 / ema≤0.5 / wheel≥0.95 / nan=0 / explode=0).
3. **픽스 PR:** 웹에서도 전진 유지되는 최소 패치 → headless **및** 웹(또는 export) 스모크 PASS 후 main + Pages 재배포.
4. Play 기준 level-1 재오픈: 회전/스냅/30s + **Motor ON 전진 안정**.
5. (선택) Interface 시트 z-order 로컬 잔여(`fbe2f83` 계열)가 main에 없는 경우 필요 시만 체리픽 — Drive P0보다 후순위.

---

## 10. 주요 PR 참고

| # | 상태 | 요약 |
|---|------|------|
| 26 | MERGED | motor drives output axle only |
| 20 | MERGED | Drive-entry motor ramp |
| 19 | MERGED→revert | single-axle — headless 폭발 |
| 17 | MERGED | starter joint graph |
| 18,21–25 | CLOSED | spawn topology 실패 |
| 14–16,12 | MERGED | Part Art / catalog icons / UI wiring |
| 15 | MERGED | environment picker |

---

## 11. 주의사항

- 웹은 **싱글스레드** (`thread_support=false`). SharedArrayBuffer/COOP·COEP 가정 금지.
- LEGO 공식 에셋/상표 사용 금지. Rebrickable/LDraw **치수 참고 + 자체 메시**만.
- headless PASS만으로 Pages 올리지 말 것 — **웹 Drive 실측**이 level-1 기준.
- `build/web/`는 내보내기 산출물; 소스와 섞어 커밋하지 않기.
- 박스 `/workspace`에 흩어진 `asm_*.gd`, `design-day1/`, `technic-plan/`은 작업 스크래치·사인오프 사본. **정본은 이 레포 `docs/` + `main`.**

---

## 12. Grok Bot 정리 대상 (참고 — 앱에서 사용자 삭제)

에이전트 삭제는 사이드바에서 해당 행 **우클릭 → Delete** (영구). 채널(그룹챗)도 사이드바에서 삭제.

### 그룹챗 (CreateChannel)

| 이름 | id |
|------|-----|
| Technic Builder | `343fc5c2-3881-4b34-995c-54b9a869e316` |
| Technic Review | `eea038fa-f3b4-4fa3-8e7e-d6dd71416817` |
| Technic Design | `07020b18-7999-4e82-9a33-c2b57d0a88c3` |

### Technic 관련 에이전트

Game builder, Motion Physics, Assembly, Interface, Parts Design, Design Lead, Part Art, Catalog Art, Environments, Tutorial, Reviewer Play, Reviewer UX, Reviewer Tech  
(+ 위 채널과 동명·동일 id로 보이는 Technic Builder / Technic Design / Technic Review 행)

**남길 것 (게임 외):** Main Agent, Agent economy / Agent Economy, Research, Deal Scout, Agent Payments, Market Map, Writing, New Bot 등.

---

## 13. 관련 문서 (레포·박스)

- `README.md` — 조작·웹 내보내기
- `docs/physics.md`, `docs/tutorial_3step.md`, `docs/catalog_part_icons.md`
- 플랜 사본(박스): `/workspace/technic-plan/CAMPAIGN_5DAY.md`, `level5_bar.md`, Day1 사인오프들
- Design 사인오프(박스): `/workspace/design-day1/`

