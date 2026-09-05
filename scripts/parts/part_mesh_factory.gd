extends RefCounted
class_name PartMeshFactory
## Procedural placeholder meshes — no official LEGO assets.

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
			mi.mesh = _box_mesh(_size(data))
		"axle":
			mi.mesh = _cylinder_mesh(0.15, _size(data).y, 8)
			mi.rotation_degrees.x = 90.0
		"pin":
			mi.mesh = _cylinder_mesh(0.22, _size(data).y, 10)
			mi.rotation_degrees.x = 90.0
		"bush":
			mi.mesh = _cylinder_mesh(0.32, _size(data).y, 12)
			mi.rotation_degrees.x = 90.0
		"gear":
			var teeth: int = int(data.get("teeth", 8))
			var pr: float = float(data.get("pitch_radius_m", 0.0064)) * SCALE
			# Procedural tooth silhouette when possible; cylinder fallback keeps headless/web stable.
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
			mi.mesh = _box_mesh(_size(data))
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

static func _gear_mesh(teeth: int, pitch_r: float, thickness: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer: float = pitch_r * 1.15
	var hub: float = pitch_r * 0.25
	var half_t: float = thickness * 0.5
	var n: int = maxi(teeth * 2, 16)
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var r0: float = outer if (i % 2 == 0) else pitch_r * 0.92
		var r1: float = outer if ((i + 1) % 2 == 0) else pitch_r * 0.92
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
	var hn: int = 12
	for i in range(hn):
		var b0: float = TAU * float(i) / float(hn)
		var b1: float = TAU * float(i + 1) / float(hn)
		_add_quad(st,
			Vector3(cos(b0) * hub, -half_t, sin(b0) * hub),
			Vector3(cos(b1) * hub, -half_t, sin(b1) * hub),
			Vector3(cos(b1) * hub, half_t, sin(b1) * hub),
			Vector3(cos(b0) * hub, half_t, sin(b0) * hub))
	st.generate_normals()
	return st.commit()

static func _wheel_mesh(radius: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w: float = width * 0.5
	var tire: float = radius
	var hub: float = radius * 0.3
	var segs: int = 20
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		_add_quad(st,
			Vector3(cos(a0) * tire, -half_w, sin(a0) * tire),
			Vector3(cos(a1) * tire, -half_w, sin(a1) * tire),
			Vector3(cos(a1) * tire, half_w, sin(a1) * tire),
			Vector3(cos(a0) * tire, half_w, sin(a0) * tire))
		_add_tri(st, Vector3(cos(a0) * tire, half_w, sin(a0) * tire), Vector3(cos(a1) * tire, half_w, sin(a1) * tire), Vector3(0, half_w, 0))
		_add_tri(st, Vector3(cos(a1) * tire, -half_w, sin(a1) * tire), Vector3(cos(a0) * tire, -half_w, sin(a0) * tire), Vector3(0, -half_w, 0))
		_add_quad(st,
			Vector3(cos(a0) * hub, -half_w * 0.6, sin(a0) * hub),
			Vector3(cos(a1) * hub, -half_w * 0.6, sin(a1) * hub),
			Vector3(cos(a1) * hub, half_w * 0.6, sin(a1) * hub),
			Vector3(cos(a0) * hub, half_w * 0.6, sin(a0) * hub))
	st.generate_normals()
	return st.commit()

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_tri(st, a, b, c)
	_add_tri(st, a, c, d)
