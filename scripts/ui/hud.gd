extends CanvasLayer
## Build/Drive HUD with Korean labels, responsive portrait layout, large touch targets.

@onready var root_ctrl: Control = $Root
@onready var top_bar: Control = %TopBar
@onready var tools_bar: Control = %ToolsBar
@onready var mode_btn: Button = %ModeBtn
@onready var catalog_toggle: Button = %CatalogToggleBtn
@onready var undo_btn: Button = %UndoBtn
@onready var rotate_btn: Button = %RotateBtn
@onready var rotate_x_btn: Button = %RotateXBtn
@onready var detach_btn: Button = %DetachBtn
@onready var starter_btn: Button = %StarterBtn
@onready var clear_btn: Button = %ClearBtn
@onready var status_label: Label = %StatusLabel
@onready var catalog: PanelContainer = %CatalogPanel
@onready var drive_panel: Control = %DrivePanel
@onready var fwd_btn: Button = %FwdBtn
@onready var back_btn: Button = %BackBtn
@onready var motor_btn: Button = %MotorBtn
@onready var help_label: Label = %HelpLabel

var assembly: AssemblyManager
var _catalog_open: bool = false
var _compact: bool = false

func setup(asm: AssemblyManager) -> void:
	assembly = asm
	catalog.part_requested.connect(_on_part_requested)
	mode_btn.pressed.connect(_on_mode)
	catalog_toggle.pressed.connect(_on_catalog_toggle)
	undo_btn.pressed.connect(func(): assembly.undo_last())
	rotate_btn.pressed.connect(func(): assembly._rotate_selected("y"))
	rotate_x_btn.pressed.connect(func(): assembly._rotate_selected("x"))
	detach_btn.pressed.connect(func():
		if GameState.selected_part:
			assembly.detach_part(GameState.selected_part as TechnicPart)
	)
	starter_btn.pressed.connect(func(): assembly.spawn_starter_cart())
	clear_btn.pressed.connect(func(): assembly.clear_all())
	motor_btn.pressed.connect(func(): assembly.toggle_motor())
	# action_mode = BUTTON_PRESS keeps multitouch hold reliable on Web
	fwd_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	back_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	fwd_btn.button_down.connect(func(): assembly.set_throttle(1.0); assembly._set_motors(true))
	fwd_btn.button_up.connect(func(): assembly.set_throttle(0.0))
	back_btn.button_down.connect(func(): assembly.set_throttle(-1.0); assembly._set_motors(true))
	back_btn.button_up.connect(func(): assembly.set_throttle(0.0))
	GameState.mode_changed.connect(_on_mode_changed)
	GameState.status_message.connect(func(t): status_label.text = t)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_mode_changed(GameState.mode)
	_apply_layout()
	help_label.text = "빈곳 드래그=궤도 · 핀치=줌 · 두손=팬 · 부품 드래그=이동 · 회전 버튼=90°"

func _on_viewport_resized() -> void:
	_apply_layout()

func _is_compact_layout() -> bool:
	var s := get_viewport().get_visible_rect().size
	# Portrait phones / narrow tablets: treat as compact
	return s.x < 920.0 or s.x < s.y * 0.95

func _on_catalog_toggle() -> void:
	_catalog_open = not _catalog_open
	_apply_layout()

func _apply_layout() -> void:
	# Keep toolbars above catalog/drive so iPhone taps hit rotate buttons first.
	if top_bar:
		top_bar.z_index = 20
		top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if tools_bar:
		tools_bar.z_index = 21
		tools_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		tools_bar.clip_contents = false
	if catalog:
		catalog.z_index = 5
		# Closed sheet must not eat taps over the world / toolbars.
		if not catalog.visible:
			catalog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			catalog.mouse_filter = Control.MOUSE_FILTER_STOP
	if drive_panel:
		drive_panel.z_index = 15
	if help_label:
		help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_label.z_index = 2
	_compact = _is_compact_layout()
	var is_build := GameState.mode == GameState.Mode.BUILD
	var vp := get_viewport().get_visible_rect().size

	# Touch targets
	var btn_h := 56.0 if _compact else 48.0
	for b in [mode_btn, catalog_toggle, undo_btn, rotate_btn, rotate_x_btn, detach_btn, starter_btn, clear_btn]:
		if b:
			b.custom_minimum_size.y = btn_h
	if _compact:
		mode_btn.custom_minimum_size.x = 150.0
		catalog_toggle.custom_minimum_size = Vector2(120, btn_h)
		for b in [undo_btn, rotate_btn, rotate_x_btn, detach_btn, starter_btn, clear_btn]:
			b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, 96.0)
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		# Rotate buttons get extra width — common miss targets on thumb reach
		rotate_btn.custom_minimum_size.x = maxf(rotate_btn.custom_minimum_size.x, 120.0)
		rotate_x_btn.custom_minimum_size.x = maxf(rotate_x_btn.custom_minimum_size.x, 120.0)
		fwd_btn.custom_minimum_size.y = 88.0
		back_btn.custom_minimum_size.y = 88.0
		motor_btn.custom_minimum_size.y = 72.0
	else:
		fwd_btn.custom_minimum_size.y = 80.0
		back_btn.custom_minimum_size.y = 80.0
		motor_btn.custom_minimum_size.y = 64.0

	catalog_toggle.visible = _compact and is_build
	tools_bar.visible = is_build

	# Top / tools bars
	if _compact:
		top_bar.offset_left = 8.0
		top_bar.offset_right = -8.0
		top_bar.offset_top = 6.0
		top_bar.offset_bottom = 6.0 + btn_h + 4.0
		tools_bar.offset_left = 8.0
		tools_bar.offset_right = -8.0
		tools_bar.offset_top = top_bar.offset_bottom + 2.0
		tools_bar.offset_bottom = tools_bar.offset_top + btn_h * 2.6 + 12.0
	else:
		top_bar.offset_left = 12.0
		top_bar.offset_right = -12.0
		top_bar.offset_top = 8.0
		top_bar.offset_bottom = 64.0
		tools_bar.offset_left = 12.0
		tools_bar.offset_right = -12.0
		tools_bar.offset_top = 68.0
		tools_bar.offset_bottom = 124.0

	# Catalog: left rail (desktop) vs bottom sheet (portrait)
	if not is_build:
		catalog.visible = false
	elif _compact:
		catalog.visible = _catalog_open
		catalog_toggle.text = "부품 ▲" if _catalog_open else "부품 ▼"
		# Bottom sheet
		var sheet_h := clampf(vp.y * 0.42, 220.0, 380.0)
		catalog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		catalog.anchor_left = 0.0
		catalog.anchor_right = 1.0
		catalog.anchor_top = 1.0
		catalog.anchor_bottom = 1.0
		catalog.offset_left = 8.0
		catalog.offset_right = -8.0
		catalog.offset_top = -sheet_h - 48.0
		catalog.offset_bottom = -48.0
		catalog.grow_horizontal = Control.GROW_DIRECTION_BOTH
		catalog.grow_vertical = Control.GROW_DIRECTION_BEGIN
		help_label.offset_left = 12.0
		help_label.offset_right = -12.0
		help_label.offset_top = -44.0
		help_label.offset_bottom = -8.0
		# Drive panel: bottom center-ish for thumbs
		drive_panel.anchor_left = 0.5
		drive_panel.anchor_right = 0.5
		drive_panel.anchor_top = 1.0
		drive_panel.anchor_bottom = 1.0
		drive_panel.offset_left = -140.0
		drive_panel.offset_right = 140.0
		drive_panel.offset_top = -300.0
		drive_panel.offset_bottom = -52.0
	else:
		_catalog_open = true
		catalog.visible = true
		catalog_toggle.text = "부품"
		catalog.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		catalog.anchor_left = 0.0
		catalog.anchor_right = 0.0
		catalog.anchor_top = 0.0
		catalog.anchor_bottom = 1.0
		catalog.offset_left = 8.0
		catalog.offset_right = 228.0
		catalog.offset_top = 132.0
		catalog.offset_bottom = -12.0
		catalog.grow_horizontal = Control.GROW_DIRECTION_END
		catalog.grow_vertical = Control.GROW_DIRECTION_BOTH
		help_label.offset_left = 240.0
		help_label.offset_right = -280.0
		help_label.offset_top = -40.0
		help_label.offset_bottom = -8.0
		drive_panel.anchor_left = 1.0
		drive_panel.anchor_right = 1.0
		drive_panel.anchor_top = 1.0
		drive_panel.anchor_bottom = 1.0
		drive_panel.offset_left = -260.0
		drive_panel.offset_right = -16.0
		drive_panel.offset_top = -280.0
		drive_panel.offset_bottom = -16.0

func _on_part_requested(part_id: String) -> void:
	if GameState.mode != GameState.Mode.BUILD:
		GameState.notify("조립 모드에서만 배치 가능")
		return
	assembly.spawn_part(part_id, Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2)))
	# On phone, auto-collapse sheet after pick so canvas is usable
	if _compact and _catalog_open:
		_catalog_open = false
		_apply_layout()

func _on_mode() -> void:
	GameState.toggle_mode()

func _on_mode_changed(mode: GameState.Mode) -> void:
	var is_build := mode == GameState.Mode.BUILD
	mode_btn.text = "모드: 조립" if _compact else "모드: 조립 (Build)"
	if not is_build:
		mode_btn.text = "모드: 운전" if _compact else "모드: 운전 (Drive)"
	undo_btn.visible = is_build
	rotate_btn.visible = is_build
	rotate_x_btn.visible = is_build
	detach_btn.visible = is_build
	starter_btn.visible = is_build
	clear_btn.visible = is_build
	drive_panel.visible = not is_build
	if is_build:
		# Portrait: start with catalog closed so scene is visible
		if _is_compact_layout():
			_catalog_open = false
		GameState.notify("조립 모드")
		help_label.text = "빈곳 드래그=궤도 · 핀치=줌 · 두손=팬 · 부품 드래그=이동 · 회전 버튼=90°"
	else:
		_catalog_open = false
		GameState.notify("운전 모드 — 모터/전진 사용")
		help_label.text = "▲▼ = 전진/후진 (멀티터치 OK) · 모터 ON/OFF · 두 손가락=카메라"
	_apply_layout()
	# Refresh mode button label with compact awareness
	if is_build:
		mode_btn.text = "모드: 조립" if _compact else "모드: 조립 (Build)"
	else:
		mode_btn.text = "모드: 운전" if _compact else "모드: 운전 (Drive)"
