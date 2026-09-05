extends SceneTree
## Headless smoke via main scene.
## godot --headless --path . -s res://scripts/smoke_test.gd

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		printerr("SMOKE FAIL: load main ", err)
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	var catalog: Node = root.get_node_or_null("PartCatalog")
	var gs: Node = root.get_node_or_null("GameState")
	if catalog == null or gs == null:
		printerr("SMOKE FAIL: autoloads missing")
		quit(1)
		return
	print("SMOKE: catalog parts=", catalog.parts.size())
	var main: Node = root.get_children().back()
	# After change_scene, current scene is under root
	main = current_scene
	var assembly: Node = main.get_node("World/Assembly")
	assembly.spawn_part("beam_5", Vector3(0, 5, 0))
	print("SMOKE: after beam spawn count=", assembly.parts.size())
	assembly.spawn_starter_cart()
	print("SMOKE: starter count=", assembly.parts.size(), " gear_links=", assembly.gear_links.size())
	gs.set_mode(gs.Mode.DRIVE)
	assembly._set_motors(true)
	assembly.set_throttle(1.0)
	for i in range(45):
		await physics_frame
	var spinning := 0
	for p in assembly.parts:
		if (p.is_gear or p.is_motor) and p.angular_velocity.length() > 0.02:
			spinning += 1
			print("SMOKE: ", p.name, " ω=", p.angular_velocity.length())
	print("SMOKE: spinning=", spinning)
	if assembly.parts.size() < 5:
		printerr("SMOKE FAIL: too few parts")
		quit(2)
		return
	print("SMOKE: gear_err last=%.4f ema=%.4f" % [GearConstraint.last_abs_error, GearConstraint.ema_abs_error])
	print("SMOKE: OK")
	quit(0)
