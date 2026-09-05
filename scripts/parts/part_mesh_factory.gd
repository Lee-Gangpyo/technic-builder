extends RefCounted
class_name PartMeshFactory
## Procedural Technic-like low-poly meshes — no official LEGO assets.

const SCALE: float = 100.0  ## m → cm

static func make_mesh(data: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var kind: String = str(data.get("mesh", "box"))
	var color := Color(str(data.get("color", "#CCCCCC")))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.15 if kind in ["axle", "pin", "bush"] else 0.05
	mi.material_override = mat

	match kind:
		"beam":
			var holes: int = int(data.get("holes", 5))
			mi.mesh = _beam_mesh(_size(data), holes)
		"axle":
			mi.mesh = _axle_mesh(_size(data))
		"pin":
			mi.mesh = _pin_mesh(_size(data))
		"bush":
			mi.mesh = _bush_mesh(_size(data))
		"gear":
			var teeth: int = int(data.get("teeth", 8))
			var pr: float = float(data.get("pitch_radius_m", 0.0064)) * SCALE
			var gm: ArrayMesh = _gear_mesh(teeth, pr, _size(data).y)
			if gm != null and gm.get_surface_count() > 0:
				mi.mesh = gm
			else:
				mi.mesh = _cylinder_mesh(pr * 1.15, _size(data).y, maxi(teeth * 2, 12))
				mi.rotation_degrees.x = 90.0
		"wheel":
			var rad: float = float(data.get("radius_m", 0.012)) * SCALE
			var wm: ArrayMesh = _wheel_mesh(rad, _size(data).y)
			if wm != null and wm.get_surface_count() > 0:
				mi.mesh = wm
			else:
				mi.mesh = _cylinder_mesh(rad, _size(data).y, 16)
				mi.rotation_degrees.x = 90.0
		"motor":
			mi.mesh = _motor_mesh(_size(data))
		_:
			mi.mesh = _box_mesh(_size(data))
	return mi

static func make_collision(data: Dictionary) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var kind: String = str(data.get("mesh", "box"))
	var s: Vector3 = _size(data)
	match kind:
		"axle", "pin", "bush":
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(s.x, s.z) * 0.5
			cyl.height = s.y
			cs.shape = cyl
			cs.rotation_degrees.x = 90.0
		"gear", "wheel":
			var cyl2 := CylinderShape3D.new()
			cyl2.radius = maxf(s.x, s.z) * 0.5
			cyl2.height = s.y
			cs.shape = cyl2
			cs.rotation_degrees.x = 90.0
		_:
			var box := BoxShape3D.new()
			box.size = s
			cs.shape = box
	return cs

static func _size(data: Dictionary) -> Vector3:
	var sm: Variant = data.get("size_m", {"x": 0.01, "y": 0.01, "z": 0.01})
	var d: Dictionary = sm as Dictionary
	return Vector3(float(d.x), float(d.y), float(d.z)) * SCALE

static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func _cylinder_mesh(radius: float, height: float, sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	return m

## Technic axle: + cross section extruded along Y (length).
static func _axle_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_l: float = size.y * 0.5
	var arm: float = minf(size.x, size.z) * 0.48
	var thick: float = arm * 0.38
	_add_box(st, Vector3(arm * 2.0, size.y, thick * 2.0), Vector3.ZERO)
	_add_box(st, Vector3(thick * 2.0, size.y, arm * 2.0), Vector3.ZERO)
	_add_box(st, Vector3(arm * 1.15, size.y * 0.04, arm * 1.15), Vector3(0, half_l - size.y * 0.02, 0))
	_add_box(st, Vector3(arm * 1.15, size.y * 0.04, arm * 1.15), Vector3(0, -half_l + size.y * 0.02, 0))
	st.generate_normals()
	return st.commit()

## Liftarm: real circular through-holes along length (Z). Hole count + Y spacing unchanged.
static func _beam_mesh(size: Vector3, holes: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var hole_r: float = minf(size.x, size.z) * 0.34
	var n: int = maxi(holes, 1)
	# KEEP spacing formula — aligned to 8 mm grid via size.y
	var span: float = size.y * (float(n - 1) / float(maxi(n, 2))) if n > 1 else 0.0
	var start_y: float = -span * 0.5
	var step: float = span / float(maxi(n - 1, 1)) if n > 1 else 0.0
	var hole_ys: Array = []
	for i in range(n):
		var y: float = start_y + step * float(i) if n > 1 else 0.0
		hole_ys.append(y)

	var segs: int = 12
	# ±X side walls
	_add_quad(st,
		Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz),
		Vector3(-hx, hy, hz), Vector3(-hx, hy, -hz))
	_add_quad(st,
		Vector3(hx, -hy, -hz), Vector3(hx, hy, -hz),
		Vector3(hx, hy, hz), Vector3(hx, -hy, hz))

	# Subtle ±Y end chamfer
	var ch: float = minf(minf(size.x, size.z) * 0.08, hx * 0.35)
	_add_quad(st,
		Vector3(-hx + ch, hy, -hz + ch), Vector3(hx - ch, hy, -hz + ch),
		Vector3(hx - ch, hy, hz - ch), Vector3(-hx + ch, hy, hz - ch))
	_add_quad(st,
		Vector3(-hx, hy - ch, -hz), Vector3(hx, hy - ch, -hz),
		Vector3(hx - ch, hy, -hz + ch), Vector3(-hx + ch, hy, -hz + ch))
	_add_quad(st,
		Vector3(hx, hy - ch, hz), Vector3(-hx, hy - ch, hz),
		Vector3(-hx + ch, hy, hz - ch), Vector3(hx - ch, hy, hz - ch))
	_add_quad(st,
		Vector3(-hx, hy - ch, hz), Vector3(-hx, hy - ch, -hz),
		Vector3(-hx + ch, hy, -hz + ch), Vector3(-hx + ch, hy, hz - ch))
	_add_quad(st,
		Vector3(hx, hy - ch, -hz), Vector3(hx, hy - ch, hz),
		Vector3(hx - ch, hy, hz - ch), Vector3(hx - ch, hy, -hz + ch))
	_add_quad(st,
		Vector3(-hx + ch, -hy, hz - ch), Vector3(hx - ch, -hy, hz - ch),
		Vector3(hx - ch, -hy, -hz + ch), Vector3(-hx + ch, -hy, -hz + ch))
	_add_quad(st,
		Vector3(-hx, -hy + ch, hz), Vector3(hx, -hy + ch, hz),
		Vector3(hx - ch, -hy, hz - ch), Vector3(-hx + ch, -hy, hz - ch))
	_add_quad(st,
		Vector3(hx, -hy + ch, -hz), Vector3(-hx, -hy + ch, -hz),
		Vector3(-hx + ch, -hy, -hz + ch), Vector3(hx - ch, -hy, -hz + ch))
	_add_quad(st,
		Vector3(-hx, -hy + ch, -hz), Vector3(-hx, -hy + ch, hz),
		Vector3(-hx + ch, -hy, hz - ch), Vector3(-hx + ch, -hy, -hz + ch))
	_add_quad(st,
		Vector3(hx, -hy + ch, hz), Vector3(hx, -hy + ch, -hz),
		Vector3(hx - ch, -hy, -hz + ch), Vector3(hx - ch, -hy, hz - ch))

	for hi in range(n):
		var cy: float = float(hole_ys[hi])
		var y_lo: float = -hy if hi == 0 else (float(hole_ys[hi - 1]) + cy) * 0.5
		var y_hi: float = hy if hi == n - 1 else (cy + float(hole_ys[hi + 1])) * 0.5
		y_lo = minf(y_lo, cy - hole_r * 0.15)
		y_hi = maxf(y_hi, cy + hole_r * 0.15)

		for si in range(segs):
			var a0: float = TAU * float(si) / float(segs)
			var a1: float = TAU * float(si + 1) / float(segs)
			var ix0: float = cos(a0) * hole_r
			var iy0: float = cy + sin(a0) * hole_r
			var ix1: float = cos(a1) * hole_r
			var iy1: float = cy + sin(a1) * hole_r
			_add_quad(st,
				Vector3(ix0, iy0, -hz), Vector3(ix1, iy1, -hz),
				Vector3(ix1, iy1, hz), Vector3(ix0, iy0, hz))

		_add_beam_z_face_with_hole(st, hx, hz, cy, hole_r, y_lo, y_hi, segs, true)
		_add_beam_z_face_with_hole(st, hx, hz, cy, hole_r, y_lo, y_hi, segs, false)

	st.generate_normals()
	return st.commit()

static func _add_beam_z_face_with_hole(
	st: SurfaceTool, hx: float, hz: float, cy: float, hole_r: float,
	y_lo: float, y_hi: float, segs: int, facing_pos_z: bool
) -> void:
	var z: float = hz if facing_pos_z else -hz
	for si in range(segs):
		var a0: float = TAU * float(si) / float(segs)
		var a1: float = TAU * float(si + 1) / float(segs)
		var i0 := Vector3(cos(a0) * hole_r, cy + sin(a0) * hole_r, z)
		var i1 := Vector3(cos(a1) * hole_r, cy + sin(a1) * hole_r, z)
		var o0_2 := _ray_rect_hit(0.0, cy, cos(a0), sin(a0), -hx, hx, y_lo, y_hi)
		var o1_2 := _ray_rect_hit(0.0, cy, cos(a1), sin(a1), -hx, hx, y_lo, y_hi)
		var o0 := Vector3(o0_2.x, o0_2.y, z)
		var o1 := Vector3(o1_2.x, o1_2.y, z)
		if facing_pos_z:
			_add_quad(st, i0, o0, o1, i1)
		else:
			_add_quad(st, i1, o1, o0, i0)

static func _ray_rect_hit(
	ox: float, oy: float, dx: float, dy: float,
	xmin: float, xmax: float, ymin: float, ymax: float
) -> Vector2:
	var t: float = 1.0e9
	if absf(dx) > 1.0e-8:
		var tx: float = (xmax - ox) / dx if dx > 0.0 else (xmin - ox) / dx
		if tx > 0.0:
			t = minf(t, tx)
	if absf(dy) > 1.0e-8:
		var ty: float = (ymax - oy) / dy if dy > 0.0 else (ymin - oy) / dy
		if ty > 0.0:
			t = minf(t, ty)
	if t > 1.0e8:
		t = 1.0
	return Vector2(ox + dx * t, oy + dy * t)

## Friction pin: stepped cylinder along Y.
static func _pin_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = minf(size.x, size.z) * 0.42
	var h: float = size.y
	_add_cylinder_y(st, r, h * 0.38, 10, Vector3(0, h * 0.28, 0))
	_add_cylinder_y(st, r * 0.78, h * 0.22, 10, Vector3.ZERO)
	_add_cylinder_y(st, r, h * 0.38, 10, Vector3(0, -h * 0.28, 0))
	_add_cylinder_y(st, r * 1.15, h * 0.06, 10, Vector3(0, h * 0.47, 0))
	_add_cylinder_y(st, r * 1.15, h * 0.06, 10, Vector3(0, -h * 0.47, 0))
	st.generate_normals()
	return st.commit()

## Bushing: short fat cylinder with axle bore.
static func _bush_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: float = minf(size.x, size.z) * 0.48
	var inner: float = outer * 0.42
	var h: float = size.y
	_add_cylinder_shell_y(st, outer, inner, h, 12)
	st.generate_normals()
	return st.commit()

## Spur gear: trapezoidal teeth (tip flat + flank + root), hub ring, axle bore.
## outer ≈ pitch_r * 1.25 (multiplier in 1.22–1.28 range).
static func _gear_mesh(teeth: int, pitch_r: float, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_teeth: int = maxi(teeth, 3)
	# Tip radius multiplier 1.25 ∈ [1.22, 1.28]
	var outer: float = pitch_r * 1.25
	var root: float = pitch_r * 0.78
	var hub: float = pitch_r * 0.32
	var bore: float = pitch_r * 0.15
	var half_t: float = thickness * 0.5
	var pitch: float = TAU / float(n_teeth)
	var tip_half: float = pitch * 0.22
	var root_half: float = pitch * 0.28

	for i in range(n_teeth):
		var mid: float = pitch * (float(i) + 0.5)
		var a_r0: float = mid - root_half
		var a_t0: float = mid - tip_half
		var a_t1: float = mid + tip_half
		var a_r1: float = mid + root_half
		var angs: Array = [a_r0, a_t0, a_t1, a_r1]
		var rads: Array = [root, outer, outer, root]
		var a_next: float = mid + pitch - root_half
		for k in range(3):
			_add_gear_sector(st, float(angs[k]), float(angs[k + 1]), float(rads[k]), float(rads[k + 1]), half_t, hub)
		_add_gear_sector(st, a_r1, a_next, root, root, half_t, hub)

	var hn: int = 16
	for i in range(hn):
		var b0: float = TAU * float(i) / float(hn)
		var b1: float = TAU * float(i + 1) / float(hn)
		_add_quad(st,
			Vector3(cos(b0) * hub, -half_t, sin(b0) * hub),
			Vector3(cos(b1) * hub, -half_t, sin(b1) * hub),
			Vector3(cos(b1) * hub, half_t, sin(b1) * hub),
			Vector3(cos(b0) * hub, half_t, sin(b0) * hub))
		_add_quad(st,
			Vector3(cos(b0) * bore, half_t, sin(b0) * bore),
			Vector3(cos(b1) * bore, half_t, sin(b1) * bore),
			Vector3(cos(b1) * bore, -half_t, sin(b1) * bore),
			Vector3(cos(b0) * bore, -half_t, sin(b0) * bore))
		_add_quad(st,
			Vector3(cos(b0) * bore, half_t, sin(b0) * bore),
			Vector3(cos(b0) * hub, half_t, sin(b0) * hub),
			Vector3(cos(b1) * hub, half_t, sin(b1) * hub),
			Vector3(cos(b1) * bore, half_t, sin(b1) * bore))
		_add_quad(st,
			Vector3(cos(b0) * hub, -half_t, sin(b0) * hub),
			Vector3(cos(b0) * bore, -half_t, sin(b0) * bore),
			Vector3(cos(b1) * bore, -half_t, sin(b1) * bore),
			Vector3(cos(b1) * hub, -half_t, sin(b1) * hub))
	st.generate_normals()
	return st.commit()

static func _add_gear_sector(
	st: SurfaceTool, a0: float, a1: float, r0: float, r1: float, half_t: float, hub: float
) -> void:
	var p0m := Vector3(cos(a0) * r0, -half_t, sin(a0) * r0)
	var p1m := Vector3(cos(a1) * r1, -half_t, sin(a1) * r1)
	var p1p := Vector3(cos(a1) * r1, half_t, sin(a1) * r1)
	var p0p := Vector3(cos(a0) * r0, half_t, sin(a0) * r0)
	_add_quad(st, p0m, p1m, p1p, p0p)
	_add_quad(st,
		p0p, p1p,
		Vector3(cos(a1) * hub, half_t, sin(a1) * hub),
		Vector3(cos(a0) * hub, half_t, sin(a0) * hub))
	_add_quad(st,
		p1m, p0m,
		Vector3(cos(a0) * hub, -half_t, sin(a0) * hub),
		Vector3(cos(a1) * hub, -half_t, sin(a1) * hub))

## Wheel: stronger tire/rim step, tread grooves, clear hub + bore. Tire OD = radius.
static func _wheel_mesh(radius: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = width * 0.5
	var tire: float = radius
	var groove: float = radius * 0.94
	var rim: float = radius * 0.58
	var hub: float = radius * 0.28
	var bore: float = radius * 0.13
	var segs: int = 24
	var yw0: float = -half_w
	var yw1: float = -half_w * 0.35
	var yw2: float = half_w * 0.35
	var yw3: float = half_w
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0x: float = cos(a0)
		var s0z: float = sin(a0)
		var c1x: float = cos(a1)
		var s1z: float = sin(a1)
		_add_quad(st,
			Vector3(c0x * tire, yw0, s0z * tire), Vector3(c1x * tire, yw0, s1z * tire),
			Vector3(c1x * tire, yw1, s1z * tire), Vector3(c0x * tire, yw1, s0z * tire))
		_add_quad(st,
			Vector3(c0x * tire, yw1, s0z * tire), Vector3(c1x * tire, yw1, s1z * tire),
			Vector3(c1x * groove, yw1, s1z * groove), Vector3(c0x * groove, yw1, s0z * groove))
		_add_quad(st,
			Vector3(c0x * groove, yw1, s0z * groove), Vector3(c1x * groove, yw1, s1z * groove),
			Vector3(c1x * groove, yw2, s1z * groove), Vector3(c0x * groove, yw2, s0z * groove))
		_add_quad(st,
			Vector3(c0x * groove, yw2, s0z * groove), Vector3(c1x * groove, yw2, s1z * groove),
			Vector3(c1x * tire, yw2, s1z * tire), Vector3(c0x * tire, yw2, s0z * tire))
		_add_quad(st,
			Vector3(c0x * tire, yw2, s0z * tire), Vector3(c1x * tire, yw2, s1z * tire),
			Vector3(c1x * tire, yw3, s1z * tire), Vector3(c0x * tire, yw3, s0z * tire))
		_add_quad(st,
			Vector3(c0x * tire, yw3, s0z * tire), Vector3(c1x * tire, yw3, s1z * tire),
			Vector3(c1x * rim, half_w * 0.72, s1z * rim), Vector3(c0x * rim, half_w * 0.72, s0z * rim))
		_add_quad(st,
			Vector3(c1x * tire, yw0, s1z * tire), Vector3(c0x * tire, yw0, s0z * tire),
			Vector3(c0x * rim, -half_w * 0.72, s0z * rim), Vector3(c1x * rim, -half_w * 0.72, s1z * rim))
		_add_quad(st,
			Vector3(c0x * rim, half_w * 0.72, s0z * rim), Vector3(c1x * rim, half_w * 0.72, s1z * rim),
			Vector3(c1x * hub, half_w * 0.5, s1z * hub), Vector3(c0x * hub, half_w * 0.5, s0z * hub))
		_add_quad(st,
			Vector3(c1x * rim, -half_w * 0.72, s1z * rim), Vector3(c0x * rim, -half_w * 0.72, s0z * rim),
			Vector3(c0x * hub, -half_w * 0.5, s0z * hub), Vector3(c1x * hub, -half_w * 0.5, s1z * hub))
		_add_quad(st,
			Vector3(c0x * hub, -half_w * 0.5, s0z * hub), Vector3(c1x * hub, -half_w * 0.5, s1z * hub),
			Vector3(c1x * hub, half_w * 0.5, s1z * hub), Vector3(c0x * hub, half_w * 0.5, s0z * hub))
		_add_quad(st,
			Vector3(c0x * bore, half_w * 0.5, s0z * bore), Vector3(c1x * bore, half_w * 0.5, s1z * bore),
			Vector3(c1x * bore, -half_w * 0.5, s1z * bore), Vector3(c0x * bore, -half_w * 0.5, s0z * bore))
		_add_quad(st,
			Vector3(c0x * bore, half_w * 0.5, s0z * bore), Vector3(c0x * hub, half_w * 0.5, s0z * hub),
			Vector3(c1x * hub, half_w * 0.5, s1z * hub), Vector3(c1x * bore, half_w * 0.5, s1z * bore))
		_add_quad(st,
			Vector3(c0x * hub, -half_w * 0.5, s0z * hub), Vector3(c0x * bore, -half_w * 0.5, s0z * bore),
			Vector3(c1x * bore, -half_w * 0.5, s1z * bore), Vector3(c1x * hub, -half_w * 0.5, s1z * hub))
	st.generate_normals()
	return st.commit()

## Motor: body+cap within size; + cross axle stub; mounts at (±0.8,-1.6,0); front grill.
static func _motor_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var split_y: float = -hy + size.y * 0.72
	var body_h: float = split_y - (-hy)
	var body_cy: float = (-hy + split_y) * 0.5
	_add_box(st, Vector3(size.x * 0.98, body_h, size.z * 0.98), Vector3(0, body_cy, 0))
	var cap_h: float = hy - split_y
	var cap_cy: float = (split_y + hy) * 0.5
	_add_box(st, Vector3(size.x * 0.90, cap_h, size.z * 0.90), Vector3(0, cap_cy, 0))
	_add_box(st, Vector3(size.x * 0.96, size.y * 0.04, size.z * 0.96), Vector3(0, split_y, 0))

	var stub_y: float = minf(2.0, hy - size.y * 0.02)
	var arm: float = minf(size.x, size.z) * 0.14
	var thick: float = arm * 0.38
	var stub_len: float = size.y * 0.18
	var stub_cy: float = stub_y - stub_len * 0.5
	_add_box(st, Vector3(arm * 2.0, stub_len, thick * 2.0), Vector3(0, stub_cy, 0))
	_add_box(st, Vector3(thick * 2.0, stub_len, arm * 2.0), Vector3(0, stub_cy, 0))

	var mount_y: float = maxf(-1.6, -hy + 0.05)
	var mount_r: float = 0.28
	var mount_depth: float = size.z * 0.55
	for sx in [-0.8, 0.8]:
		var mx: float = clampf(sx, -hx + mount_r, hx - mount_r)
		_add_ring_face(st, Vector3(mx, mount_y, hz * 0.99), mount_r, mount_r * 0.45, 10, true)
		_add_ring_face(st, Vector3(mx, mount_y, -hz * 0.99), mount_r, mount_r * 0.45, 10, false)
		_add_cylinder_shell(st, Vector3(mx, mount_y, 0), mount_r * 0.85, mount_depth, 8, Vector3(1, 0, 0))

	var grill_z: float = hz * 0.98
	var grill_y0: float = hy * 0.15
	var grill_y1: float = hy * 0.55
	_add_box(st, Vector3(size.x * 0.88, size.y * 0.06, size.z * 0.04), Vector3(0, grill_y1, grill_z * 0.5))
	for gi in range(4):
		var gy: float = grill_y0 + (grill_y1 - grill_y0) * (float(gi) + 0.5) / 4.0
		_add_box(st, Vector3(size.x * 0.70, size.y * 0.025, size.z * 0.03), Vector3(0, gy, grill_z * 0.55))

	st.generate_normals()
	return st.commit()

# --- helpers ---

static func _add_box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var bx := size.x * 0.5
	var by := size.y * 0.5
	var bz := size.z * 0.5
	var p := [
		center + Vector3(-bx, -by, -bz),
		center + Vector3(bx, -by, -bz),
		center + Vector3(bx, by, -bz),
		center + Vector3(-bx, by, -bz),
		center + Vector3(-bx, -by, bz),
		center + Vector3(bx, -by, bz),
		center + Vector3(bx, by, bz),
		center + Vector3(-bx, by, bz),
	]
	_add_quad(st, p[0], p[1], p[2], p[3])
	_add_quad(st, p[5], p[4], p[7], p[6])
	_add_quad(st, p[4], p[0], p[3], p[7])
	_add_quad(st, p[1], p[5], p[6], p[2])
	_add_quad(st, p[3], p[2], p[6], p[7])
	_add_quad(st, p[4], p[5], p[1], p[0])

static func _add_cylinder_y(st: SurfaceTool, radius: float, height: float, segs: int, center: Vector3) -> void:
	var half: float = height * 0.5
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var x0 := cos(a0) * radius
		var z0 := sin(a0) * radius
		var x1 := cos(a1) * radius
		var z1 := sin(a1) * radius
		_add_quad(st,
			center + Vector3(x0, -half, z0),
			center + Vector3(x1, -half, z1),
			center + Vector3(x1, half, z1),
			center + Vector3(x0, half, z0))
		_add_tri(st, center + Vector3(0, half, 0), center + Vector3(x0, half, z0), center + Vector3(x1, half, z1))
		_add_tri(st, center + Vector3(0, -half, 0), center + Vector3(x1, -half, z1), center + Vector3(x0, -half, z0))

static func _add_cylinder_shell_y(st: SurfaceTool, outer: float, inner: float, height: float, segs: int) -> void:
	var half: float = height * 0.5
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		_add_quad(st,
			Vector3(cos(a0) * outer, -half, sin(a0) * outer),
			Vector3(cos(a1) * outer, -half, sin(a1) * outer),
			Vector3(cos(a1) * outer, half, sin(a1) * outer),
			Vector3(cos(a0) * outer, half, sin(a0) * outer))
		_add_quad(st,
			Vector3(cos(a0) * inner, half, sin(a0) * inner),
			Vector3(cos(a1) * inner, half, sin(a1) * inner),
			Vector3(cos(a1) * inner, -half, sin(a1) * inner),
			Vector3(cos(a0) * inner, -half, sin(a0) * inner))
		_add_quad(st,
			Vector3(cos(a0) * inner, half, sin(a0) * inner),
			Vector3(cos(a0) * outer, half, sin(a0) * outer),
			Vector3(cos(a1) * outer, half, sin(a1) * outer),
			Vector3(cos(a1) * inner, half, sin(a1) * inner))
		_add_quad(st,
			Vector3(cos(a0) * outer, -half, sin(a0) * outer),
			Vector3(cos(a0) * inner, -half, sin(a0) * inner),
			Vector3(cos(a1) * inner, -half, sin(a1) * inner),
			Vector3(cos(a1) * outer, -half, sin(a1) * outer))

static func _add_cylinder_shell(st: SurfaceTool, center: Vector3, radius: float, length: float, segs: int, axis: Vector3) -> void:
	var half: float = length * 0.5
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		_add_quad(st,
			center + Vector3(cos(a0) * radius, sin(a0) * radius, -half),
			center + Vector3(cos(a1) * radius, sin(a1) * radius, -half),
			center + Vector3(cos(a1) * radius, sin(a1) * radius, half),
			center + Vector3(cos(a0) * radius, sin(a0) * radius, half))

static func _add_ring_face(st: SurfaceTool, center: Vector3, outer: float, inner: float, segs: int, facing_pos_z: bool) -> void:
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var o0 := center + Vector3(cos(a0) * outer, sin(a0) * outer, 0)
		var o1 := center + Vector3(cos(a1) * outer, sin(a1) * outer, 0)
		var i0 := center + Vector3(cos(a0) * inner, sin(a0) * inner, 0)
		var i1 := center + Vector3(cos(a1) * inner, sin(a1) * inner, 0)
		if facing_pos_z:
			_add_quad(st, i0, o0, o1, i1)
		else:
			_add_quad(st, i1, o1, o0, i0)

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_tri(st, a, b, c)
	_add_tri(st, a, c, d)
