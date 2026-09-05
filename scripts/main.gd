extends Node3D
## Main scene bootstrap.

@onready var assembly: AssemblyManager = $World/Assembly
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	hud.setup(assembly)
	await get_tree().process_frame
	GameState.notify("테크닉 빌더 MVP — 부품을 선택하거나 스타터 카트를 로드하세요")
	var want_smoke := false
	for a in OS.get_cmdline_user_args():
		if str(a).contains("smoke"):
			want_smoke = true
	if want_smoke:
		await _smoke()

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
