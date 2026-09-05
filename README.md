# Technic Builder / 테크닉 빌더

Family-friendly **Godot 4** Lego Technic–style assembly mini-game inspired by Zelda TotK Ultrahand.  
Assemble beams, gears, axles, motors, and wheels with magnet snap, simulate gear ratios & motor torque, then **Drive** the build.

가족용 Godot 4 테크닉 조립 미니게임입니다. 빔/기어/액슬/모터/바퀴를 스냅으로 조립하고, 기어비·모터 토크를 시뮬한 뒤 운전할 수 있습니다.

> **Data credit:** Part dimensions and Technic conventions reference community data from [Rebrickable](https://rebrickable.com/) and [LDraw](https://www.ldraw.org/). This project uses **procedural/CSG placeholder meshes only** — no official LEGO® assets or trademarks as product assets. LEGO is a trademark of the LEGO Group.

## Requirements
- **Godot 4.3+** (developed with 4.3 stable, GDScript only)
- Forward+ renderer (default)

## How to open
1. Install [Godot 4.3+](https://godotengine.org/download/).
2. Import / open this folder (`project.godot`).
3. Run the main scene `scenes/main.tscn` (F5).

```bash
# Optional: headless smoke check
godot --path . --headless --quit-after 3
```

## Controls / 조작

| Action | Mouse/Keyboard | Touch UI |
|---|---|---|
| Spawn part | Catalog buttons | Same |
| Move | LMB drag | Drag |
| Rotate 90° | `R` or button | 회전 90° |
| Detach | `X` or button | 분리 |
| Undo | `Ctrl+Z` | 실행취소 |
| Build ↔ Drive | Mode button | 모드 |
| Motor on/off | `Space` | 모터 ON/OFF |
| Forward / Back | `W` / `S` (or arrows) | ▲ / ▼ |
| Orbit camera | RMB / MMB drag, wheel zoom | — |

**Starter:** press **스타터 카트** to load a motor→gear→wheel demo cart, then switch to **Drive**.

## Architecture
```
data/parts/*.json     Part catalog (id, KO/EN names, mass, teeth, connectors, size)
scripts/parts/        TechnicPart, PartCatalog, PartMeshFactory (procedural meshes)
scripts/physics/      SnapSystem, JointFactory, GearConstraint, ConnectionTypes
scripts/assembly_manager.gd   Spawn, drag, snap, undo, starter, motors
scripts/ui/           Catalog + HUD (Korean labels)
scenes/main.tscn      Ground, ramp, lighting, assembly roots, HUD
docs/physics.md       Gear solver rationale
```

### Scale
Catalog sizes are in **meters**. Runtime scale **×100** → **1 unit = 1 cm**. Hole spacing = **0.8**. Documented so physics stay stable on web.

### Snap & joints
Compatible pairs: `pin`↔`pin_hole` (weld via 6DOF), `axle`↔`axle_hole` (hinge). When connectors align within distance/angle, parts magnet-snap and a joint is created.

### Gears & motors
Nearby gears with pitch-radius sum ≈ separation get a `GearConstraint` (opposite ω × tooth ratio). Motors apply torque in `_integrate_forces` toward target RPM.

## Web / iPad export notes
1. Editor → **Project → Export → Web**.
2. Enable **VRAM texture compression** / ETC2/ASTC as needed for mobile Safari.
3. Prefer **lower physics tick** if needed; keep part counts small.
4. Touch: catalog + drive buttons are large; orbit still desktop-oriented (TODO: one-finger orbit).
5. Host with correct COOP/COEP headers if using SharedArrayBuffer threads; otherwise use single-threaded export for broader iPad Safari support.
6. Stability > fidelity: soft gear constraint and modest damping are intentional for HTML5.

## MVP status
**Works:** catalog spawn, drag/rotate/snap/detach/undo, Build/Drive toggle, gear constraint, motor torque, starter cart, ground + ramp, KO UI labels.  
**Limitations:** placeholder meshes; snap is connector-proximity only (no full Ultrahand multi-grab); gear constraint can slip under shock; camera orbit is mouse-first; no save/load yet; pin/beam structures may jitter with many 6DOF welds.

## TODOs
- [ ] Save / load assemblies (JSON)
- [ ] Better touch orbit + pinch zoom
- [ ] More parts (bevel gears, frames, liftarms)
- [ ] Visual snap ghosts / highlight valid sockets
- [ ] Optional Jolt physics export template
- [ ] PWA wrapper for iPad home-screen

## License
Code and procedural assets: MIT (unless noted). Third-party data references remain with their owners. Not affiliated with the LEGO Group or Nintendo.
