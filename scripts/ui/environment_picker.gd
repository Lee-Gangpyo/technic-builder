extends PanelContainer
## Background / environment picker. Uses EnvironmentCatalog + thumbnails.
## Layout/chrome owned by HUD; this panel only lists and emits selection.

signal environment_selected(env_id: String)

@onready var list: VBoxContainer = %EnvList
@onready var title: Label = %EnvTitle

var _selected_id: String = ""

func _ready() -> void:
	title.text = "배경"
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()

func set_selected(env_id: String) -> void:
	_selected_id = env_id
	_rebuild()

func _rebuild() -> void:
	if list == null:
		return
	for c in list.get_children():
		c.queue_free()
	title.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(18.0))))
	var row_h := UITheme.screen_px(56.0)
	var font_sz := int(round(UITheme.screen_px(16.0)))
	var icon_sz := int(round(UITheme.screen_px(40.0)))
	for entry in EnvironmentCatalog.list():
		var id: String = str(entry.get("id", ""))
		var name_ko: String = str(entry.get("name_ko", id))
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, row_h)
		row.add_theme_font_size_override("font_size", font_sz)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mark := "✓ " if id == _selected_id else ""
		row.text = "%s%s" % [mark, name_ko]
		var thumb_path := "res://assets/catalog/environments/%s.png" % id
		if ResourceLoader.exists(thumb_path):
			var tex: Texture2D = load(thumb_path) as Texture2D
			if tex != null:
				row.icon = tex
				row.expand_icon = true
				row.add_theme_constant_override("icon_max_width", icon_sz)
		var captured := id
		row.pressed.connect(func():
			_selected_id = captured
			environment_selected.emit(captured)
			_rebuild()
		)
		list.add_child(row)
