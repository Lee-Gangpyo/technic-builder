extends PanelContainer
## Touch-friendly part catalog (≥44pt / preferably ≥64px hit targets). Shows KR + EN labels.

signal part_requested(part_id: String)

@onready var list: VBoxContainer = %PartList
@onready var title: Label = %Title

func _ready() -> void:
	title.text = "부품 카탈로그"
	title.add_theme_font_size_override("font_size", int(round(UITheme.screen_px(18.0))))
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	var cats := ["beam", "axle", "connector", "gear", "wheel", "motor"]
	var cat_ko := {"beam": "빔", "axle": "액슬", "connector": "연결", "gear": "기어", "wheel": "바퀴", "motor": "모터"}
	var compact := UITheme.is_compact() or UITheme.want_large_touch()
	var row_h := UITheme.screen_px(56.0 if compact else 48.0)
	var font_sz := int(round(UITheme.screen_px(16.0 if compact else 14.0)))
	for cat in cats:
		var hdr := Label.new()
		hdr.text = "— %s —" % cat_ko.get(cat, cat)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 15)
		hdr.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.95))
		list.add_child(hdr)
		for data in PartCatalog.by_category(cat):
			var btn := Button.new()
			var ko: String = str(data.get("name_ko", ""))
			var en: String = str(data.get("name_en", ""))
			if ko.is_empty():
				btn.text = en if not en.is_empty() else str(data.get("id", "?"))
			elif en.is_empty() or en == ko:
				btn.text = ko
			else:
				btn.text = "%s\n%s" % [ko, en]
			btn.custom_minimum_size = Vector2(0, row_h)
			btn.add_theme_font_size_override("font_size", font_sz)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var id: String = data["id"]
			# Catalog Art: res://assets/catalog/parts/{id}.png (PR #12)
			var icon_path := "res://assets/catalog/parts/%s.png" % id
			if ResourceLoader.exists(icon_path):
				var tex: Texture2D = load(icon_path) as Texture2D
				if tex != null:
					btn.icon = tex
					btn.expand_icon = true
					btn.add_theme_constant_override("icon_max_width", int(round(UITheme.screen_px(40.0))))
			btn.pressed.connect(func(): part_requested.emit(id))
			list.add_child(btn)
