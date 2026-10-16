extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var tuning: MachineTuning = load("res://game/machine/machine_tuning.tres")
	await test_coin_setup(tuning)
	await test_coin_launch(tuning)
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
	check(is_equal_approx(coin.physics_material_override.bounce, tuning.bounce), "bounce from tuning")
	var shape: CollisionShape3D = coin.get_node("Shape")
	check(shape != null and shape.shape is CylinderShape3D, "cylinder collider")
	check(is_equal_approx((shape.shape as CylinderShape3D).radius, tuning.coin_radius) and is_equal_approx((shape.shape as CylinderShape3D).height, tuning.coin_thickness), "cylinder matches radius and thickness")
	var mesh: MeshInstance3D = coin.get_node("Mesh")
	check(mesh != null and mesh.mesh is CylinderMesh, "placeholder cylinder mesh")
	coin.place(Vector3(1, 0.07, 2))
	await physics_frame
	check(not coin.is_airborne and coin.collision_layer == 1 and coin.collision_mask == 1, "placed coin is solid")
	coin.apply_friction(0.9)
	coin.apply_bounce(0.5)
	check(is_equal_approx(coin.physics_material_override.friction, 0.9) and is_equal_approx(coin.physics_material_override.bounce, 0.5), "apply_friction/apply_bounce update material")
	coin.queue_free()
	await physics_frame


func test_coin_launch(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 1, 1, Color.WHITE)
	root.add_child(coin)
	var origin: Vector3 = MachineLayout.side_chute_origin(MachineLayout.Chute.LEFT)
	var vel: Vector3 = MachineLayout.side_chute_velocity(MachineLayout.Chute.LEFT, 22.0, 20.0)
	check(origin.x < -8.0 and origin.y > MachineLayout.PUSHER_HEIGHT, "left chute origin is at the left wall above the pusher top")
	check(vel.x > 0.0 and vel.y < 0.0 and is_zero_approx(vel.z), "left chute velocity points inward and downward")
	var rvel: Vector3 = MachineLayout.side_chute_velocity(MachineLayout.Chute.RIGHT, 22.0, 20.0)
	check(rvel.x < 0.0, "right chute velocity points left")
	check(is_equal_approx(MachineLayout.top_chute_origin(99.0).x, MachineLayout.TOP_AIM_MAX_X), "top chute aim is clamped")
	coin.launch(origin, Basis(Vector3.FORWARD, deg_to_rad(90.0)), vel, Vector3(0, 0, -44.0))
	await physics_frame
	check(coin.is_airborne and coin.collision_layer == 1 and not coin.freeze, "launched coin is airborne but a real physics body")
	check(coin.linear_velocity.x > 10.0, "launch velocity applied")
	for _i in range(6):
		await physics_frame
	check(coin.position.x > origin.x + 1.0, "coin flies inward after launch (x=%.2f)" % coin.position.x)
	for _i in range(200):
		coin.tick_airborne(1.0 / 60.0)
		await physics_frame
	check(not coin.is_airborne, "coin stops being airborne after it slows or 3s pass")
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
