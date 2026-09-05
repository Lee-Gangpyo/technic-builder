extends RefCounted
class_name ConnectionTypes
## Compatible Technic connector pairs.

static func compatible(a: String, b: String) -> bool:
	var pair: Array = [a, b]
	pair.sort()
	var key := "%s|%s" % [pair[0], pair[1]]
	match key:
		"pin|pin_hole":
			return true
		"axle|axle_hole":
			return true
		"axle|axle":
			return true
		"pin_hole|pin_hole":
			# Ultrahand-style weld convenience (MVP: beam/motor mounts without extra pin)
			return true
		_:
			return false

static func is_revolute(a: String, b: String) -> bool:
	return a.begins_with("axle") or b.begins_with("axle")

static func is_fixed(a: String, b: String) -> bool:
	return not is_revolute(a, b)
