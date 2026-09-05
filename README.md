# Technic Builder / 테크닉 빌더

Family-friendly **Godot 4** Lego Technic–style assembly mini-game inspired by Zelda TotK Ultrahand.  
Assemble beams, gears, axles, motors, and wheels with magnet snap, simulate gear ratios & motor torque, then **Drive** the build.

가족용 Godot 4 테크닉 조립 미니게임입니다. 빔/기어/액슬/모터/바퀴를 스냅으로 조립하고, 기어비·모터 토크를 시뮬한 뒤 운전할 수 있습니다.

> **Data credit:** Part dimensions and Technic conventions reference community data from [Rebrickable](https://rebrickable.com/) and [LDraw](https://www.ldraw.org/). This project uses **procedural/CSG placeholder meshes only** — no official LEGO® assets or trademarks as product assets. LEGO is a trademark of the LEGO Group.

## Requirements
- **Godot 4.3+** (developed with 4.3 stable, GDScript only)
- Desktop: Forward+ renderer (default)
- Web / iPad Safari: **GL Compatibility** (`rendering_method.web`)

## How to open
1. Install [Godot 4.3+](https://godotengine.org/download/).
2. Import / open this folder (`project.godot`).
3. Run the main scene `scenes/main.tscn` (F5).

```bash
# Optional: headless smoke check
godot --path . --headless --quit-after 3
# Or full gameplay smoke:
godot --path . --headless -s res://scripts/smoke_test.gd
```

## Controls / 조작

### 터치 스킴 (iPad) — 선택한 방식
부품 드래그와 카메라가 싸우지 않도록 **빈 공간 / 부품을 구분**합니다.

| 제스처 | 동작 |
|---|---|
| **한 손가락 — 빈 공간 드래그** | 카메라 궤도(orbit) |
| **한 손가락 — 부품 위 드래그** | 선택 부품 이동(스냅 유지) |
| **두 손가락 핀치** | 줌 |
| **두 손가락 드래그** | 카메라 팬(바라보는 지점 이동) |
| 카탈로그 / 상단 버튼 | 배치·회전·모드 전환 (≥44pt) |
| 운전: **▲ / ▼** + **모터 ON/OFF** | 멀티터치 홀드 지원 |

### Desktop

| Action | Mouse/Keyboard | Touch UI |
|---|---|---|
| Spawn part | Catalog buttons | Same |
| Move | LMB drag | 부품 드래그 |
| Rotate 90° | `R` or 회전 Y/X | 회전 Y 90° / 회전 X 90° |
| Detach | `X` or button | 분리 |
| Undo | `Ctrl+Z` | 실행취소 |
| Build ↔ Drive | Mode button | 모드 |
| Motor on/off | `Space` | 모터 ON/OFF |
| Forward / Back | `W` / `S` (or arrows) | ▲ / ▼ |
| Orbit camera | RMB / MMB drag, wheel zoom | 빈곳 한 손가락 |
| Pan camera | Shift+MMB | 두 손가락 드래그 |

**Starter:** on first load a motor→gear→wheel demo cart is auto-spawned (and framed by the camera). Press **스타터 카트** to reload it, then switch to **Drive**.

### UI / iPhone portrait
- Bundled **Noto Sans KR** (`assets/fonts/`) is the project default theme font so Hangul renders on Web/iOS (no tofu).
- Narrow/portrait: top bar keeps Mode + **부품** toggle; tool buttons wrap in a flow row; catalog becomes a **bottom sheet** (collapsed by default, larger ≥56px targets).
- Landscape/desktop: left catalog rail + tools row (unchanged usability).

## Web / iPad 내보내기

### 프리셋 메모 (Safari 친화)
- 프리셋 이름: **`Web (Safari/iPad)`** (`export_presets.cfg`)
- **`variant/thread_support=false`** (단일 스레드) — iPad Safari에서 SharedArrayBuffer / COOP·COEP 없이 안정적으로 동작
- 커스텀 셸: `export/ipad_shell.html` (`touch-action: none`, gesture `preventDefault`, `user-scalable=no`)
- 텍스처: 모바일 VRAM 압축(ETC2/ASTC) 활성
- 렌더러: 웹은 `gl_compatibility` (프로젝트 `rendering_method.web`)

### 보내기

```bash
# Export templates must match Godot 4.3.stable
godot --headless --path . --export-release "Web (Safari/iPad)" build/web/index.html
```

산출물: `build/web/` (`index.html` + `.wasm` + `.pck` + JS).

### 로컬 서버 / iPad 테스트

```bash
./scripts/serve_web.sh          # 기본 포트 8080
./scripts/serve_web.sh 9000     # 포트 지정
```

1. PC와 iPad를 **같은 Wi‑Fi(LAN)** 에 연결합니다.
2. 스크립트가 출력하는 `http://<LAN-IP>:8080/` 주소를 iPad **Safari**에서 엽니다.
3. 가로(landscape) 권장. 홈 화면에 추가하면 거의 전체화면으로 쓸 수 있습니다.
4. 브라우저 확대/스크롤이 가로채면 새로고침 후 캔버스를 한 번 탭하세요.

> 스레드 ON 빌드는 COOP/COEP 헤더가 있는 HTTPS 호스트가 필요합니다. 이 저장소 기본값은 **스레드 OFF** 입니다.

## Architecture
```
data/parts/*.json     Part catalog (id, KO/EN names, mass, teeth, connectors, size)
assets/catalog/environments/{id}.png   Environment picker thumbnails (sandbox, forest, space, mars, construction, stadium)
scripts/parts/        TechnicPart, PartCatalog, PartMeshFactory (procedural meshes)
scripts/physics/      SnapSystem, JointFactory, GearConstraint, ConnectionTypes
scripts/assembly_manager.gd   Spawn, drag, snap, undo, starter, motors
scripts/camera_pivot.gd       Mouse + multitouch orbit/pinch/pan
scripts/ui/           Catalog + HUD (Korean labels, large hit targets)
export/ipad_shell.html Safari-friendly HTML shell
build/web/            HTML5 export output
scenes/main.tscn      Ground, ramp, lighting, assembly roots, HUD
docs/physics.md       Gear solver rationale
```

### Scale
Catalog sizes are in **meters**. Runtime scale **×100** → **1 unit = 1 cm**. Hole spacing = **0.8**. Documented so physics stay stable on web.

### Snap & joints
Compatible pairs: `pin`↔`pin_hole` (weld via 6DOF), `axle`↔`axle_hole` (hinge). When connectors align within distance/angle, parts magnet-snap and a joint is created.

### Gears & motors
Nearby gears with pitch-radius sum ≈ separation get a `GearConstraint` (opposite ω × tooth ratio). Motors apply torque in `_integrate_forces` toward target RPM.

## MVP status
**Works:** catalog spawn, drag/rotate/snap/detach/undo, Build/Drive toggle, gear constraint, motor torque, starter cart, ground + ramp, KO UI labels, **touch orbit/pinch/pan**, **Web single-thread export**.  
**Limitations:** placeholder meshes; snap is connector-proximity only (no full Ultrahand multi-grab); gear constraint can slip under shock; no save/load yet; pin/beam structures may jitter with many 6DOF welds; Web performance depends on part count; iPad Safari has no threads in this preset (CPU heavier builds may stutter).

## TODOs
- [ ] Save / load assemblies (JSON)
- [x] Better touch orbit + pinch zoom
- [ ] More parts (bevel gears, frames, liftarms)
- [ ] Visual snap ghosts / highlight valid sockets
- [ ] Optional Jolt physics export template
- [ ] PWA wrapper for iPad home-screen
- [ ] On-screen virtual stick (optional alternative to ▲▼)

## License
Code and procedural assets: MIT (unless noted). Third-party data references remain with their owners. Not affiliated with the LEGO Group or Nintendo.
