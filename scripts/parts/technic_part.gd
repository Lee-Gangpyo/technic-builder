extends RigidBody3D
class_name TechnicPart
## A single Technic part: RigidBody3D + connectors + optional motor/gear metadata.

signal part_clicked(part: TechnicPart)

const SCALE := 100.0

var part_id: String = ""
var part_data: Dictionary = {}
var connectors: Array = []  ## Array of ConnectorData dictionaries with Node3D markers
var connector_nodes: Array[Marker3D] = []
var connections: Dictionary = {}  ## connector_id -> {other: TechnicPart, other_cid: String, joint: Joint3D}
var is_ghost: bool = false
var is_motor: bool = false
var is_gear: bool = false
var teeth: int = 0
var motor_enabled: bool = false
var target_rpm: float = 120.0
var max_torque: float = 0.15
var motor_lerp: float = 0.10
var motor_max_domega: float = 1.5

@onready var highlight: MeshInstance3D = null

func setup(data: Dictionary) -> void:
	part_data = data
	part_id = data.get("id", "")
	teeth = int(data.get("teeth", 0))
	is_gear = teeth > 0
	is_motor = data.get("category", "") == "motor"
	if is_motor:
		target_rpm = float(data.get("max_rpm", 200)) * 0.6
		max_torque = float(data.get("max_torque", 0.15))

	mass = max(float(data.get("mass", 0.01)) * SCALE, 0.05)
	# Stability for small assemblies on web
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 2
	collision_mask = 1 | 2
	can_sleep = true
	# Slightly higher linear damp reduces 6DOF positional jitter on web;
	# keep angular modest so hinge/gear spin is not over-killed.
	linear_damp = 1.25
	angular_damp = 1.8

	var mesh_i := PartMeshFactory.make_mesh(data)
	add_child(mesh_i)
	var col := PartMeshFactory.make_collision(data)
	add_child(col)
	_build_connectors(data)
	_add_highlight_ring()

func _build_connectors(data: Dictionary) -> void:
	connectors.clear()
	connector_nodes.clear()
	var list: Array = data.get("connectors", [])
	for c in list:
		var m := Marker3D.new()
		m.name = "conn_%s" % str(c.get("id", "x"))
		var pos: Array = c.get("pos", [0, 0, 0])
		m.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2])) * SCALE
		var axis: Array = c.get("axis", [0, 1, 0])
		var ax := Vector3(float(axis[0]), float(axis[1]), float(axis[2])).normalized()
		if ax.length_squared() > 0.01 and not ax.is_equal_approx(Vector3.UP):
			m.look_at(m.position + ax, Vector3.UP if abs(ax.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
		add_child(m)
		# small visual sphere
		var vis := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.12
		sph.height = 0.24
		vis.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _conn_color(str(c.get("type", "")))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.55
		vis.material_override = mat
		m.add_child(vis)
		connector_nodes.append(m)
		connectors.append({
			"id": str(c.get("id", "")),
			"type": str(c.get("type", "")),
			"node": m,
			"axis_local": ax,
			"occupied": false
		})

func _conn_color(t: String) -> Color:
	match t:
		"pin_hole": return Color(0.2, 0.6, 1.0, 0.55)
		"pin": return Color(0.2, 0.4, 1.0, 0.55)
		"axle": return Color(0.9, 0.9, 0.2, 0.55)
		"axle_hole": return Color(0.9, 0.6, 0.1, 0.55)
		_: return Color(0.5, 0.5, 0.5, 0.55)

func _add_highlight_ring() -> void:
	highlight = MeshInstance3D.new()
	highlight.name = "Highlight"
	var sph := SphereMesh.new()
	sph.radius = 1.1
	sph.height = 2.2
	highlight.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.6, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.material_override = mat
	highlight.visible = false
	add_child(highlight)

func set_selected(sel: bool) -> void:
	if highlight:
		highlight.visible = sel

func set_ghost(g: bool) -> void:
	is_ghost = g
	freeze = g
	collision_layer = 0 if g else 2
	collision_mask = 0 if g else (1 | 2)
	var mesh_i := get_node_or_null("Mesh") as MeshInstance3D
	if mesh_i and mesh_i.material_override:
		var mat := mesh_i.material_override.duplicate() as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.45 if g else 1.0
		mesh_i.material_override = mat

func get_connector_global(cid: String) -> Transform3D:
	for c in connectors:
		if c["id"] == cid:
			return (c["node"] as Marker3D).global_transform
	return global_transform

func get_free_connectors() -> Array:
	var out: Array = []
	for c in connectors:
		if not c["occupied"]:
			out.append(c)
	return out

func mark_connected(cid: String, occupied: bool) -> void:
	for c in connectors:
		if c["id"] == cid:
			c["occupied"] = occupied
			break

func world_axis_of(cid: String) -> Vector3:
	for c in connectors:
		if c["id"] == cid:
			var local_ax: Vector3 = c["axis_local"]
			return (global_transform.basis * local_ax).normalized()
	return global_transform.basis.y

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Always damp explosive solver spikes (web/iPad stability)
	if state.angular_velocity.length() > 30.0:
		state.angular_velocity = state.angular_velocity.limit_length(30.0)
	if state.linear_velocity.length() > 50.0:
		state.linear_velocity = state.linear_velocity.limit_length(50.0)

	if not is_motor or not motor_enabled:
		return
	var axis := (global_transform.basis * Vector3.UP).normalized()
	var target_omega: float = target_rpm * TAU / 60.0
	# Gentle omega drive so GearConstraint can keep motor→gear→wheel ratio
	# without fighting a hard lerp every integrate tick (web single-thread).
	var current: float = state.angular_velocity.dot(axis)
	var blended: float = lerpf(current, target_omega, motor_lerp)
	blended = clampf(blended, current - motor_max_domega, current + motor_max_domega)
	var tangential := state.angular_velocity - axis * current
	state.angular_velocity = tangential * 0.92 + axis * blended
