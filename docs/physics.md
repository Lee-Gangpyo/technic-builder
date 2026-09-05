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

### web_stable preset (Assembly-agreed)
`JointFactory` keeps the public `create_joint(...)` signature and joint mapping. Internal tuning only:

**Fixed 6DOF** — hard 0 linear/angular limits; soft-limit flags stay **off**. Softness 0.8 / restitution 0.1 / damping 1.0 on linear+angular XYZ (soaks snap residual / web jitter without spongy post-snap UX).

**Hinge** — `PARAM_BIAS` 0.25, `PARAM_LIMIT_RELAXATION` 0.8, `PARAM_LIMIT_SOFTNESS` 0.7 (no-op until limits on), motor flag off.

## Gear mesh solver choice
We use a **soft velocity constraint** (`GearConstraint`) each physics tick:

```
teeth_a * ω_a + teeth_b * ω_b ≈ 0
```

### Bidirectional mass-weighted correction
1. Measure axis-aligned spins about each gear’s local Y (`global_transform.basis * Vector3.UP`).
2. Residual `error = teeth_a * ω_a + teeth_b * ω_b`.
3. Impulse-like split by inverse mass:
   - `λ = follow * error / (teeth_a²/m_a + teeth_b²/m_b)`
   - `Δω_a = -λ * teeth_a / m_a`, `Δω_b = -λ * teeth_b / m_b`
4. Heavier body moves less; both gears are corrected.
5. **Catch-up cap:** `|Δω|` per body clamped to `MAX_CATCHUP_DELTA` (~2 rad/s/tick).
6. **Follow blend:** `follow` ≈ 0.4.
7. Tangential (non-axis) angular velocity: light damp on both (~0.94).
8. Ratio-aware `MAX_OMEGA` ceilings so the small gear cannot force residual slip.

Optional metrics: set `GearConstraint.DEBUG_METRICS = true` to print avg/max `|err|` every ~60 frames.

### Why not alternatives?
1. **Hinge motor ratio / custom Jacobian** — accurate but heavy across Godot versions.
2. **Animated kinematic gears** — breaks Drive-mode RigidBody / ground interaction.
3. **Full contact tooth simulation** — unstable at game scale, expensive on mobile/web.

## Motors
`TechnicPart._integrate_forces` uses a **gentle omega blend** toward target RPM when `motor_enabled` is true:
- Lerp factor ~0.10 plus per-tick `|Δω|` cap (~1.5) so the motor does not overpower `GearConstraint`.
- Explosion clamps on linear/angular velocity remain.
- Defaults: `linear_damp` ~1.25, `angular_damp` ~1.8 (web 6DOF jitter vs free axle spin).

## Engine
Default **GodotPhysics3D** (standard Godot 4.3 export). Jolt can be swapped later if a custom export template includes it.
