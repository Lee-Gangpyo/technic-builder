extends Node
class_name GearConstraint
## Soft velocity constraint: ω_b ≈ -ω_a * (teeth_a / teeth_b)
## See docs/physics.md.

const MAX_OMEGA := 25.0

var gear_a: TechnicPart
var gear_b: TechnicPart
var teeth_a: int = 8
var teeth_b: int = 16
var enabled: bool = true
var follow: float = 0.5

func setup(a: TechnicPart, b: TechnicPart) -> void:
	gear_a = a
	gear_b = b
	teeth_a = maxi(a.teeth, 1)
	teeth_b = maxi(b.teeth, 1)
	name = "GearConstraint_%s_%s" % [a.part_id, b.part_id]

func _physics_process(_delta: float) -> void:
	if not enabled or gear_a == null or gear_b == null:
		return
	if not is_instance_valid(gear_a) or not is_instance_valid(gear_b):
		queue_free()
		return
	if gear_a.freeze or gear_b.freeze:
		return
	var wa: Vector3 = (gear_a.global_transform.basis * Vector3.UP).normalized()
	var wb: Vector3 = (gear_b.global_transform.basis * Vector3.UP).normalized()
	var wa_vel: float = clampf(gear_a.angular_velocity.dot(wa), -MAX_OMEGA, MAX_OMEGA)
	var ratio: float = float(teeth_a) / float(teeth_b)
	var target_b: float = -wa_vel * ratio
	var wb_vel: float = gear_b.angular_velocity.dot(wb)
	var new_b: float = lerpf(wb_vel, target_b, follow)
	var tang_b: Vector3 = gear_b.angular_velocity - wb * wb_vel
	gear_b.angular_velocity = tang_b * 0.85 + wb * clampf(new_b, -MAX_OMEGA, MAX_OMEGA)
	_clamp(gear_a)
	_clamp(gear_b)

static func _clamp(p: TechnicPart) -> void:
	if p.angular_velocity.length() > MAX_OMEGA:
		p.angular_velocity = p.angular_velocity.limit_length(MAX_OMEGA)

static func pitch_distance(a: TechnicPart, b: TechnicPart) -> float:
	var ra: float = float(a.part_data.get("pitch_radius_m", 0.01)) * 100.0
	var rb: float = float(b.part_data.get("pitch_radius_m", 0.01)) * 100.0
	return ra + rb

static func are_meshed(a: TechnicPart, b: TechnicPart, slop: float = 0.5) -> bool:
	if not a.is_gear or not b.is_gear:
		return false
	var expected: float = pitch_distance(a, b)
	var d: float = a.global_position.distance_to(b.global_position)
	return absf(d - expected) < slop + 1.2
