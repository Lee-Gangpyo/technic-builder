extends Node3D
## Main scene bootstrap.

@onready var assembly: AssemblyManager = $World/Assembly
@onready var hud: CanvasLayer = $HUD
@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	var env_applier := get_node_or_null("EnvironmentApplier")
	if env_applier and env_applier.has_method("apply"):
		env_applier.apply(EnvironmentCatalog.default_id())
	hud.setup(assembly)
	await get_tree().process_frame
	await get_tree().physics_frame
	var want_smoke := _wants_smoke()
	if want_smoke:
		await _smoke()
		return
	# First entry: auto-spawn starter cart so the scene is never empty
	if assembly.parts.is_empty():
		assembly.spawn_starter_cart()
		GameState.undo_stack.clear()
		if camera_pivot and camera_pivot.has_method("focus_on"):
			camera_pivot.focus_on(Vector3(-0.6, 2.2, 0.0), 13.0)
		GameState.notify("스타터 카트 준비됨 — 조립하거나 운전 모드로 전환하세요")
	else:
		GameState.notify("테크닉 빌더 MVP — 부품을 선택하거나 스타터 카트를 로드하세요")

func _wants_smoke() -> bool:
	for a in OS.get_cmdline_user_args():
		if str(a).contains("smoke"):
			return true
	return false

func _smoke() -> void:
	print("SMOKE: catalog=", PartCatalog.parts.size())
	assembly.spawn_part("beam_5", Vector3(0, 5, 0))
	print("SMOKE: after beam=", assembly.parts.size())
	assembly.spawn_starter_cart()
	print("SMOKE: starter=", assembly.parts.size(), " gears=", assembly.gear_links.size())
	GameState.set_mode(GameState.Mode.DRIVE)
	assembly._set_motors(true)
	assembly.set_throttle(1.0)
	for i in range(30):
		await get_tree().physics_frame
	var spinning := 0
	for p in assembly.parts:
		if (p.is_gear or p.is_motor) and p.angular_velocity.length() > 0.02:
			spinning += 1
			print("SMOKE spin ", p.name, " ", p.angular_velocity.length())
	print("SMOKE: spinning=", spinning, " OK")
	get_tree().quit(0)

func _process(_delta: float) -> void:
	if GameState.mode != GameState.Mode.DRIVE:
		return
	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle += 1.0
	if Input.is_action_pressed("move_back"):
		throttle -= 1.0
	if absf(throttle) > 0.01:
		assembly.set_throttle(throttle)
		if not GameState.motor_on:
			assembly._set_motors(true)
	else:
		var fwd := hud.get_node_or_null("Root/DrivePanel/FwdBtn") as Button
		var back := hud.get_node_or_null("Root/DrivePanel/BackBtn") as Button
		var ui_held := (fwd != null and fwd.button_pressed) or (back != null and back.button_pressed)
		if not ui_held and absf(GameState.drive_throttle) > 0.01:
			assembly.set_throttle(0.0)
	if Input.is_action_just_pressed("motor_toggle"):
		assembly.toggle_motor()

func _unhandled_input(event: InputEvent) -> void:
	## Template spawns (no HUD): 1=starter, 2=gear demo, 3=mini crane
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				assembly.spawn_starter_cart()
				GameState.undo_stack.clear()
				get_viewport().set_input_as_handled()
			KEY_2:
				assembly.spawn_gear_demo()
				GameState.undo_stack.clear()
				get_viewport().set_input_as_handled()
			KEY_3:
				assembly.spawn_mini_crane()
				GameState.undo_stack.clear()
				get_viewport().set_input_as_handled()
