extends SceneTree
## Headless 開主場景，模擬發幣，驗證統計有變。

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var machine: Machine = main.get_node_or_null("Machine")
	check(machine != null, "main scene has a Machine child named Machine")
	var hud: Label = main.find_child("Hud", true, false)
	check(hud != null and hud.text.length() > 0, "HUD label exists and has text")
	check(main.find_child("Camera", true, false) is Camera3D, "scene has a Camera3D")
	if machine == null:
		finish()
		return
	var bed: int = machine.coins_on_board()
	check(bed > 80, "bed coins spawned (got %d)" % bed)
	check(machine.clip == 20, "clip starts at 20")
	main.call("demo_fire", MachineLayout.Chute.LEFT)
	await physics_frame
	check(machine.clip == 19, "demo_fire(left) fires one coin")
	check(machine.coins_on_board() == bed + 1, "fired coin is on board")
	main.call("demo_fire", MachineLayout.Chute.TOP)
	await physics_frame
	check(machine.clip == 18, "demo_fire(top) fires one coin")
	machine.set_aim_x(3.0)
	check(is_equal_approx(machine.aim_x, 3.0), "aim_x set")
	check(machine.find_child("AimMarker", true, false) != null, "aim marker exists")
	main.call("demo_adjust", "period", 1)
	check(machine.tuning.pusher_period > 2.4, "period adjust up works")
	main.call("demo_adjust", "period", -1)
	check(is_equal_approx(machine.tuning.pusher_period, 2.4), "period adjust down restores")
	main.call("demo_adjust", "friction", 1)
	check(is_equal_approx(machine.tuning.friction, 0.25), "friction adjust +0.05")
	main.call("demo_adjust", "friction", -1)
	main.call("demo_adjust", "bounce", 1)
	check(is_equal_approx(machine.tuning.bounce, 0.3), "bounce adjust +0.05")
	main.call("demo_adjust", "bounce", -1)
	check(hud.text.find("彈匣") >= 0, "HUD shows clip label in Chinese")
	finish()


func finish() -> void:
	print("Smoke: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
