extends Node
## Loads data/environments/_index.json + presets into a catalog (autoload).

var _index: Dictionary = {}
var _environments: Dictionary = {}  ## id -> Dictionary

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_index = {}
	_environments.clear()
	var index_path := "res://data/environments/_index.json"
	var f := FileAccess.open(index_path, FileAccess.READ)
	if f == null:
		push_error("EnvironmentCatalog: cannot open %s" % index_path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnvironmentCatalog: invalid _index.json")
		return
	_index = parsed
	var ids: Array = _index.get("ids", [])
	for id in ids:
		var path := "res://data/environments/%s.json" % str(id)
		var ef := FileAccess.open(path, FileAccess.READ)
		if ef == null:
			push_warning("EnvironmentCatalog: missing preset %s" % path)
			continue
		var env_parsed = JSON.parse_string(ef.get_as_text())
		ef.close()
		if typeof(env_parsed) == TYPE_DICTIONARY and env_parsed.has("id"):
			_environments[str(env_parsed["id"])] = env_parsed
	print("EnvironmentCatalog: loaded %d environments" % _environments.size())

func list() -> Array:
	## Array of {id, name_ko, name_en, order} sorted by order.
	var out: Array = []
	for id in _environments:
		var e: Dictionary = _environments[id]
		out.append({
			"id": str(e.get("id", id)),
			"name_ko": str(e.get("name_ko", id)),
			"name_en": str(e.get("name_en", id)),
			"order": int(e.get("order", 999)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 999)) < int(b.get("order", 999))
	)
	return out

func get_environment(id: String) -> Dictionary:
	return _environments.get(id, {})

func default_id() -> String:
	var d := str(_index.get("default", "sandbox"))
	if _environments.has(d):
		return d
	var listed := list()
	if listed.size() > 0:
		return str(listed[0]["id"])
	return "sandbox"
