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
	# Horizontal bar of +
	_add_box(st, Vector3(arm * 2.0, size.y, thick * 2.0), Vector3.ZERO)
	# Vertical bar of +
	_add_box(st, Vector3(thick * 2.0, size.y, arm * 2.0), Vector3.ZERO)
	# End caps slightly flared (Technic axle tip feel)
	_add_box(st, Vector3(arm * 1.15, size.y * 0.04, arm * 1.15), Vector3(0, half_l - size.y * 0.02, 0))
	_add_box(st, Vector3(arm * 1.15, size.y * 0.04, arm * 1.15), Vector3(0, -half_l + size.y * 0.02, 0))
	st.generate_normals()
	return st.commit()

## Liftarm: rectangular beam with circular pin-hole indents along length.
static func _beam_mesh(size: Vector3, holes: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, size, Vector3.ZERO)
	var hole_r: float = minf(size.x, size.z) * 0.34
	var depth: float = size.z * 0.52
	var n: int = maxi(holes, 1)
	var span: float = size.y * (float(n - 1) / float(maxi(n, 2))) if n > 1 else 0.0
	var start_y: float = -span * 0.5
	var step: float = span / float(maxi(n - 1, 1)) if n > 1 else 0.0
	for i in range(n):
		var y: float = start_y + step * float(i) if n > 1 else 0.0
		# Darker "hole" rings on both Z faces (visual only)
		_add_ring_face(st, Vector3(0, y, size.z * 0.501), hole_r, hole_r * 0.55, 10, true)
		_add_ring_face(st, Vector3(0, y, -size.z * 0.501), hole_r, hole_r * 0.55, 10, false)
		# Thin tube through (suggests through-hole)
		_add_cylinder_shell(st, Vector3(0, y, 0), hole_r * 0.9, depth, 8, Vector3(1, 0, 0))
	st.generate_normals()
	return st.commit()

## Friction pin: stepped cylinder along Y.
static func _pin_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = minf(size.x, size.z) * 0.42
	var h: float = size.y
	# Two grip lobes + thin center waist
	_add_cylinder_y(st, r, h * 0.38, 10, Vector3(0, h * 0.28, 0))
	_add_cylinder_y(st, r * 0.78, h * 0.22, 10, Vector3.ZERO)
	_add_cylinder_y(st, r, h * 0.38, 10, Vector3(0, -h * 0.28, 0))
	# End stop discs
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

static func _gear_mesh(teeth: int, pitch_r: float, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: float = pitch_r * 1.28
	var root: float = pitch_r * 0.82
	var hub: float = pitch_r * 0.28
	var bore: float = pitch_r * 0.14
	var half_t: float = thickness * 0.5
	var n: int = maxi(teeth * 2, 16)
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		# Wider tooth flats (even indices = tooth tip)
		var r0: float = outer if (i % 2 == 0) else root
		var r1: float = outer if ((i + 1) % 2 == 0) else root
		_add_quad(st,
			Vector3(cos(a0) * r0, -half_t, sin(a0) * r0),
			Vector3(cos(a1) * r1, -half_t, sin(a1) * r1),
			Vector3(cos(a1) * r1, half_t, sin(a1) * r1),
			Vector3(cos(a0) * r0, half_t, sin(a0) * r0))
		_add_tri(st,
			Vector3(cos(a0) * r0, half_t, sin(a0) * r0),
			Vector3(cos(a1) * r1, half_t, sin(a1) * r1),
			Vector3(0, half_t, 0))
		_add_tri(st,
			Vector3(cos(a1) * r1, -half_t, sin(a1) * r1),
			Vector3(cos(a0) * r0, -half_t, sin(a0) * r0),
			Vector3(0, -half_t, 0))
	# Hub ring + axle bore wall
	var hn: int = 14
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
	st.generate_normals()
	return st.commit()

static func _wheel_mesh(radius: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = width * 0.5
	var tire: float = radius
	var rim: float = radius * 0.72
	var hub: float = radius * 0.26
	var bore: float = radius * 0.12
	var segs: int = 20
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		# Tire tread band
		_add_quad(st,
			Vector3(cos(a0) * tire, -half_w, sin(a0) * tire),
			Vector3(cos(a1) * tire, -half_w, sin(a1) * tire),
			Vector3(cos(a1) * tire, half_w, sin(a1) * tire),
			Vector3(cos(a0) * tire, half_w, sin(a0) * tire))
		# Sidewall tire → rim
		_add_quad(st,
			Vector3(cos(a0) * tire, half_w, sin(a0) * tire),
			Vector3(cos(a1) * tire, half_w, sin(a1) * tire),
			Vector3(cos(a1) * rim, half_w * 0.85, sin(a1) * rim),
			Vector3(cos(a0) * rim, half_w * 0.85, sin(a0) * rim))
		_add_quad(st,
			Vector3(cos(a1) * tire, -half_w, sin(a1) * tire),
			Vector3(cos(a0) * tire, -half_w, sin(a0) * tire),
			Vector3(cos(a0) * rim, -half_w * 0.85, sin(a0) * rim),
			Vector3(cos(a1) * rim, -half_w * 0.85, sin(a1) * rim))
		# Disc to hub
		_add_quad(st,
			Vector3(cos(a0) * rim, half_w * 0.5, sin(a0) * rim),
			Vector3(cos(a1) * rim, half_w * 0.5, sin(a1) * rim),
			Vector3(cos(a1) * hub, half_w * 0.45, sin(a1) * hub),
			Vector3(cos(a0) * hub, half_w * 0.45, sin(a0) * hub))
		_add_quad(st,
			Vector3(cos(a1) * rim, -half_w * 0.5, sin(a1) * rim),
			Vector3(cos(a0) * rim, -half_w * 0.5, sin(a0) * rim),
			Vector3(cos(a0) * hub, -half_w * 0.45, sin(a0) * hub),
			Vector3(cos(a1) * hub, -half_w * 0.45, sin(a1) * hub))
		# Hub barrel + bore
		_add_quad(st,
			Vector3(cos(a0) * hub, -half_w * 0.45, sin(a0) * hub),
			Vector3(cos(a1) * hub, -half_w * 0.45, sin(a1) * hub),
			Vector3(cos(a1) * hub, half_w * 0.45, sin(a1) * hub),
			Vector3(cos(a0) * hub, half_w * 0.45, sin(a0) * hub))
		_add_quad(st,
			Vector3(cos(a0) * bore, half_w * 0.45, sin(a0) * bore),
			Vector3(cos(a1) * bore, half_w * 0.45, sin(a1) * bore),
			Vector3(cos(a1) * bore, -half_w * 0.45, sin(a1) * bore),
			Vector3(cos(a0) * bore, -half_w * 0.45, sin(a0) * bore))
	st.generate_normals()
	return st.commit()

## Motor body + output axle stub + side mounts.
static func _motor_mesh(size: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, size, Vector3.ZERO)
	# Output axle stub (+Y)
	var stub_r: float = minf(size.x, size.z) * 0.12
	_add_cylinder_y(st, stub_r, size.y * 0.28, 8, Vector3(0, size.y * 0.5 + size.y * 0.1, 0))
	# Front grill plate
	_add_box(st, Vector3(size.x * 0.92, size.y * 0.08, size.z * 0.06), Vector3(0, size.y * 0.35, size.z * 0.5))
	st.generate_normals()
	return st.commit()

# --- helpers ---

static func _add_box(st: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var p := [
		center + Vector3(-hx, -hy, -hz),
		center + Vector3(hx, -hy, -hz),
		center + Vector3(hx, hy, -hz),
		center + Vector3(-hx, hy, -hz),
		center + Vector3(-hx, -hy, hz),
		center + Vector3(hx, -hy, hz),
		center + Vector3(hx, hy, hz),
		center + Vector3(-hx, hy, hz),
	]
	_add_quad(st, p[0], p[1], p[2], p[3])  # -Z
	_add_quad(st, p[5], p[4], p[7], p[6])  # +Z
	_add_quad(st, p[4], p[0], p[3], p[7])  # -X
	_add_quad(st, p[1], p[5], p[6], p[2])  # +X
	_add_quad(st, p[3], p[2], p[6], p[7])  # +Y
	_add_quad(st, p[4], p[5], p[1], p[0])  # -Y

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
		# outer wall
		_add_quad(st,
			Vector3(cos(a0) * outer, -half, sin(a0) * outer),
			Vector3(cos(a1) * outer, -half, sin(a1) * outer),
			Vector3(cos(a1) * outer, half, sin(a1) * outer),
			Vector3(cos(a0) * outer, half, sin(a0) * outer))
		# inner wall (axle bore)
		_add_quad(st,
			Vector3(cos(a0) * inner, half, sin(a0) * inner),
			Vector3(cos(a1) * inner, half, sin(a1) * inner),
			Vector3(cos(a1) * inner, -half, sin(a1) * inner),
			Vector3(cos(a0) * inner, -half, sin(a0) * inner))
		# top annulus
		_add_quad(st,
			Vector3(cos(a0) * inner, half, sin(a0) * inner),
			Vector3(cos(a0) * outer, half, sin(a0) * outer),
			Vector3(cos(a1) * outer, half, sin(a1) * outer),
			Vector3(cos(a1) * inner, half, sin(a1) * inner))
		# bottom annulus
		_add_quad(st,
			Vector3(cos(a0) * outer, -half, sin(a0) * outer),
			Vector3(cos(a0) * inner, -half, sin(a0) * inner),
			Vector3(cos(a1) * inner, -half, sin(a1) * inner),
			Vector3(cos(a1) * outer, -half, sin(a1) * outer))

static func _add_cylinder_shell(st: SurfaceTool, center: Vector3, radius: float, length: float, segs: int, axis: Vector3) -> void:
	# Thin cylinder along local Z through beam (axis ignored; uses Z for hole direction)
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
