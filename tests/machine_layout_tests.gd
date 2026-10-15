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
	check(is_equal_approx(MachineLayout.pusher_front_y(0.0, 2.4, 36.0, 40.0), 40.0), "pusher rests at t=0")
	check(is_equal_approx(MachineLayout.pusher_front_y(1.2, 2.4, 36.0, 40.0), 76.0), "pusher fully extended at half period")
	check(is_equal_approx(MachineLayout.pusher_front_y(2.4, 2.4, 36.0, 40.0), 40.0), "pusher back to rest after one period")
	var quarter: float = MachineLayout.pusher_front_y(0.6, 2.4, 36.0, 40.0)
	check(quarter > 40.0 and quarter < 76.0, "quarter period is between rest and extended")
	check(is_equal_approx(MachineLayout.pusher_front_y(5.0, 0.0, 36.0, 40.0), 40.0), "zero period stays at rest")


func test_classify() -> void:
	check(MachineLayout.classify(Vector2(200, 100)) == MachineLayout.Zone.BOARD, "back shelf centre is board")
	check(MachineLayout.classify(Vector2(5, 100)) == MachineLayout.Zone.BOARD, "back shelf has no gutter")
	check(MachineLayout.classify(Vector2(5, 200)) == MachineLayout.Zone.LOST_LEFT, "front platform left gutter loses")
	check(MachineLayout.classify(Vector2(395, 200)) == MachineLayout.Zone.LOST_RIGHT, "front platform right gutter loses")
	check(MachineLayout.classify(Vector2(18, 200)) == MachineLayout.Zone.BOARD, "gutter edge x=18 is still board")
	check(MachineLayout.classify(Vector2(200, 279.9)) == MachineLayout.Zone.BOARD, "just before drop line is board")
	check(MachineLayout.classify(Vector2(200, 280.0)) == MachineLayout.Zone.SCORED, "drop line scores")
	check(MachineLayout.classify(Vector2(5, 290)) == MachineLayout.Zone.SCORED, "drop line wins over gutter")


func test_cycle_index() -> void:
	check(MachineLayout.cycle_index(0.0, 2.4) == 0, "cycle 0 at start")
	check(MachineLayout.cycle_index(2.39, 2.4) == 0, "still cycle 0 just before period")
	check(MachineLayout.cycle_index(2.4, 2.4) == 1, "cycle 1 at exactly one period")
	check(MachineLayout.cycle_index(7.3, 2.4) == 3, "cycle 3 at 7.3s")


func test_tuning_defaults() -> void:
	var t: MachineTuning = load("res://game/machine/machine_tuning.tres")
	check(t != null, "tuning resource loads")
	check(is_equal_approx(t.pusher_period, 2.4), "default period 2.4")
	check(is_equal_approx(t.pusher_stroke, 36.0), "default stroke 36")
	check(is_equal_approx(t.linear_damp, 3.0), "default damp 3.0")
	check(is_equal_approx(t.fire_speed, 180.0), "default fire speed 180")
	check(is_equal_approx(t.fire_cooldown, 0.25), "default cooldown 0.25")
	check(t.clip_size == 20, "default clip 20")
	check(is_equal_approx(t.coin_radius, 7.0), "copper radius 7")
	check(is_equal_approx(t.bed_spacing, 17.0), "bed spacing 17")
