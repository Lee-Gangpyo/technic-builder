extends RefCounted
class_name MotionPresets
## Motor / hinge presets for assembly templates (kart, gear demo, crane).
## Keep JointFactory.create_joint signature unchanged — this only tunes parts/hinges.

enum Kind { KART, GEAR_DEMO, CRANE }

## rpm_factor * max_rpm, max_torque, motor_lerp, motor_max_domega
const MOTOR := {
	Kind.KART: {"rpm_factor": 0.58, "max_torque": 0.15, "motor_lerp": 0.10, "motor_max_domega": 1.5},
	Kind.GEAR_DEMO: {"rpm_factor": 0.40, "max_torque": 0.12, "motor_lerp": 0.12, "motor_max_domega": 1.2},
	Kind.CRANE: {"rpm_factor": 0.35, "max_torque": 0.28, "motor_lerp": 0.08, "motor_max_domega": 1.0},
}

## Hinge bias / limit_relaxation (CRANE stiffer than JointFactory web_stable 0.25 / 0.8)
const HINGE := {
	Kind.CRANE: {"bias": 0.35, "relaxation": 0.9},
}


static func apply_motor(part: TechnicPart, kind: Kind) -> void:
	if part == null or not is_instance_valid(part):
		return
	var cfg: Dictionary = MOTOR.get(kind, MOTOR[Kind.KART])
	var max_rpm: float = float(part.part_data.get("max_rpm", 200))
	part.target_rpm = max_rpm * float(cfg["rpm_factor"])
	part.max_torque = float(cfg["max_torque"])
	part.motor_lerp = float(cfg["motor_lerp"])
	part.motor_max_domega = float(cfg["motor_max_domega"])


static func tune_hinge(hinge: HingeJoint3D, kind: Kind) -> void:
	if hinge == null or not is_instance_valid(hinge):
		return
	if not HINGE.has(kind):
		return
	var cfg: Dictionary = HINGE[kind]
	hinge.set_param(HingeJoint3D.PARAM_BIAS, float(cfg["bias"]))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_RELAXATION, float(cfg["relaxation"]))
	# Free hinges stay motor-off (drive is TechnicPart omega blend).
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
