extends RefCounted
class_name JointFactory
## Creates pin (fixed) or axle (hinge) joints between Technic parts.

static func create_joint(parent: Node, part_a: TechnicPart, cid_a: String, part_b: TechnicPart, cid_b: String, type_a: String, type_b: String) -> Joint3D:
	var revolute := ConnectionTypes.is_revolute(type_a, type_b)
	var anchor := part_a.get_connector_global(cid_a).origin

	if revolute:
		var hinge := HingeJoint3D.new()
		hinge.name = "Hinge_%s_%s" % [cid_a, cid_b]
		parent.add_child(hinge)
		var axis := part_a.world_axis_of(cid_a)
		if axis.length_squared() > 0.01:
			hinge.global_transform = Transform3D(_basis_from_x(axis), anchor)
		else:
			hinge.global_position = anchor
		hinge.node_a = hinge.get_path_to(part_a)
		hinge.node_b = hinge.get_path_to(part_b)
		hinge.set_param(HingeJoint3D.PARAM_BIAS, 0.3)
		return hinge
	else:
		var j := Generic6DOFJoint3D.new()
		j.name = "Fixed_%s_%s" % [cid_a, cid_b]
		parent.add_child(j)
		j.global_position = anchor
		j.node_a = j.get_path_to(part_a)
		j.node_b = j.get_path_to(part_b)
		_lock_6dof(j)
		return j

static func _lock_6dof(j: Generic6DOFJoint3D) -> void:
	j.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	j.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	j.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	j.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	j.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	j.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	j.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	j.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	j.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	j.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	j.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	j.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
	j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
	j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
	j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
	j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
	j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)

static func _basis_from_x(x_axis: Vector3) -> Basis:
	var x := x_axis.normalized()
	var y := Vector3.UP
	if absf(x.dot(y)) > 0.9:
		y = Vector3.RIGHT
	var z := x.cross(y).normalized()
	y = z.cross(x).normalized()
	return Basis(x, y, z)
