extends Node
## Global game state: Build vs Drive mode, selection, undo.

enum Mode { BUILD, DRIVE }

signal mode_changed(mode: Mode)
signal selection_changed(part: Node3D)
signal status_message(text: String)

const UNIT_SCALE := 100.0  ## meters → cm (1 Godot unit = 1 cm)
const HOLE_SPACING := 0.8  ## cm between Technic holes
const SNAP_DISTANCE := 0.6  ## cm magnet snap threshold
const SNAP_ANGLE_DEG := 25.0

var mode: Mode = Mode.BUILD
var selected_part: Node3D = null
var motor_on: bool = false
var drive_throttle: float = 0.0  ## -1 .. 1
var undo_stack: Array = []  ## Array of Dictionaries

func set_mode(m: Mode) -> void:
	if mode == m:
		return
	mode = m
	if mode == Mode.BUILD:
		motor_on = false
		drive_throttle = 0.0
	mode_changed.emit(mode)

func toggle_mode() -> void:
	set_mode(Mode.DRIVE if mode == Mode.BUILD else Mode.BUILD)

func select_part(part: Node3D) -> void:
	selected_part = part
	selection_changed.emit(part)

func push_undo(action: Dictionary) -> void:
	undo_stack.append(action)
	if undo_stack.size() > 50:
		undo_stack.pop_front()

func pop_undo() -> Dictionary:
	if undo_stack.is_empty():
		return {}
	return undo_stack.pop_back()

func notify(text: String) -> void:
	status_message.emit(text)
