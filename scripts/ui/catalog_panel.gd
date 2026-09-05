extends PanelContainer
## Touch-friendly part catalog (≥44pt / preferably ≥64px hit targets). Shows KR + EN labels.

signal part_requested(part_id: String)

@onready var list: VBoxContainer = %PartList
@onready var title: Label = %Title

func _ready() -> void:
	title.text = "부품 카탈로그"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_rebuild()

func _is_compact() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.x < 920.0 or s.x < s.y * 0.95

func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	var cats := ["beam", "axle", "connector", "gear", "wheel", "motor"]
	var cat_ko := {"beam": "빔", "axle": "액슬", "connector": "연결", "gear": "기어", "wheel": "바퀴", "motor": "모터"}
	var row_h := 72.0 if _is_compact() else 64.0
	var font_sz := 18 if _is_compact() else 16
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
			var id: String = data["id"]
			btn.pressed.connect(func(): part_requested.emit(id))
			list.add_child(btn)
