extends PanelContainer
## Touch-friendly part catalog (≥44pt hit targets).

signal part_requested(part_id: String)

@onready var list: VBoxContainer = %PartList
@onready var title: Label = %Title

func _ready() -> void:
	title.text = "부품 카탈로그 / Parts"
	_rebuild()

func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	var cats := ["beam", "axle", "connector", "gear", "wheel", "motor"]
	var cat_ko := {"beam": "빔", "axle": "액슬", "connector": "연결", "gear": "기어", "wheel": "바퀴", "motor": "모터"}
	for cat in cats:
		var hdr := Label.new()
		hdr.text = "— %s —" % cat_ko.get(cat, cat)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(hdr)
		for data in PartCatalog.by_category(cat):
			var btn := Button.new()
			btn.text = "%s\n%s" % [data.get("name_ko", ""), data.get("name_en", "")]
			btn.custom_minimum_size = Vector2(0, 64)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var id: String = data["id"]
			btn.pressed.connect(func(): part_requested.emit(id))
			list.add_child(btn)
