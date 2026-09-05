# Technic Builder — Strategic Quality Roadmap Audit

**Date:** 2026-09-05 (KST)  
**Repo:** `Lee-Gangpyo/technic-builder` @ `main` (`09c4a89`, includes rotate HUD fixes `499672e` / `f715245` / `09c4a89`)  
**Live:** https://lee-gangpyo.github.io/technic-builder/  
**Self-rating context:** ~0.2 / 5.0 vs top-tier published web sandbox builders (itch.io / Poki polish bar)  
**Scope:** Read-only code/docs audit; no gameplay code changes in this PR.

---

## Executive summary

The MVP is a credible **Godot 4.3 / GDScript** phone+web skeleton: catalog spawn, magnet snap + joints, gear soft-constraint, motor drive, starter cart, KO UI, Safari single-thread export. Core loops exist but were fragile on mobile (rotate-after-select). **Input-order / HUD occlusion fixes just landed on main** and need device sign-off. Content is thin (10 procedural parts); production layers (save/share/onboarding/juice/retention) are largely absent.

**Honest level placement today:** **L0.5–L1 incomplete**, trending toward L1 if phone QA on the new rotate path passes. Desktop Build/Drive can look like early L1. Physics toy satisfaction is closer to early L2 *when* the starter cart drives, but assembly feel is not yet “toy-grade.”

**Highest-leverage next move:** **verify** rotate/select on real iPhone/iPad Safari, add tap-vs-drag (stop detach-on-every-tap), then juice + one guided goal before expanding the catalog.

---

## 1. Current feature inventory

### Works (shipped / demoable)

| Area | What | Evidence |
|---|---|---|
| Project bootstrap | Godot 4.3, Forward+/web GL Compatibility, KO fallback locale | `project.godot` |
| Part catalog | 10 JSON parts (beams 5/7, axle 5, pin, bush, gears 8/16/24, wheel, motor M) | `data/parts/*.json`, `scripts/parts/part_catalog.gd` |
| Procedural meshes | CSG/placeholder Technic-like silhouettes + collisions | `scripts/parts/part_mesh_factory.gd` |
| Connectors | Markers + colored spheres; pin/axle types; 8mm module alignment | `technic_part.gd`, parts PRs in history |
| Spawn / select / drag | Ray pick layer 2, planar drag, freeze while moving | `assembly_manager.gd` `_try_pick` / `_drag_to` |
| Snap | Distance+angle scoring, hysteresis prefer, ghost preview mesh | `snap_system.gd`, `_show_snap_ghost` |
| Joints | pin↔pin_hole → 6DOF weld; axle↔axle_hole → hinge; `web_stable` tuning | `joint_factory.gd`, `docs/physics.md` |
| Gears | Soft bidirectional mass-weighted `GearConstraint` | `gear_constraint.gd` |
| Motors | `_integrate_forces` omega blend + throttle | `technic_part.gd`, `set_throttle` |
| Starter cart | Motor→gear→wheel template + camera `focus_on` | `spawn_starter_cart`, `main.gd` |
| Build ↔ Drive | Mode toggle, motor UI, ▲/▼ hold | `hud.gd`, `game_state.gd` |
| Camera | Desktop RMB/MMB/wheel; touch orbit / pinch / two-finger pan; skips while part-dragging | `camera_pivot.gd` |
| HUD / i18n | Noto Sans KR theme, portrait bottom-sheet catalog, ≥48–56px targets; compact rotate targets enlarged | `hud.gd`, `assets/fonts/`, `assets/ui/default_theme.tres` |
| HUD vs 3D input | Skip 3D pick over STOP HUD controls; toolbar z-index / mouse_filter hardening | `assembly_manager.gd:173-249`, `hud.gd:68-106`, `09c4a89` |
| Undo (partial) | Spawn + connect only (stack capped 50) | `game_state.gd`, `undo_last` |
| Web export | Threadless Safari preset, custom shell, `build/web/` artifacts | `export_presets.cfg`, `export/ipad_shell.html` |
| Smoke | Headless starter + short Drive spin check | `scripts/smoke_test.gd` |
| World | Ground + ramp, lighting, ambient | `scenes/main.tscn` |

### Broken / unreliable

| Issue | Severity | Notes |
|---|---|---|
| **Rotate after select on mobile** | **P0 → verify** | Pre-fix: HUD taps stolen by `_input` ray-pick. Mitigated on main (`499672e`, `09c4a89`). **Device QA still required** — see §2 |
| Select = always drag+detach | Medium | `_try_pick` always `detach_part` (`assembly_manager.gd:294-295`); no tap-vs-drag threshold |
| Rotate undo missing | Low–Med | Rotate notifies but does not `push_undo` |
| Symmetric meshes look unchanged | Low | Axle/pin/bush local Y rotate can look like a no-op |
| Gear slip under shock | Med | Documented; mitigated (`docs/physics.md`) |
| 6DOF weld jitter at scale | Med | Pin-heavy frames wobble on web |
| Drive on phone | Med | Works if cart intact; no virtual stick; depends on Button multitouch path |
| Empty-space tap does not clear selection | Low | Selection can go stale |
| Mode→DRIVE clears highlights, not always `GameState.selected_part` | Low | Easy confusion after mode toggle |

### Missing (vs README TODOs + L3–L5 bar)

- Save / load assemblies (JSON)
- Per-socket snap highlight (beyond whole-part ghost)
- Broader Technic set (frames, liftarms, bevels, longer beams)
- Guided onboarding / tutorial / challenges / goals
- PWA beyond shell meta tags
- Share link / screenshot / remix
- Accessibility (focus order, contrast, reduced motion, SR labels)
- Juice: haptics/audio/particles/camera kick
- Persistence, daily goals, gallery, retention
- Optional Jolt physics template
- Multi-grab / Ultrahand-like group manipulate
- Automated UI tests (only short physics smoke today)

---

## 2. Known bug: rotation after select fails on mobile

### Status (audit against `main` @ `09c4a89`)

| State | Detail |
|---|---|
| **Pre-fix root cause** | Assembly handled pointer in `_input` **before** GUI, ray-picked parts under the tools bar, and `set_input_as_handled()` — so `Button.pressed` never fired. |
| **Fixes landed** | (1) `499672e` briefly moved pick to `_unhandled_input` + raised ToolsBar/TopBar z-index / StatusLabel IGNORE / larger compact rotate hits. (2) `09c4a89` restored pick in `_input` (so it still beats camera) but added `_screen_over_blocking_gui` to skip picks over STOP HUD controls; `_rotate_selected` ends drag, freezes, and toasts if nothing selected. Web re-exports included. |
| **Still open** | Confirm on real iPhone Safari; tap-vs-drag/detach-on-pick; rotate undo; possible miss if a Control is STOP but outside recursive HUD/Root walk edge cases. |

### Observed symptom (pre-fix / residual risk)

User selects a part (touch), then taps **회전 Y 90°** / **회전 X 90°** — rotation often did nothing (or started a drag / detach instead). Desktop `R` / precise mouse clicks were more reliable.

### Wiring (happy path)

1. HUD connects buttons → `AssemblyManager._rotate_selected` — `scripts/ui/hud.gd:33-34`
2. Rotate ends active drag, detaches, freezes, applies local 90°, toasts if null — `scripts/assembly_manager.gd:406-423`
3. Keyboard: `_unhandled_input` → `rotate_part` (`R`) — `assembly_manager.gd:258-260`

### Root-cause hypothesis (primary, pre-fix) — **3D pick stole HUD taps**

**Claim:** With pick in `_input` and no UI occlusion check, a finger on Rotate Y that also ray-hit a part (common under the compact tools bar) was claimed as a part pick. GUI never saw the press.

| Step | Evidence |
|---|---|
| **(Historical)** Pick in `_input` before Controls + `set_input_as_handled` on hit | Explains mobile rotate failure; see `499672e` / `09c4a89` commit messages |
| **(Current)** `_screen_over_blocking_gui` / `_control_blocks_pointer` | `assembly_manager.gd:173-201` — walks `HUD/Root` children topmost-first; STOP filters block pick |
| **(Current)** Skip pick when over blocking GUI | `assembly_manager.gd:225-226`, `239-240` |
| **(Current)** Pick still in `_input` to beat camera | `assembly_manager.gd:204-206` comment |
| Compact ToolsBar covers ~2 rows of 3D view | `hud.gd` `_apply_layout` (`btn_h * 2.2`); rotate min width ≥120 in compact (`hud.gd:104-106`) |
| ToolsBar/TopBar z-index + STOP; StatusLabel/Help IGNORE | `hud.gd:68-87`, `scenes/main.tscn` |
| Mobile pure `ScreenTouch` | `project.godot` `emulate_mouse_from_touch=false` |
| Side effect of stolen tap | `_try_pick` selects + freezes + **`detach_part`** (`assembly_manager.gd:286-295`) — felt like “rotate broke my build” |

**Why mobile felt worse than desktop:** larger compact chrome over the framed starter cart; fat-finger occlusion; pure touch path.

### Secondary factors (still relevant)

1. **No select-only gesture** — every successful pick starts drag + detach.
2. **Symmetric meshes** — axle/pin/bush may look unchanged after Y rotate.
3. Null-selection toast is now present (`assembly_manager.gd:408-410`) — former silent no-op mitigated.

### Remaining fix / verify direction

1. **Device QA (P0):** iPhone Safari — select under tools bar → Rotate Y/X ×3 → snap → Drive 10s.
2. **Tap vs drag threshold** — do not detach until movement exceeds N px (Assembly).
3. Optional: `gui_get_hovered_control()` as second guard; rotate undo + SFX.

---

## 3. Gap analysis vs level rubric

### L1 — Playable phone core (select / move / rotate / snap / drive reliable)

| Criterion | Status | Gap |
|---|---|---|
| Select | Partial | Works via pick; always starts drag+detach |
| Move | Mostly | Planar drag OK; no vertical/lift; camera fight mitigated |
| Rotate | **Fix landed / verify** | §2 — code on main; phone QA outstanding |
| Snap | Partial | Ghost OK; no per-socket highlight |
| Drive | Partial | Starter OK in smoke; fragile if joints break |
| Reliability | Improving | Detach-on-pick still hurts “tool after select” |

**Verdict:** **Not L1 yet** until device sign-off. Gate = verify §2 + tap/drag threshold.

### L2 — Satisfying assembly + physics toy

| Criterion | Status | Gap |
|---|---|---|
| Snap feel | Early | Ghost exists; missing magnet pull, click/haptic, socket glow |
| Structure rigidity | Fragile | 6DOF jitter on web |
| Gear/motor toy loop | Promising | Soft constraint + motor blend; regression targets in `docs/physics.md` |
| Part identity | Weak | Procedural, not collectible |
| Failure feedback | Weak | Slip/explode mostly silent |

**Verdict:** **~L1.5 physics demo**, not L2 toy.

### L3 — Content + onboarding + goals

| Criterion | Status | Gap |
|---|---|---|
| Onboarding | Missing | HelpLabel one-liner (`hud.gd`) |
| Goals / challenges | Missing | No missions |
| Content breadth | Thin | 10 parts |
| Templates | One | Starter cart only |

**Verdict:** **L3 empty.** One tutorial + 3 goal cards > +20 parts right now.

### L4 — Production web polish

| Criterion | Status | Gap |
|---|---|---|
| Perf budget | Unknown | Large wasm+pck; single-thread Safari; no part-count policy |
| Save/load | Missing | README TODO |
| Share | Missing | No URL/JSON export |
| a11y | Minimal | Large targets yes; little else |
| PWA | Shell metas only | No SW/offline |

**Verdict:** **Pre-L4.** Save+share before PWA.

### L5 — Top-tier web game

Juice/audio/identity/retention/meta/social essentially **absent**. Consistent with ~0.2/5 self-rating. Do not prioritize until L1–L3 solid.

### Score sketch

| Level | Approx fill | Notes |
|---|---|---|
| L1 | 50–60% | Rotate path fixed in code; verify + select UX remain |
| L2 | 25% | Physics clever; feel unfinished |
| L3 | 5% | Starter ≠ content system |
| L4 | 15% | Export/shell/font real; save/a11y/share not |
| L5 | 2% | Live URL only |
| **Overall vs 5.0** | **~0.3–0.5** | Early MVP with accelerating phone-core fixes |

---

## 4. Ranked backlog (P0–P3)

Owner tags: **Parts Design** · **Interface** · **Assembly** · **Motion Physics** · *(suggested new)* **Content/Onboarding** · **Web/Platform** · **Juice/Audio**

### P0 — Unblocks L1 phone core

| ID | Item | Owner | Why |
|---|---|---|---|
| P0-1 | **HUD occlusion / input order** — DONE on main (`499672e`, `09c4a89`); **verify on device** | Assembly + Interface | Was §2 root cause |
| P0-2 | **Tap vs drag threshold; detach only after drag** | Assembly | Select-then-tool still fighty |
| P0-3 | **Rotate null-selection toast** — DONE (`assembly_manager.gd:408-410`); optional success juice | Interface | Silent no-op mitigated |
| P0-4 | **Manual phone QA script** (select→rotate Y/X→snap→Drive 10s) Safari iPhone/iPad | Interface (+ human) | L1 gate |
| P0-5 | Harden `_screen_over_blocking_gui` edge cases (Drive panel, open catalog sheet) | Assembly | Prevent regressions |

### P1 — Stabilize assembly + drive toy

| ID | Item | Owner | Why |
|---|---|---|---|
| P1-1 | Per-connector snap highlight / valid socket tint | Assembly + Parts Design | Teaches pin vs axle |
| P1-2 | Rotate undo + optional camera-relative axes | Assembly | Power-user expectation |
| P1-3 | Vertical move / lift gesture or HUD Nudge Y | Assembly + Interface | Planar-only limits builds |
| P1-4 | Keep Drive 10s regression targets (`docs/physics.md`) in CI if Godot available | Motion Physics | Prevent gear/motor regressions |
| P1-5 | Cap/warn part count; sleep islands; profile Safari | Motion Physics + Web/Platform | Web stutter |
| P1-6 | Starter cart integrity assert after spawn | Assembly | Mount-align already burned once |

### P2 — L2 feel + L3 content wedge

| ID | Item | Owner | Why |
|---|---|---|---|
| P2-1 | Snap SFX + haptic + ghost pulse | Juice/Audio | Satisfaction multiplier |
| P2-2 | 3 guided goals (connect / gear ratio / climb ramp) | **Content/Onboarding** (new) | Session purpose |
| P2-3 | First-run coach marks (orbit / drag / rotate) | Interface + Content | Replace HelpLabel-only UX |
| P2-4 | +6–12 structural parts | Parts Design | After teach loop |
| P2-5 | Save/load assembly JSON (localStorage / user://) | Assembly + Web/Platform | L4 prerequisite |
| P2-6 | Soften weld jitter / document part budget | Motion Physics | Toy trust |

### P3 — L4–L5 production / retention

| ID | Item | Owner | Why |
|---|---|---|---|
| P3-1 | Share build JSON / deep link | Web/Platform | Virality |
| P3-2 | PWA install + icons | Web/Platform | Home-screen family use |
| P3-3 | a11y pass | Interface | Store/Poki bar |
| P3-4 | Audio bed + drive whoosh + UI clicks | Juice/Audio | Identity |
| P3-5 | Gallery / daily challenge seed | Content + Web | Retention |
| P3-6 | Optional Jolt experiment | Motion Physics | If GodotPhysics ceilings |
| P3-7 | Ultrahand multi-select / group move | Assembly | After L1–L2 |

---

## 5. Five-day plan sketch (~70% capacity after Day 0)

Assumption: ~0.7 FTE effective after planning; Assembly-capable implementer + light Interface help; phone-in-hand QA daily.

### Day 0 — Planning / alignment (this audit)

- Agree L1 DoD: *iPhone Safari — select → Rotate Y/X ×3 → snap to beam → Drive starter 10s without dead zones.*
- Note rotate HUD fixes already on `main`; Day 1 = **verify + P0-2**, not greenfield input rewrite.
- Next feature branch: `fix/select-drag-threshold` (or similar). No catalog expansion until P0 green.
- Capture screen recordings for regression.

### Day 1 — P0 verify + select UX

- Verify `09c4a89` on iPhone/iPad Safari (rotate over starter under tools bar).
- Implement drag threshold before detach (P0-2).
- Spot-check Drive ▲▼ multitouch + open catalog sheet not eating tools.
- Capacity ~70% → verify + one follow-up PR.

### Day 2 — L1 hardening + Drive confidence

- Fallout fixes (camera vs UI, bottom sheet).
- Starter integrity check; optional headless rotate API smoke.
- Re-export web if needed; **declare L1 candidate** after QA checklist.

### Day 3 — Snap clarity

- Per-socket highlight for compatible free connectors.
- Status copy for axis mismatch.
- Motion Physics only if Drive regressed.

### Day 4 — Onboarding wedge

- First-run 3-step coach (orbit / drag / rotate).
- Goal card v0: starter approaches ramp (motor ON + displacement).
- Still no large catalog dump.

### Day 5 — Save prototype + buffer

- Local save/load JSON for parts + transforms + connections.
- Buffer for family-tester bugs.
- Update README MVP status; point to this roadmap; plan P2 juice + parts.

**Out of scope this week:** PWA, gallery, Jolt, multi-grab, large mesh art, L5 retention.

---

## Appendix A — Key paths

```
project.godot
scenes/main.tscn
scripts/main.gd
scripts/game_state.gd
scripts/assembly_manager.gd      # pick/drag/snap/rotate/drive + HUD occlusion
scripts/camera_pivot.gd
scripts/ui/hud.gd
scripts/ui/catalog_panel.gd
scripts/parts/{technic_part,part_catalog,part_mesh_factory}.gd
scripts/physics/{snap_system,joint_factory,gear_constraint,connection_types}.gd
data/parts/*.json
docs/physics.md
docs/roadmap_audit.md            # this file
export/ipad_shell.html
build/web/
README.md
```

## Appendix B — Agent / ownership map (suggested)

| Lane | Primary surfaces |
|---|---|
| Parts Design | `data/parts/`, `part_mesh_factory.gd`, connectors |
| Interface | `hud.gd`, `catalog_panel.gd`, theme/fonts, coach UI |
| Assembly | `assembly_manager.gd`, snap UX, save schema, starters |
| Motion Physics | `joint_factory.gd`, `gear_constraint.gd`, motor integrate, `docs/physics.md` |
| Content/Onboarding *(new)* | Goals, tutorial, challenge detection |
| Web/Platform *(new)* | Export, Pages, PWA, storage bridge, perf budget |
| Juice/Audio *(new)* | SFX, haptics, VFX, camera impulses |

---

*Strategic audit for family Technic assembly web game quality planning. Re-audit after phone L1 sign-off on the rotate path.*
