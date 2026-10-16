extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var tuning: MachineTuning = load("res://game/machine/machine_tuning.tres")
	await test_coin_setup(tuning)
	await test_coin_slide(tuning)
	await test_coin_falls(tuning)
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
	check(is_equal_approx(coin.mass, tuning.coin_mass), "coin mass from tuning")
	check(coin.physics_material_override != null and is_equal_approx(coin.physics_material_override.friction, tuning.friction), "friction from tuning")
	var shape: CollisionShape3D = coin.get_node("Shape")
	check(shape != null and shape.shape is CylinderShape3D, "cylinder collider")
	check(is_equal_approx((shape.shape as CylinderShape3D).radius, tuning.coin_radius) and is_equal_approx((shape.shape as CylinderShape3D).height, tuning.coin_thickness), "cylinder matches radius and thickness")
	var mesh: MeshInstance3D = coin.get_node("Mesh")
	check(mesh != null and mesh.mesh is CylinderMesh, "placeholder cylinder mesh")
	coin.place(Vector3(1, 0.07, 2))
	await physics_frame
	check(not coin.is_airborne and coin.collision_layer == 1 and coin.collision_mask == 1, "placed coin is solid")
	coin.apply_friction(0.9)
	check(is_equal_approx(coin.physics_material_override.friction, 0.9), "apply_friction updates material")
	coin.queue_free()
	await physics_frame


func test_coin_slide(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 1, 1, Color.WHITE)
	root.add_child(coin)
	var landed_box: Dictionary = {"count": 0, "pos": Vector3.ZERO}
	coin.landed.connect(func(c: Coin) -> void:
		landed_box["count"] += 1
		landed_box["pos"] = c.position)
	coin.begin_slide(Vector3(-9.4, 1.28, -2.0), 1.0, 14.0)
	await physics_frame
	check(coin.is_airborne and coin.collision_layer == 0 and coin.collision_mask == 0, "sliding coin does not collide")
	check(coin.freeze, "sliding coin is frozen (kinematic)")
	check(coin.position.is_equal_approx(Vector3(-9.4, 1.28, -2.0)), "sliding coin stays put until Machine moves it")
	var nxt: Vector3 = coin.slide_next(0.1)
	check(is_equal_approx(nxt.x, -8.0) and is_equal_approx(nxt.z, -2.0), "slide_next advances 1.4 units right per 0.1s at 14/s")
	coin.begin_slide(Vector3(9.4, 1.28, -2.0), -1.0, 14.0)
	nxt = coin.slide_next(0.1)
	check(is_equal_approx(nxt.x, 8.0), "slide_next goes left for right chute")
	coin.land_at(Vector3(0, 1.28, -2.0), Vector3(2, 0, 1))
	await physics_frame
	check(not coin.is_airborne and not coin.freeze and coin.collision_layer == 1, "landed coin is physical")
	check(landed_box["count"] == 1 and (landed_box["pos"] as Vector3).is_equal_approx(Vector3(0, 1.28, -2.0)), "landed emitted once at landing position")
	coin.queue_free()
	await physics_frame


func test_coin_falls(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 1, 2, Color.WHITE)
	root.add_child(coin)
	coin.place(Vector3(0, 5, 0))
	await physics_frame
	for _i in range(30):
		await physics_frame
	check(coin.position.y < 4.0, "unsupported coin falls under gravity (y=%.2f)" % coin.position.y)
	coin.queue_free()
	await physics_frame


func test_pusher(tuning: MachineTuning) -> void:
	var pusher: Pusher = Pusher.new()
	root.add_child(pusher)
	pusher.configure(tuning)
	await physics_frame
	check(is_equal_approx(pusher.front_z(), MachineLayout.PUSHER_REST_FRONT_Z), "pusher starts at rest")
	check(is_equal_approx(pusher.position.y, MachineLayout.PUSHER_HEIGHT / 2.0), "pusher body sits on the platform")
	check(is_equal_approx(pusher.position.z, MachineLayout.PUSHER_REST_FRONT_Z - MachineLayout.PUSHER_DEPTH / 2.0), "pusher body centre is behind its front face")
	check(is_equal_approx(pusher.top_y(), MachineLayout.PUSHER_HEIGHT), "top_y is the pusher height")
	var cycles_box: Dictionary = {"count": 0, "last": -1}
	pusher.cycle_completed.connect(func(i: int) -> void:
		cycles_box["count"] += 1
		cycles_box["last"] = i)
	var dt: float = 1.0 / 60.0
	for _i in range(72):
		pusher.step(dt)
	check(absf(pusher.front_z() - (MachineLayout.PUSHER_REST_FRONT_Z + tuning.pusher_stroke)) < 0.2, "after half period pusher is near full extension")
	check(absf(pusher.front_z_after(1.2) - MachineLayout.PUSHER_REST_FRONT_Z) < 0.2, "front_z_after predicts rest half a period later")
	for _i in range(73):
		pusher.step(dt)
	check(cycles_box["count"] == 1 and cycles_box["last"] == 1, "one cycle completed after full period")
	check(absf(pusher.front_z() - MachineLayout.PUSHER_REST_FRONT_Z) < 0.2, "pusher back near rest")
	var before_phase: float = fmod(pusher.time, tuning.pusher_period) / tuning.pusher_period
	pusher.set_period_keep_phase(1.2)
	var after_phase: float = fmod(pusher.time, 1.2) / 1.2
	check(absf(before_phase - after_phase) < 0.01, "changing period keeps phase")
	check(is_equal_approx(tuning.pusher_period, 1.2), "period written back to tuning")
	tuning.pusher_period = 2.4
	pusher.queue_free()
	await physics_frame
