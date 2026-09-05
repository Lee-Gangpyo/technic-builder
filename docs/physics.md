# Physics notes — Technic Builder MVP

## Scale
- Catalog stores SI meters (`size_m`). At runtime parts are scaled by **100** so **1 Godot unit = 1 cm**.
- Technic hole pitch = 8 mm → **0.8 units**. This keeps masses/forces in a range that GodotPhysics3D handles stably on web/iPad.

## Joints
| Connection | Joint | Behavior |
|---|---|---|
| `pin` ↔ `pin_hole` | `Generic6DOFJoint3D` (all DOF locked) | Rigid frame (beams/motors) |
| `axle` ↔ `axle_hole` (or axle↔axle) | `HingeJoint3D` | Free spin about connector axis |

Godot 4 has no built-in FixedJoint3D; 6DOF with zero limits approximates a weld.

**P2 applied (Assembly agreement):** `JointFactory` uses an internal **web_stable** preset. Public `create_joint(...)` signature and pin/axle mapping are unchanged (no preset argument).

| Joint | Tuning |
|---|---|
| Fixed `Generic6DOFJoint3D` | Hard 0 linear/angular limits on X/Y/Z. Soft-limit / spring flags **off**. Per-axis linear & angular: LIMIT_SOFTNESS **0.8**, RESTITUTION **0.1**, DAMPING **1.0**. |
| Revolute `HingeJoint3D` | `PARAM_BIAS` **0.25**, relaxation **0.8** (`PARAM_LIMIT_RELAXATION` in Godot 4.3), `PARAM_LIMIT_SOFTNESS` **0.7**, `FLAG_ENABLE_MOTOR` **false**. |

Duplicate-joint avoidance remains outside this factory.

## Gear mesh solver choice
We use a **soft velocity constraint** (`GearConstraint`) each physics tick:

```
teeth_a * ω_a + teeth_b * ω_b ≈ 0
```

### Bidirectional mass-weighted correction (P1)
1. Measure axis-aligned spins about each gear’s local Y (`global_transform.basis * Vector3.UP`).
2. Residual `error = teeth_a * ω_a + teeth_b * ω_b`.
3. Impulse-like split by inverse mass:
   - `λ = follow * error / (teeth_a²/m_a + teeth_b²/m_b)`
   - `Δω_a = -λ * teeth_a / m_a`, `Δω_b = -λ * teeth_b / m_b`
4. Heavier body moves less; both gears are corrected (not only B).
5. **Catch-up cap:** `|λ|` limited so both `|Δω| ≤ MAX_CATCHUP_DELTA` (~2 rad/s/tick), preserving mass-weighted split (not independent Δω clamps). After ratio-aware `MAX_OMEGA` ceilings, spins are re-paired if needed.
6. **Follow blend:** `follow` default **0.4** (separate from the cap) — partial correction per tick for web single-thread stability.
7. **Ratio-aware `MAX_OMEGA`:** per-gear axis ceilings so a 3:1 mesh cannot demand `|ω| > MAX_OMEGA` on the small gear (avoids sustained clamp-induced slip).
8. Tangential (non-axis) angular velocity: light damp on **both** gears (**0.94**).
9. `MAX_OMEGA` (**25**) length clamp applied after correction.

### Slip mitigation
Under large shocks the ratio can still slip briefly; catch-up cap, bidirectional mass split, ratio-aware omega ceilings, and gentler motor drive reduce sustained slip versus the old one-sided B-follow. Optional metrics: set `GearConstraint.DEBUG_METRICS = true` to print avg/max `|err|` every ~60 frames (`err = ω_b - (-ω_a * teeth_a/teeth_b)` post-correction). Smoke prints `last_abs_error` / `ema_abs_error` even when DEBUG is off.

### Why not alternatives?
1. **Hinge motor ratio / custom Jacobian** — accurate but heavy to maintain across Godot versions and awkward with multiple meshes.
2. **Animated kinematic gears** — breaks Drive-mode RigidBody interaction with the ground.
3. **Full contact tooth simulation** — unstable at game scale, expensive on mobile/web.

The soft constraint is **stable-first**: it keeps opposite rotation and tooth ratio visible for demos while remaining cheap for HTML5/iPad exports.

## Motors
`TechnicPart._integrate_forces` applies a **gentle omega blend** toward target RPM when `motor_enabled` is true (Drive mode + UI/keyboard):
- Lerp factor **`motor_lerp`** (default **0.10**) plus per-tick `|Δω|` cap **`motor_max_domega`** (default **±1.5**) so the motor does not overpower `GearConstraint` every frame. Templates override via `MotionPresets`.
- Tangential damp **0.92**; explosion clamps on linear/angular velocity remain.

Part defaults: `linear_damp` **1.25** and `angular_damp` **1.8** to ease web 6DOF positional jitter without killing free axle spin.

## Drive regression targets (Game builder)
Headless Drive ~10s (≈600 physics frames) on the starter cart after motor ON:

| Metric | Target | Notes |
|---|---|---|
| `GearConstraint.last_abs_error` | **≤ 0.05** | Instant post-correction ratio residual |
| `GearConstraint.ema_abs_error` | **≤ 0.5** | Smoothed residual |
| Wheel spin frame ratio | **≥ 0.95** | Frames with any wheel `‖ω‖ > 0.05` / total |
| NaN / explode | **0** | No NaN velocities; no `‖v‖>80` / `‖ω‖>40` spikes |

Merge bar: **NaN=0 and explode=0** is sufficient for priority merge; the table above is the preferred regression gate. Measured baseline (post λ re-pair): last/ema **0.0**, wheel ratio **≈0.997**.

## MotionPresets (P0)
`scripts/physics/motion_presets.gd` (`class_name MotionPresets`) applies per-template motor/hinge tuning without changing `JointFactory.create_joint(...)`.

| Kind | rpm_factor × max_rpm | max_torque | motor_lerp | motor_max_domega | hinge |
|---|---|---|---|---|---|
| `KART` | **0.58** | 0.15 | 0.10 | 1.5 | (factory default) |
| `GEAR_DEMO` | **0.40** | 0.12 | 0.12 | 1.2 | (factory default) |
| `CRANE` | **0.35** | 0.28 | 0.08 | 1.0 | BIAS **0.35**, LIMIT_RELAXATION **0.9**, motor flag **false** |

Spawn APIs on `AssemblyManager` (BUILD freeze pattern):
- `spawn_starter_cart()` — applies `Kind.KART`
- `spawn_gear_demo()` — board + 24T↔8T (3:1), `Kind.GEAR_DEMO`
- `spawn_mini_crane()` — mast + 24→8 + boom hinge, `Kind.CRANE` (+ `tune_hinge`)

`TechnicPart` exposes `motor_lerp` / `motor_max_domega` used in `_integrate_forces`. Drive regression targets above remain valid for the starter kart (last≤0.05, ema≤0.5, wheel≥0.95, nan=0).

## Engine
Default **GodotPhysics3D** (standard Godot 4.3 export). Jolt can be swapped later if a custom export template includes it.
