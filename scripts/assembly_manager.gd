extends Node3D
class_name AssemblyManager
## Spawn, drag, rotate, snap, detach, undo, gear mesh detection, starter template.

@export var parts_root_path: NodePath = ^"Parts"
@export var joints_root_path: NodePath = ^"Joints"
@export var camera_path: NodePath = ^"../CameraPivot/Camera3D"

var parts_root: Node3D
var joints_root: Node3D
var camera: Camera3D

var parts: Array[TechnicPart] = []
var dragging: TechnicPart = null
var drag_plane_y: float = 2.0
var drag_offset: Vector3 = Vector3.ZERO
var pending_snap: Dictionary = {}
var gear_links: Array = []  ## GearConstraint nodes

func _ready() -> void:
	add_to_group("assembly_manager")
	parts_root = get_node(parts_root_path)
	joints_root = get_node(joints_root_path)
	camera = get_node(camera_path)
	GameState.mode_changed.connect(_on_mode_changed)

func _physics_process(_delta: float) -> void:
	if GameState.mode != GameState.Mode.DRIVE:
		return
	for p in parts:
		if not is_instance_valid(p):
			continue
		if p.angular_velocity.length() > 30.0:
			p.angular_velocity = p.angular_velocity.limit_length(30.0)
		if p.linear_velocity.length() > 40.0:
			p.linear_velocity = p.linear_velocity.limit_length(40.0)

func _on_mode_changed(mode: GameState.Mode) -> void:
	if mode == GameState.Mode.DRIVE:
		_end_drag()
		for p in parts:
			p.freeze = false
			p.set_selected(false)
		_set_motors(GameState.motor_on)
	else:
		_set_motors(false)
		# Soft-freeze floating unconnected? keep physics for demo stability:
		for p in parts:
			p.linear_velocity = Vector3.ZERO
			p.angular_velocity = Vector3.ZERO

func spawn_part(part_id: String, world_pos: Vector3 = Vector3(0, 3, 0)) -> TechnicPart:
	var data: Dictionary = PartCatalog.get_part(part_id)
	if data.is_empty():
		GameState.notify("알 수 없는 부품: %s" % part_id)
		return null
	var p := TechnicPart.new()
	p.name = "%s_%d" % [part_id, parts.size()]
	parts_root.add_child(p)
	p.setup(data)
	p.global_position = world_pos
	p.freeze = GameState.mode == GameState.Mode.BUILD
	parts.append(p)
	GameState.push_undo({"type": "spawn", "part": p})
	GameState.select_part(p)
	p.set_selected(true)
	GameState.notify("배치: %s / %s" % [data.get("name_ko", part_id), data.get("name_en", part_id)])
	return p

func spawn_starter_cart() -> void:
	## Motor → axle → gear24 → gear8 → axle → wheels on beam chassis
	## Pitch radii (cm): 24T=1.92, 8T=0.64 → center distance 2.56
	clear_all(false)
	var y: float = 3.0
	var beam := spawn_part("beam_7", Vector3(0, y - 1.2, 0))
	beam.rotation_degrees = Vector3(0, 0, 90)
	beam.freeze = true

	var motor := spawn_part("motor_m", Vector3(-2.56, y - 0.4, 0))
	motor.freeze = true

	var axle_drive := spawn_part("axle_5", Vector3(-2.56, y, 0))
	axle_drive.freeze = true

	var g24 := spawn_part("gear_24", Vector3(-2.56, y, 0))
	g24.freeze = true

	var g8 := spawn_part("gear_8", Vector3(0.0, y, 0))
	g8.freeze = true

	var axle_wheel := spawn_part("axle_5", Vector3(0.0, y, 0))
	axle_wheel.rotation_degrees = Vector3(90, 0, 0)
	axle_wheel.freeze = true

	var w1 := spawn_part("wheel", Vector3(0.0, y, -2.0))
	w1.freeze = true
	var w2 := spawn_part("wheel", Vector3(0.0, y, 2.0))
	w2.freeze = true

	_force_connect(motor, "output", axle_drive, "a0")
	_force_connect(axle_drive, "a2", g24, "axle_in")
	_force_connect(axle_wheel, "a2", g8, "axle_in")
	_force_connect(axle_wheel, "a0", w1, "axle_in")
	_force_connect(axle_wheel, "a4", w2, "axle_in")
	_force_connect(beam, "h3", motor, "mount0")

	_refresh_gear_constraints()
	if gear_links.is_empty():
		_link_gears(g24, g8)
	for p in parts:
		p.freeze = true
	GameState.notify("스타터: 모터→기어→바퀴 카트 로드됨")

func _link_gears(a: TechnicPart, b: TechnicPart) -> void:
	if a == null or b == null:
		return
	var gc := GearConstraint.new()
	add_child(gc)
	gc.setup(a, b)
	gear_links.append(gc)

func _force_connect(a: TechnicPart, cid_a: String, b: TechnicPart, cid_b: String) -> void:
	var ta = null
	var tb = null
	for c in a.connectors:
		if c["id"] == cid_a:
			ta = c
	for c in b.connectors:
		if c["id"] == cid_b:
			tb = c
	if ta == null or tb == null:
		return
	# Move b so connectors coincide
	var snap := {
		"found": true,
		"target_part": a,
		"moving_cid": cid_b,
		"target_cid": cid_a,
		"moving_type": tb["type"],
		"target_type": ta["type"],
		"target_pos": a.get_connector_global(cid_a).origin,
		"target_axis": a.world_axis_of(cid_a)
	}
	b.global_transform = SnapSystem.compute_snap_transform(b, snap)
	_create_connection(b, cid_b, a, cid_a, tb["type"], ta["type"])

func clear_all(notify: bool = true) -> void:
	for j in joints_root.get_children():
		j.queue_free()
	for g in gear_links:
		if is_instance_valid(g):
			g.queue_free()
	gear_links.clear()
	for p in parts:
		if is_instance_valid(p):
			p.queue_free()
	parts.clear()
	GameState.undo_stack.clear()
	GameState.select_part(null)
	if notify:
		GameState.notify("모두 삭제")

func _input(event: InputEvent) -> void:
	## Pointer pick/drag in _input so part drag wins over camera orbit (which uses unhandled).
	if GameState.mode != GameState.Mode.BUILD:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _try_pick(mb.position):
					get_viewport().set_input_as_handled()
			else:
				if dragging:
					_end_drag()
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		_drag_to((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _try_pick(st.position):
				get_viewport().set_input_as_handled()
		else:
			if dragging:
				_end_drag()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and dragging:
		_drag_to((event as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if GameState.mode != GameState.Mode.BUILD:
		return
	if event.is_action_pressed("undo"):
		undo_last()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rotate_part") and GameState.selected_part:
		_rotate_selected()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("detach") and GameState.selected_part:
		detach_part(GameState.selected_part as TechnicPart)
		get_viewport().set_input_as_handled()
		return

func _try_pick(screen_pos: Vector2) -> bool:
	if camera == null:
		return false
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	q.collision_mask = 2
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var body = hit.collider
	if body is TechnicPart:
		var p: TechnicPart = body
		if GameState.selected_part and GameState.selected_part != p:
			(GameState.selected_part as TechnicPart).set_selected(false)
		GameState.select_part(p)
		p.set_selected(true)
		dragging = p
		dragging.freeze = true
		drag_plane_y = p.global_position.y
		var planar := _ray_to_plane(screen_pos, drag_plane_y)
		drag_offset = p.global_position - planar
		# Detach while dragging so user can re-place
		detach_part(p, false)
		return true
	return false

func _drag_to(screen_pos: Vector2) -> void:
	if dragging == null:
		return
	var planar := _ray_to_plane(screen_pos, drag_plane_y)
	dragging.global_position = planar + drag_offset
	pending_snap = SnapSystem.find_snap(dragging, parts, GameState.SNAP_DISTANCE, GameState.SNAP_ANGLE_DEG)
	if pending_snap.get("found", false):
		dragging.global_transform = SnapSystem.compute_snap_transform(dragging, pending_snap)
		GameState.notify("스냅 가능 ✓")

func _end_drag() -> void:
	if dragging == null:
		return
	if pending_snap.get("found", false):
		var s := pending_snap
		dragging.global_transform = SnapSystem.compute_snap_transform(dragging, s)
		_create_connection(
			dragging, s["moving_cid"],
			s["target_part"], s["target_cid"],
			s["moving_type"], s["target_type"]
		)
		GameState.push_undo({"type": "connect", "part": dragging, "snap": s})
		GameState.notify("연결됨")
		_refresh_gear_constraints()
	pending_snap = {}
	dragging = null

func _ray_to_plane(screen_pos: Vector2, y: float) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 1e-5:
		return Vector3(from.x, y, from.z)
	var t := (y - from.y) / dir.y
	return from + dir * t

func _create_connection(a: TechnicPart, cid_a: String, b: TechnicPart, cid_b: String, type_a: String, type_b: String) -> void:
	a.mark_connected(cid_a, true)
	b.mark_connected(cid_b, true)
	var joint := JointFactory.create_joint(joints_root, a, cid_a, b, cid_b, type_a, type_b)
	a.connections[cid_a] = {"other": b, "other_cid": cid_b, "joint": joint}
	b.connections[cid_b] = {"other": a, "other_cid": cid_a, "joint": joint}

func detach_part(p: TechnicPart, push: bool = true) -> void:
	if p == null:
		return
	var keys: Array = p.connections.keys()
	for cid in keys:
		var info: Dictionary = p.connections[cid]
		var other: TechnicPart = info.get("other")
		var ocid: String = info.get("other_cid", "")
		var joint: Joint3D = info.get("joint")
		if joint and is_instance_valid(joint):
			joint.queue_free()
		p.mark_connected(cid, false)
		if other and is_instance_valid(other):
			other.mark_connected(ocid, false)
			other.connections.erase(ocid)
		p.connections.erase(cid)
	_refresh_gear_constraints()
	if push:
		GameState.push_undo({"type": "detach", "part": p})
		GameState.notify("분리됨")

func _rotate_selected(axis: String = "y") -> void:
	var p := GameState.selected_part as TechnicPart
	if p == null:
		return
	detach_part(p, false)
	match axis:
		"x":
			p.rotate_x(deg_to_rad(90))
		"z":
			p.rotate_z(deg_to_rad(90))
		_:
			p.rotate_y(deg_to_rad(90))
	GameState.notify("90° 회전 (%s)" % axis.to_upper())

func undo_last() -> void:
	var action := GameState.pop_undo()
	if action.is_empty():
		GameState.notify("되돌릴 수 없음")
		return
	match action.get("type", ""):
		"spawn":
			var p: TechnicPart = action.get("part")
			if p and is_instance_valid(p):
				detach_part(p, false)
				parts.erase(p)
				p.queue_free()
				GameState.select_part(null)
				GameState.notify("실행 취소: 배치")
		"connect":
			var p2: TechnicPart = action.get("part")
			if p2 and is_instance_valid(p2):
				detach_part(p2, false)
				GameState.notify("실행 취소: 연결")
		_:
			GameState.notify("실행 취소")

func _refresh_gear_constraints() -> void:
	for g in gear_links:
		if is_instance_valid(g):
			g.queue_free()
	gear_links.clear()
	var gears: Array[TechnicPart] = []
	for p in parts:
		if p.is_gear:
			gears.append(p)
	for i in range(gears.size()):
		for j in range(i + 1, gears.size()):
			if GearConstraint.are_meshed(gears[i], gears[j]):
				var gc := GearConstraint.new()
				add_child(gc)
				gc.setup(gears[i], gears[j])
				gear_links.append(gc)
				GameState.notify("기어 맞물림: %dT ↔ %dT" % [gears[i].teeth, gears[j].teeth])

func _set_motors(on: bool) -> void:
	GameState.motor_on = on
	for p in parts:
		if p.is_motor:
			p.motor_enabled = on
			# Also drive throttle: reverse if negative
			if on and absf(GameState.drive_throttle) > 0.01:
				p.target_rpm = absf(float(p.part_data.get("max_rpm", 200)) * 0.6) * signf(GameState.drive_throttle)
			elif on:
				p.target_rpm = absf(float(p.part_data.get("max_rpm", 200)) * 0.6)

func set_throttle(v: float) -> void:
	GameState.drive_throttle = clampf(v, -1.0, 1.0)
	if GameState.mode == GameState.Mode.DRIVE:
		_set_motors(GameState.motor_on or absf(v) > 0.05)

func toggle_motor() -> void:
	_set_motors(not GameState.motor_on)
	GameState.notify("모터 %s" % ("ON" if GameState.motor_on else "OFF"))
