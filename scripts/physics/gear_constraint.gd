extends Node
class_name GearConstraint
## Soft bidirectional velocity constraint: teeth_a * ω_a + teeth_b * ω_b ≈ 0
## Mass-weighted, catch-up capped. See docs/physics.md.

const MAX_OMEGA := 25.0
## Blend toward zero constraint error each tick (0..1).
const FOLLOW_DEFAULT := 0.4
## Max |Δω| applied to one body per tick (rad/s) — limits energy injection.
const MAX_CATCHUP_DELTA := 2.0
## Damp angular velocity orthogonal to gear axis (both bodies).
const TANGENTIAL_DAMP := 0.94
## Optional debug metrics (throttled print). Keep false in shipping builds.
const DEBUG_METRICS := false

var gear_a: TechnicPart
var gear_b: TechnicPart
var teeth_a: int = 8
var teeth_b: int = 16
var enabled: bool = true
var follow: float = FOLLOW_DEFAULT

## Last / EMA of |wb - (-wa * teeth_a/teeth_b)| (post-correction residual).
static var last_abs_error: float = 0.0
static var ema_abs_error: float = 0.0
static var _metric_sum: float = 0.0
static var _metric_max: float = 0.0
static var _metric_count: int = 0
static var _metric_frames: int = 0

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

	var axis_a: Vector3 = (gear_a.global_transform.basis * Vector3.UP).normalized()
	var axis_b: Vector3 = (gear_b.global_transform.basis * Vector3.UP).normalized()
	var wa_vel: float = gear_a.angular_velocity.dot(axis_a)
	var wb_vel: float = gear_b.angular_velocity.dot(axis_b)
	wa_vel = clampf(wa_vel, -MAX_OMEGA, MAX_OMEGA)
	wb_vel = clampf(wb_vel, -MAX_OMEGA, MAX_OMEGA)

	# Constraint residual: teeth_a * ω_a + teeth_b * ω_b should be ~0
	var ta := float(teeth_a)
	var tb := float(teeth_b)
	var error: float = ta * wa_vel + tb * wb_vel

	var mass_a: float = maxf(gear_a.mass, 0.05)
	var mass_b: float = maxf(gear_b.mass, 0.05)
	var inv_a: float = 1.0 / mass_a
	var inv_b: float = 1.0 / mass_b
	var denom: float = ta * ta * inv_a + tb * tb * inv_b
	var lambda: float = 0.0
	if denom > 1e-8:
		# Reduce error by `follow` this tick (impulse-like split by inverse mass).
		lambda = (follow * error) / denom

	# Limit |λ| so BOTH bodies stay within MAX_CATCHUP_DELTA (keeps impulse ratio intact).
	var coeff_a: float = ta * inv_a
	var coeff_b: float = tb * inv_b
	var max_abs_lambda: float = 1.0e12
	if coeff_a > 1e-8:
		max_abs_lambda = minf(max_abs_lambda, MAX_CATCHUP_DELTA / coeff_a)
	if coeff_b > 1e-8:
		max_abs_lambda = minf(max_abs_lambda, MAX_CATCHUP_DELTA / coeff_b)
	lambda = clampf(lambda, -max_abs_lambda, max_abs_lambda)

	var dwa: float = -lambda * coeff_a
	var dwb: float = -lambda * coeff_b

	# Ratio-aware omega ceilings so MAX_OMEGA cannot force sustained clamp slip.
	var max_a: float = minf(MAX_OMEGA, MAX_OMEGA * tb / ta)
	var max_b: float = minf(MAX_OMEGA, MAX_OMEGA * ta / tb)
	var new_a: float = clampf(wa_vel + dwa, -max_a, max_a)
	var new_b: float = clampf(wb_vel + dwb, -max_b, max_b)

	# If independent ceiling clipped one side, re-pair to keep teeth*ω sum ≈ 0.
	var post_err: float = ta * new_a + tb * new_b
	if absf(post_err) > 1e-4 and denom > 1e-8:
		var lam2: float = post_err / denom
		var a2: float = new_a - lam2 * coeff_a
		var b2: float = new_b - lam2 * coeff_b
		if absf(a2) <= max_a + 1e-6 and absf(b2) <= max_b + 1e-6:
			new_a = a2
			new_b = b2
		else:
			var scale: float = 1.0
			if absf(new_a) > 1e-6:
				scale = minf(scale, max_a / absf(new_a))
			if absf(new_b) > 1e-6:
				scale = minf(scale, max_b / absf(new_b))
			var drive_a: float = new_a * scale
			var paired_b: float = -drive_a * (ta / tb)
			if absf(paired_b) <= max_b + 1e-6:
				new_a = drive_a
				new_b = paired_b
			else:
				var drive_b: float = new_b * scale
				var paired_a: float = -drive_b * (tb / ta)
				new_a = clampf(paired_a, -max_a, max_a)
				new_b = clampf(drive_b, -max_b, max_b)

	var tang_a: Vector3 = gear_a.angular_velocity - axis_a * wa_vel
	var tang_b: Vector3 = gear_b.angular_velocity - axis_b * wb_vel
	gear_a.angular_velocity = tang_a * TANGENTIAL_DAMP + axis_a * new_a
	gear_b.angular_velocity = tang_b * TANGENTIAL_DAMP + axis_b * new_b

	_clamp(gear_a)
	_clamp(gear_b)

	# Post-correction ratio residual (cheap last/EMA always; print if DEBUG_METRICS).
	var ratio: float = ta / tb
	var ratio_err: float = new_b - (-new_a * ratio)
	_record_metric(ratio_err)

static func _record_metric(ratio_err: float) -> void:
	var abs_e: float = absf(ratio_err)
	last_abs_error = abs_e
	ema_abs_error = lerpf(ema_abs_error, abs_e, 0.08)
	if not DEBUG_METRICS:
		return
	_metric_sum += abs_e
	_metric_max = maxf(_metric_max, abs_e)
	_metric_count += 1
	_metric_frames += 1
	if _metric_frames >= 60 and _metric_count > 0:
		var avg: float = _metric_sum / float(_metric_count)
		print("GEAR_METRICS: avg|err|=%.4f max|err|=%.4f ema=%.4f n=%d" % [avg, _metric_max, ema_abs_error, _metric_count])
		_metric_sum = 0.0
		_metric_max = 0.0
		_metric_count = 0
		_metric_frames = 0

static func reset_metrics() -> void:
	last_abs_error = 0.0
	ema_abs_error = 0.0
	_metric_sum = 0.0
	_metric_max = 0.0
	_metric_count = 0
	_metric_frames = 0

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
