extends Node
## Loads data/parts/*.json into a dictionary keyed by id.

var parts: Dictionary = {}  ## id -> Dictionary

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	var dir := DirAccess.open("res://data/parts")
	if dir == null:
		push_error("PartCatalog: cannot open res://data/parts")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path := "res://data/parts/%s" % fname
			var f := FileAccess.open(path, FileAccess.READ)
			if f:
				var parsed = JSON.parse_string(f.get_as_text())
				f.close()
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id"):
					parts[parsed["id"]] = parsed
		fname = dir.get_next()
	dir.list_dir_end()
	print("PartCatalog: loaded %d parts" % parts.size())

func get_part(id: String) -> Dictionary:
	return parts.get(id, {})

func all_ids() -> Array:
	var ids: Array = parts.keys()
	ids.sort()
	return ids

func by_category(cat: String) -> Array:
	var out: Array = []
	for id in parts:
		if parts[id].get("category", "") == cat:
			out.append(parts[id])
	return out
