extends RefCounted
class_name SnapSystem
## Magnet-snap: find nearest compatible free connectors and return snap transform.

static func find_snap(moving: TechnicPart, candidates: Array, snap_dist: float, snap_angle_deg: float) -> Dictionary:
	## Returns {found, target_part, moving_cid, target_cid, transform} or empty.
	var best := {}
	var best_d := snap_dist
	var max_dot := cos(deg_to_rad(snap_angle_deg))
	for c_move in moving.get_free_connectors():
		var mnode: Marker3D = c_move["node"]
		var mpos := mnode.global_position
		var maxis: Vector3 = (moving.global_transform.basis * c_move["axis_local"]).normalized()
		for other in candidates:
			if other == moving or not (other is TechnicPart):
				continue
			var op: TechnicPart = other
			for c_tgt in op.get_free_connectors():
				if not ConnectionTypes.compatible(c_move["type"], c_tgt["type"]):
					continue
				var tnode: Marker3D = c_tgt["node"]
				var tpos := tnode.global_position
				var d := mpos.distance_to(tpos)
				if d >= best_d:
					continue
				var taxis: Vector3 = (op.global_transform.basis * c_tgt["axis_local"]).normalized()
				# axes should be parallel (same or opposite)
				var align := absf(maxis.dot(taxis))
				if align < max_dot:
					continue
				best_d = d
				best = {
					"found": true,
					"target_part": op,
					"moving_cid": c_move["id"],
					"target_cid": c_tgt["id"],
					"moving_type": c_move["type"],
					"target_type": c_tgt["type"],
					"target_pos": tpos,
					"target_axis": taxis,
					"distance": d
				}
	return best

static func compute_snap_transform(moving: TechnicPart, snap: Dictionary) -> Transform3D:
	## Align moving connector to target connector position/axis.
	var mcid: String = snap["moving_cid"]
	var c_move = null
	for c in moving.connectors:
		if c["id"] == mcid:
			c_move = c
			break
	if c_move == null:
		return moving.global_transform
	var mnode: Marker3D = c_move["node"]
	var local_offset := mnode.position  # in moving space
	var target_pos: Vector3 = snap["target_pos"]
	var target_axis: Vector3 = snap["target_axis"]
	var move_axis: Vector3 = (moving.global_transform.basis * c_move["axis_local"]).normalized()

	var xf := moving.global_transform
	# Rotate so axes align
	if absf(move_axis.dot(target_axis)) < 0.999:
		var from_a := move_axis
		var to_a := target_axis if move_axis.dot(target_axis) >= 0.0 else -target_axis
		var axis := from_a.cross(to_a)
		if axis.length_squared() > 1e-8:
			axis = axis.normalized()
			var ang := from_a.angle_to(to_a)
			xf.basis = Basis(axis, ang) * xf.basis
	# Recompute connector world after rotation
	var new_conn_world := xf.origin + xf.basis * local_offset
	xf.origin += target_pos - new_conn_world
	return xf
