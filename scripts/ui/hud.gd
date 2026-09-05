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
var _first_build_hint: bool = true

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
	# Use real window pixels (web/iOS), not stretched 1280-wide viewport.
	return UITheme.is_compact()

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

	# Touch targets in VIEWPORT units sized to hit ≥44–56 CSS px after stretch.
	# Web iPhone: viewport ~1280 mapped onto ~390 CSS → scale≈3.3; raw 64px looked ~18px.
	var large := UITheme.want_large_touch()
	var btn_h := UITheme.screen_px(56.0 if (_compact or large) else 52.0)
	var font_sz := int(round(UITheme.screen_px(17.0 if (_compact or large) else 15.0)))
	for b in [mode_btn, catalog_toggle, undo_btn, rotate_btn, rotate_x_btn, detach_btn, starter_btn, clear_btn]:
		if b:
			b.custom_minimum_size.y = btn_h
			b.add_theme_font_size_override("font_size", font_sz)
	if status_label:
		status_label.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(14.0))))
		status_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	if _compact or large:
		mode_btn.custom_minimum_size.x = UITheme.screen_px(140.0)
		catalog_toggle.custom_minimum_size = Vector2(UITheme.screen_px(120.0), btn_h)
		catalog_toggle.add_theme_font_size_override("font_size", font_sz)
		for b in [undo_btn, rotate_btn, rotate_x_btn, detach_btn, starter_btn, clear_btn]:
			b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, UITheme.screen_px(100.0))
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		rotate_btn.custom_minimum_size = Vector2(maxf(rotate_btn.custom_minimum_size.x, UITheme.screen_px(118.0)), btn_h)
		rotate_x_btn.custom_minimum_size = Vector2(maxf(rotate_x_btn.custom_minimum_size.x, UITheme.screen_px(118.0)), btn_h)
		fwd_btn.custom_minimum_size.y = UITheme.screen_px(72.0)
		back_btn.custom_minimum_size.y = UITheme.screen_px(72.0)
		motor_btn.custom_minimum_size.y = UITheme.screen_px(60.0)
		fwd_btn.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(18.0))))
		back_btn.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(18.0))))
		motor_btn.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(16.0))))
	else:
		fwd_btn.custom_minimum_size.y = UITheme.screen_px(64.0)
		back_btn.custom_minimum_size.y = UITheme.screen_px(64.0)
		motor_btn.custom_minimum_size.y = UITheme.screen_px(52.0)

	catalog_toggle.visible = (_compact or UITheme.want_large_touch()) and is_build and UITheme.window_size().x < 1000.0
	tools_bar.visible = is_build
	if _compact:
		rotate_btn.text = "회전 Y"
		rotate_x_btn.text = "회전 X"
		undo_btn.text = "취소"
		detach_btn.text = "분리"
		starter_btn.text = "스타터"
		clear_btn.text = "전체삭제"
	else:
		rotate_btn.text = "회전 Y 90°"
		rotate_x_btn.text = "회전 X 90°"
		undo_btn.text = "실행취소"
		detach_btn.text = "분리"
		starter_btn.text = "스타터 카트"
		clear_btn.text = "전체삭제"

	# Top / tools bars
	if _compact:
		top_bar.offset_left = 8.0
		top_bar.offset_right = -8.0
		top_bar.offset_top = 6.0
		top_bar.offset_bottom = 6.0 + btn_h + 4.0
		tools_bar.offset_left = 8.0
		tools_bar.offset_right = -8.0
		tools_bar.offset_top = top_bar.offset_bottom + 2.0
		tools_bar.offset_bottom = tools_bar.offset_top + btn_h * 2.8 + 16.0
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
		# Portrait: first entry opens catalog so parts aren't off-screen/missing;
		# later visits stay collapsed for canvas room.
		if _is_compact_layout():
			if _first_build_hint:
				_catalog_open = true
				_first_build_hint = false
				GameState.notify("부품 ▼ 로 목록 열고 닫기")
			else:
				_catalog_open = false
				GameState.notify("조립 모드")
		else:
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
