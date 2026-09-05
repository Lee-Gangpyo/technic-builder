extends Node3D
## Orbit camera — desktop mouse + iPad-friendly multitouch.
## Touch scheme (documented in README):
##   1 finger on empty space → orbit
##   1 finger on part → part drag (AssemblyManager; camera skips while dragging)
##   2 fingers pinch → zoom
##   2 fingers drag → pan target
## Desktop: RMB/MMB orbit, wheel zoom, Shift+MMB pan.

@onready var camera: Camera3D = $Camera3D

var distance: float = 18.0
var yaw: float = 35.0
var pitch: float = -35.0
var target := Vector3(0, 2, 0)
var orbiting := false
var panning := false
var last_pos := Vector2.ZERO

## Touch state: index -> position
var _touches: Dictionary = {}
var _orbit_touch_index: int = -1
var _pinch_start_dist: float = 0.0
var _pinch_start_distance: float = 0.0
var _pan_start_mid: Vector2 = Vector2.ZERO
var _two_finger_active: bool = false

var _assembly: Node = null

func _ready() -> void:
	_apply()
	call_deferred("_find_assembly")

func _find_assembly() -> void:
	_assembly = get_tree().get_first_node_in_group("assembly_manager")
	if _assembly == null:
		var main := get_tree().current_scene
		if main:
			_assembly = main.get_node_or_null("World/Assembly")

func _is_part_dragging() -> bool:
	if _assembly == null:
		_find_assembly()
	if _assembly and "dragging" in _assembly:
		return _assembly.dragging != null
	return false

func _clear_orbit_gesture() -> void:
	_orbit_touch_index = -1
	_two_finger_active = false
	orbiting = false
	panning = false

func _unhandled_input(event: InputEvent) -> void:
	# While a part is grabbed, never steal the gesture (orbit/pan/pinch).
	if _is_part_dragging():
		_clear_orbit_gesture()
		if event is InputEventScreenTouch:
			var st_busy := event as InputEventScreenTouch
			if st_busy.pressed:
				_touches[st_busy.index] = st_busy.position
			else:
				_touches.erase(st_busy.index)
		elif event is InputEventScreenDrag:
			var sd_busy := event as InputEventScreenDrag
			if _touches.has(sd_busy.index):
				_touches[sd_busy.index] = sd_busy.position
		return

	# --- Mouse (desktop) ---
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.shift_pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
				panning = mb.pressed
				orbiting = false
			else:
				orbiting = mb.pressed
				panning = false
			last_pos = mb.position
			if mb.pressed:
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 1.0, 6.0, 40.0)
			_apply()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 1.0, 6.0, 40.0)
			_apply()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if orbiting:
			yaw -= mm.relative.x * 0.3
			pitch = clampf(pitch - mm.relative.y * 0.3, -80.0, -10.0)
			_apply()
			get_viewport().set_input_as_handled()
		elif panning:
			_pan_screen(mm.relative)
			get_viewport().set_input_as_handled()

	# --- Touch ---
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				# One finger on empty space (Assembly did not claim a part) → orbit
				_orbit_touch_index = st.index
				last_pos = st.position
			elif _touches.size() >= 2:
				_orbit_touch_index = -1
				_begin_two_finger()
		else:
			_touches.erase(st.index)
			if st.index == _orbit_touch_index:
				_orbit_touch_index = -1
			if _touches.size() < 2:
				_two_finger_active = false
			if _touches.size() == 1:
				# Resume orbit with remaining finger
				var idx: int = int(_touches.keys()[0])
				_orbit_touch_index = idx
				last_pos = _touches[idx]
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			_update_two_finger()
			get_viewport().set_input_as_handled()
		elif _orbit_touch_index == sd.index:
			yaw -= sd.relative.x * 0.35
			pitch = clampf(pitch - sd.relative.y * 0.35, -80.0, -10.0)
			_apply()
			get_viewport().set_input_as_handled()

func _begin_two_finger() -> void:
	if _touches.size() < 2:
		return
	var pts: Array = _touches.values()
	_pinch_start_dist = pts[0].distance_to(pts[1])
	_pinch_start_distance = distance
	_pan_start_mid = (pts[0] + pts[1]) * 0.5
	_two_finger_active = true

func _update_two_finger() -> void:
	if _touches.size() < 2:
		return
	if not _two_finger_active:
		_begin_two_finger()
	var pts: Array = _touches.values()
	var dist: float = pts[0].distance_to(pts[1])
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5
	# Pinch zoom
	if _pinch_start_dist > 8.0:
		var scale := _pinch_start_dist / maxf(dist, 8.0)
		distance = clampf(_pinch_start_distance * scale, 6.0, 40.0)
	# Two-finger pan
	var delta: Vector2 = mid - _pan_start_mid
	_pan_start_mid = mid
	_pan_screen(delta)
	# Keep pinch baseline soft-updating so continuous pinch feels natural
	_pinch_start_dist = dist
	_pinch_start_distance = distance
	_apply()

func _pan_screen(relative: Vector2) -> void:
	# Pan along camera right / up projected onto XZ + Y
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	right.y = 0.0
	if right.length() > 0.001:
		right = right.normalized()
	else:
		right = Vector3.RIGHT
	var pan_scale := distance * 0.0025
	target += -right * relative.x * pan_scale
	target += up * relative.y * pan_scale
	target.y = clampf(target.y, 0.5, 20.0)
	_apply()

func _apply() -> void:
	if camera == null or not is_inside_tree() or not camera.is_inside_tree():
		return
	var r := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	var offset := Vector3(
		cos(p) * sin(r),
		-sin(p),
		cos(p) * cos(r)
	) * distance
	global_position = target
	camera.position = offset
	camera.look_at(target, Vector3.UP)
