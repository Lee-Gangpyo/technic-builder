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

## Gear mesh solver choice
We use a **soft velocity constraint** (`GearConstraint`) each physics tick:

```
teeth_a * ω_a + teeth_b * ω_b = 0
```

Correction is split by mass proxy and applied to angular velocity about each gear’s local Y axis.

### Why not alternatives?
1. **Hinge motor ratio / custom Jacobian** — accurate but heavy to maintain across Godot versions and awkward with multiple meshes.
2. **Animated kinematic gears** — breaks Drive-mode RigidBody interaction with the ground.
3. **Full contact tooth simulation** — unstable at game scale, expensive on mobile/web.

The soft constraint is **stable-first**: it keeps opposite rotation and tooth ratio visible for demos while remaining cheap for HTML5/iPad exports. Known limitation: under large external shocks the ratio can slip briefly until the constraint catches up; increase `stiffness` carefully to avoid energy injection.

## Motors
`TechnicPart._integrate_forces` applies torque about the motor output axis toward a target RPM when `motor_enabled` is true (Drive mode + UI/keyboard).

## Engine
Default **GodotPhysics3D** (standard Godot 4.3 export). Jolt can be swapped later if a custom export template includes it.
