extends CanvasLayer
## Build/Drive HUD with Korean labels + touch controls.

@onready var mode_btn: Button = %ModeBtn
@onready var undo_btn: Button = %UndoBtn
@onready var rotate_btn: Button = %RotateBtn
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

func setup(asm: AssemblyManager) -> void:
	assembly = asm
	catalog.part_requested.connect(_on_part_requested)
	mode_btn.pressed.connect(_on_mode)
	undo_btn.pressed.connect(func(): assembly.undo_last())
	rotate_btn.pressed.connect(func(): assembly._rotate_selected())
	detach_btn.pressed.connect(func():
		if GameState.selected_part:
			assembly.detach_part(GameState.selected_part as TechnicPart)
	)
	starter_btn.pressed.connect(func(): assembly.spawn_starter_cart())
	clear_btn.pressed.connect(func(): assembly.clear_all())
	motor_btn.pressed.connect(func(): assembly.toggle_motor())
	fwd_btn.button_down.connect(func(): assembly.set_throttle(1.0); assembly._set_motors(true))
	fwd_btn.button_up.connect(func(): assembly.set_throttle(0.0))
	back_btn.button_down.connect(func(): assembly.set_throttle(-1.0); assembly._set_motors(true))
	back_btn.button_up.connect(func(): assembly.set_throttle(0.0))
	GameState.mode_changed.connect(_on_mode_changed)
	GameState.status_message.connect(func(t): status_label.text = t)
	_on_mode_changed(GameState.mode)
	help_label.text = "드래그=이동 · R=회전 · X=분리 · Ctrl+Z=실행취소 · WASD/버튼=운전"

func _on_part_requested(part_id: String) -> void:
	if GameState.mode != GameState.Mode.BUILD:
		GameState.notify("조립 모드에서만 배치 가능")
		return
	assembly.spawn_part(part_id, Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2)))

func _on_mode() -> void:
	GameState.toggle_mode()

func _on_mode_changed(mode: GameState.Mode) -> void:
	var is_build := mode == GameState.Mode.BUILD
	mode_btn.text = "모드: 조립 (Build)" if is_build else "모드: 운전 (Drive)"
	catalog.visible = is_build
	undo_btn.visible = is_build
	rotate_btn.visible = is_build
	detach_btn.visible = is_build
	starter_btn.visible = is_build
	clear_btn.visible = is_build
	drive_panel.visible = not is_build
	if is_build:
		GameState.notify("조립 모드")
	else:
		GameState.notify("운전 모드 — 모터/전진 사용")
