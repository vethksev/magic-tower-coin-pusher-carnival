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
	var hud: Label = main.get_node_or_null("Hud")
	check(hud != null and hud.text.length() > 0, "HUD label exists and has text")
	if machine == null:
		finish()
		return
	var bed: int = machine.coins_on_board()
	check(bed > 300, "bed coins spawned (got %d)" % bed)
	check(machine.clip == 20, "clip starts at 20")
	main.call("demo_fire", 0)
	await physics_frame
	check(machine.clip == 19, "demo_fire(0) fires one coin")
	check(machine.coins_on_board() == bed + 1, "fired coin is on board")
	main.call("demo_adjust", "period", 1)
	check(machine.tuning.pusher_period > 2.4, "period adjust up works")
	main.call("demo_adjust", "period", -1)
	check(is_equal_approx(machine.tuning.pusher_period, 2.4), "period adjust down restores")
	main.call("demo_adjust", "damp", 1)
	check(is_equal_approx(machine.tuning.linear_damp, 3.5), "damp adjust +0.5")
	main.call("demo_adjust", "damp", -1)
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
