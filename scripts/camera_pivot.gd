extends Node3D
## Orbit camera — mouse drag / pinch-friendly simple orbit.

@onready var camera: Camera3D = $Camera3D

var distance: float = 18.0
var yaw: float = 35.0
var pitch: float = -35.0
var target := Vector3(0, 2, 0)
var orbiting := false
var last_pos := Vector2.ZERO

func _ready() -> void:
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			orbiting = mb.pressed
			last_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 1.0, 6.0, 40.0)
			_apply()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 1.0, 6.0, 40.0)
			_apply()
	elif event is InputEventMouseMotion and orbiting:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.3
		pitch = clampf(pitch - mm.relative.y * 0.3, -80.0, -10.0)
		_apply()

func _apply() -> void:
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
