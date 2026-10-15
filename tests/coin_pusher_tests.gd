extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var tuning: MachineTuning = load("res://game/machine/machine_tuning.tres")
	await test_coin_setup(tuning)
	await test_coin_flight(tuning)
	await test_pusher(tuning)
	print("CoinPusher: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func test_coin_setup(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 3, 42, Color.WHITE)
	root.add_child(coin)
	await physics_frame
	check(coin.value == 3 and coin.uid == 42, "coin keeps value and uid")
	check(is_equal_approx(coin.radius, tuning.coin_radius), "coin radius from tuning")
	check(is_zero_approx(coin.gravity_scale), "coin has no gravity")
	check(coin.linear_damp_mode == RigidBody2D.DAMP_MODE_REPLACE, "damp replaces project default")
	check(is_equal_approx(coin.linear_damp, tuning.linear_damp), "coin damp from tuning")
	check(coin.physics_material_override != null and is_equal_approx(coin.physics_material_override.friction, tuning.friction), "friction from tuning")
	var shape: CollisionShape2D = coin.get_node("Shape")
	check(shape != null and shape.shape is CircleShape2D and is_equal_approx((shape.shape as CircleShape2D).radius, tuning.coin_radius), "circle collider matches radius")
	coin.place(Vector2(100, 100))
	await physics_frame
	check(not coin.is_airborne and coin.collision_layer == 1 and coin.collision_mask == 1, "placed coin is solid")
	coin.queue_free()
	await physics_frame


func test_coin_flight(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 1, 1, Color.WHITE)
	root.add_child(coin)
	var landed_box: Dictionary = {"count": 0, "pos": Vector2.ZERO}
	coin.landed.connect(func(c: Coin) -> void:
		landed_box["count"] += 1
		landed_box["pos"] = c.position)
	coin.launch(Vector2(30, 48), Vector2(90, 70), 0.3, Vector2(60, 20))
	await physics_frame
	check(coin.is_airborne and coin.collision_layer == 0 and coin.collision_mask == 0, "airborne coin does not collide")
	check(coin.freeze, "airborne coin is frozen (kinematic)")
	for _i in range(8):
		await physics_frame
	check(coin.position.x > 30.0 and coin.position.x < 90.0, "coin moves along flight path")
	for _i in range(16):
		await physics_frame
	check(not coin.is_airborne, "coin lands after flight time")
	check((landed_box["pos"] as Vector2).distance_to(Vector2(90, 70)) < 0.5, "coin lands at target")
	check(landed_box["count"] == 1, "landed emitted exactly once")
	check(not coin.freeze and coin.collision_layer == 1, "landed coin is physical")
	check(coin.linear_velocity.length() > 10.0, "landing velocity applied")
	coin.queue_free()
	await physics_frame


func test_pusher(tuning: MachineTuning) -> void:
	var pusher: Pusher = Pusher.new()
	root.add_child(pusher)
	pusher.configure(tuning)
	await physics_frame
	check(is_equal_approx(pusher.front_y(), tuning.pusher_rest_y), "pusher starts at rest")
	check(is_equal_approx(pusher.position.x, MachineLayout.WIDTH / 2.0), "pusher centred horizontally")
	check(is_equal_approx(pusher.position.y, tuning.pusher_rest_y - tuning.pusher_thickness / 2.0), "pusher body sits behind its front face")
	var cycles_box: Dictionary = {"count": 0, "last": -1}
	pusher.cycle_completed.connect(func(i: int) -> void:
		cycles_box["count"] += 1
		cycles_box["last"] = i)
	var dt: float = 1.0 / 60.0
	for _i in range(72):
		pusher.step(dt)
	check(absf(pusher.front_y() - (tuning.pusher_rest_y + tuning.pusher_stroke)) < 1.5, "after half period pusher is near full extension")
	for _i in range(73):
		pusher.step(dt)
	check(cycles_box["count"] == 1 and cycles_box["last"] == 1, "one cycle completed after full period")
	check(absf(pusher.front_y() - tuning.pusher_rest_y) < 1.5, "pusher back near rest")
	var before_phase: float = fmod(pusher.time, tuning.pusher_period) / tuning.pusher_period
	pusher.set_period_keep_phase(1.2)
	var after_phase: float = fmod(pusher.time, 1.2) / 1.2
	check(absf(before_phase - after_phase) < 0.01, "changing period keeps phase")
	check(is_equal_approx(tuning.pusher_period, 1.2), "period written back to tuning")
	tuning.pusher_period = 2.4
	pusher.queue_free()
	await physics_frame
