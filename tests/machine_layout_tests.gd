extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	test_pusher_motion()
	test_classify()
	test_cycle_index()
	test_tuning_defaults()
	print("MachineLayout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func test_pusher_motion() -> void:
	check(is_equal_approx(MachineLayout.pusher_front_z(0.0, 2.4, 4.0, -4.0), -4.0), "pusher rests at t=0")
	check(is_equal_approx(MachineLayout.pusher_front_z(1.2, 2.4, 4.0, -4.0), 0.0), "pusher fully extended at half period")
	check(is_equal_approx(MachineLayout.pusher_front_z(2.4, 2.4, 4.0, -4.0), -4.0), "pusher back to rest after one period")
	var quarter: float = MachineLayout.pusher_front_z(0.6, 2.4, 4.0, -4.0)
	check(quarter > -4.0 and quarter < 0.0, "quarter period is between rest and extended")
	check(is_equal_approx(MachineLayout.pusher_front_z(5.0, 0.0, 4.0, -4.0), -4.0), "zero period stays at rest")


func test_classify() -> void:
	check(MachineLayout.classify(Vector3(0, 0.06, 2)) == MachineLayout.Zone.BOARD, "coin on platform is board")
	check(MachineLayout.classify(Vector3(0, 1.3, -2)) == MachineLayout.Zone.BOARD, "coin on pusher top is board")
	check(MachineLayout.classify(Vector3(0, -0.5, 5.5)) == MachineLayout.Zone.BOARD, "slightly below top but above DROP_Y is still board")
	check(MachineLayout.classify(Vector3(0, -1.5, 5.5)) == MachineLayout.Zone.SCORED, "fell past front edge scores")
	check(MachineLayout.classify(Vector3(-9.6, -1.5, 4.0)) == MachineLayout.Zone.LOST_LEFT, "fell into left gutter is lost left")
	check(MachineLayout.classify(Vector3(9.6, -1.5, 4.0)) == MachineLayout.Zone.LOST_RIGHT, "fell into right gutter is lost right")
	check(MachineLayout.classify(Vector3(0, -1.5, 4.9)) == MachineLayout.Zone.LOST_RIGHT, "fell before SCORE_MIN_Z counts as lost")


func test_cycle_index() -> void:
	check(MachineLayout.cycle_index(0.0, 2.4) == 0, "cycle 0 at start")
	check(MachineLayout.cycle_index(2.39, 2.4) == 0, "still cycle 0 just before period")
	check(MachineLayout.cycle_index(2.4, 2.4) == 1, "cycle 1 at exactly one period")
	check(MachineLayout.cycle_index(7.3, 2.4) == 3, "cycle 3 at 7.3s")


func test_tuning_defaults() -> void:
	var t: MachineTuning = load("res://game/machine/machine_tuning.tres")
	check(t != null, "tuning resource loads")
	check(is_equal_approx(t.pusher_period, 2.4), "default period 2.4")
	check(is_equal_approx(t.pusher_stroke, 6.0), "default stroke 6")
	check(is_equal_approx(t.friction, 0.2), "default friction 0.2")
	check(is_equal_approx(t.fire_speed, 14.0), "default fire speed 14")
	check(is_equal_approx(t.fire_cooldown, 0.25), "default cooldown 0.25")
	check(t.clip_size == 20, "default clip 20")
	check(is_equal_approx(t.coin_radius, 0.5), "coin radius 0.5")
	check(is_equal_approx(t.coin_thickness, 0.12), "coin thickness 0.12")
	check(is_equal_approx(t.bed_spacing, 1.02), "bed spacing 1.02")
	check(t.settle_cycles == 2, "settle after 2 cycles")
