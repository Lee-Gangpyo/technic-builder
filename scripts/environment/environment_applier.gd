extends Node
## Applies environment presets from EnvironmentCatalog to the Main scene.

signal environment_changed(id: String)

@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var sun_path: NodePath = NodePath("../Sun")
@export var ground_path: NodePath = NodePath("../World/Ground")
@export var ramp_path: NodePath = NodePath("../World/Ramp")
@export var env_props_path: NodePath = NodePath("../World/EnvProps")

var _current_id: String = ""

func apply(id: String) -> void:
	var data: Dictionary = EnvironmentCatalog.get_environment(id)
	if data.is_empty():
		push_warning("EnvironmentApplier: unknown environment id '%s'" % id)
		return

	_apply_world_environment(data)
	_apply_sun(data)
	_apply_ground(data)
	_apply_ramp(data)
	_clear_env_props()

	_current_id = id
	environment_changed.emit(id)
	print("EnvironmentApplier: applied '%s'" % id)

func current_id() -> String:
	return _current_id

func _color4(arr: Variant, fallback: Color = Color.WHITE) -> Color:
	if typeof(arr) != TYPE_ARRAY:
		return fallback
	var a: Array = arr
	var r := float(a[0]) if a.size() > 0 else fallback.r
	var g := float(a[1]) if a.size() > 1 else fallback.g
	var b := float(a[2]) if a.size() > 2 else fallback.b
	var al := float(a[3]) if a.size() > 3 else 1.0
	return Color(r, g, b, al)

func _apply_world_environment(data: Dictionary) -> void:
	var we := get_node_or_null(world_environment_path) as WorldEnvironment
	if we == null or we.environment == null:
		push_warning("EnvironmentApplier: WorldEnvironment missing")
		return
	var env: Environment = we.environment
	var sky: Dictionary = data.get("sky", {})
	var mode := str(sky.get("mode", "color"))
	if mode == "color":
		env.background_mode = Environment.BG_COLOR
		env.background_color = _color4(sky.get("color", [0.55, 0.72, 0.92, 1.0]))
	var ambient: Dictionary = data.get("ambient", {})
	var src := str(ambient.get("source", "color"))
	if src == "color":
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _color4(ambient.get("color", [0.85, 0.88, 0.95, 1.0]))
	env.ambient_light_energy = float(ambient.get("energy", 0.55))
	var fog: Dictionary = data.get("fog", {})
	env.fog_enabled = bool(fog.get("enabled", false))
	if env.fog_enabled:
		env.fog_light_color = _color4(fog.get("color", [0.7, 0.75, 0.8, 1.0]))
		env.fog_density = float(fog.get("density", 0.0))

func _apply_sun(data: Dictionary) -> void:
	var sun := get_node_or_null(sun_path) as DirectionalLight3D
	if sun == null:
		push_warning("EnvironmentApplier: Sun missing")
		return
	var sun_data: Dictionary = data.get("sun", {})
	sun.light_energy = float(sun_data.get("energy", 1.0))
	sun.light_color = _color4(sun_data.get("color", [1.0, 1.0, 1.0, 1.0]))
	sun.shadow_enabled = bool(sun_data.get("shadows", true))
	var rot: Variant = sun_data.get("rotation_deg", [-45.0, 35.0, 0.0])
	if typeof(rot) == TYPE_ARRAY and (rot as Array).size() >= 3:
		var r: Array = rot
		sun.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))

func _apply_ground(data: Dictionary) -> void:
	var ground := get_node_or_null(ground_path) as Node
	if ground == null:
		push_warning("EnvironmentApplier: Ground missing")
		return
	var mesh := ground.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var ground_data: Dictionary = data.get("ground", {})
	var albedo := _color4(ground_data.get("albedo", [0.35, 0.55, 0.35, 1.0]))
	var roughness := float(ground_data.get("roughness", 0.9))
	var mat := mesh.get_surface_override_material(0)
	if mat == null and mesh.mesh != null:
		mat = mesh.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.albedo_color = albedo
		sm.roughness = roughness
		mesh.set_surface_override_material(0, sm)
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = albedo
		sm.roughness = roughness
		mesh.set_surface_override_material(0, sm)

func _apply_ramp(data: Dictionary) -> void:
	var ramp := get_node_or_null(ramp_path) as Node3D
	if ramp == null:
		return
	var features: Dictionary = data.get("features", {})
	var show_ramp := bool(features.get("ramp", false))
	ramp.visible = show_ramp
	# Disable collision when hidden so vehicles don't hit invisible ramp.
	if ramp is CollisionObject3D:
		(ramp as CollisionObject3D).collision_layer = 1 if show_ramp else 0
	var col := ramp.get_node_or_null("Collision") as CollisionShape3D
	if col:
		col.disabled = not show_ramp

func _clear_env_props() -> void:
	var props := get_node_or_null(env_props_path) as Node
	if props == null:
		return
	for child in props.get_children():
		props.remove_child(child)
		child.queue_free()
