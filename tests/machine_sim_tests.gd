extends SceneTree
## Headless 3D 物理模擬。建議加 --fixed-fps 60 跑；唔加就係真實時間。

var checks: int = 0
var failures: int = 0

const FIRE_GAP_TICKS: int = 16     # 0.25s 冷卻 = 15 ticks，用 16 保證冷卻已過
const TOTAL_TICKS: int = 1500      # 25 秒


func _initialize() -> void:
	run()


func run() -> void:
	var a: Dictionary = await simulate(7, 20, "sides")
	var b: Dictionary = await simulate(7, 20, "sides")
	var c: Dictionary = await simulate(8, 20, "sides")
	var top: Dictionary = await simulate(7, 20, "top")
	var idle: Dictionary = await simulate(7, 0, "sides")
	var bed: int = a["bed_count"]
	check(bed >= 80 and bed <= 250, "bed has roughly 100-200 coins (got %d)" % bed)
	check(idle["scored"] <= 3 and idle["lost"] <= 3, "bed is stable with no firing (scored %d lost %d)" % [idle["scored"], idle["lost"]])
	check(a["fired"] == 20, "all 20 clip coins fired from side chutes (got %d)" % a["fired"])
	check(a["scored"] + a["lost"] + a["on_board"] == bed + 20, "every coin is scored, lost or on board")
	check(a["scored"] >= 2, "firing 20 side coins drops at least 2 within 25s (got %d)" % a["scored"])
	check(a["scored"] >= a["lost"], "side chutes: scored >= lost (%d vs %d)" % [a["scored"], a["lost"]])
	check(a["scored_value"] == a["scored"], "copper-only board: scored value equals scored count")
	check(a["cycles"] >= 9, "pusher completes at least 9 cycles in 25s (got %d)" % a["cycles"])
	check(a["bed_layout"] == b["bed_layout"], "same seed gives identical bed layout")
	check(b["scored"] >= 1, "same seed second run also drops coins (%d vs %d)" % [a["scored"], b["scored"]])
	check(a["positions"] != c["positions"] or a["scored"] != c["scored"] or a["lost"] != c["lost"], "different seed changes the outcome")
	check(a["clip_after"] == 0, "clip empty after firing 20")
	check(a["settled"], "machine reports settled after drops stop")
	check(a["max_y"] < 6.0, "no coin flies away or rests high (max y %.1f)" % a["max_y"])
	check(top["fired"] == 20, "top chute fires all 20 (got %d)" % top["fired"])
	check(top["scored"] + top["lost"] + top["on_board"] == bed + 20, "top chute coins all accounted for")
	check(top["scored"] >= 1, "top chute drops at least 1 (got %d)" % top["scored"])
	var through_floor: int = a["lost_on_platform"] + b["lost_on_platform"] + c["lost_on_platform"] + top["lost_on_platform"]
	check(through_floor == 0, "no coin is lost while still over the platform (fell through floor) (got %d)" % through_floor)
	check(a["bed_jump_y"] < 0.5, "bed coins stay down right after reset (max y %.2f)" % a["bed_jump_y"])
	var reset_jump: Dictionary = await simulate_double_reset(7)
	check(reset_jump["max_y"] < 0.5, "second reset does not launch bed coins into the air (max y %.2f)" % reset_jump["max_y"])
	check(reset_jump["max_speed"] < 2.0, "second reset leaves bed coins calm (max speed %.1f)" % reset_jump["max_speed"])
	print("MachineSim: sides seed7 scored=%d lost=%d | seed8 %d/%d | top %d/%d | idle %d/%d | cycles=%d" % [a["scored"], a["lost"], c["scored"], c["lost"], top["scored"], top["lost"], idle["scored"], idle["lost"], a["cycles"]])
	print("MachineSim: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func simulate(seed_value: int, fire_count: int, mode: String) -> Dictionary:
	var machine: Machine = Machine.new()
	machine.tuning = load("res://game/machine/machine_tuning.tres")
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	var bed_count: int = machine.coins_on_board()
	var bed_layout: Array[Vector3] = machine.bed_layout()
	var bed_jump_y: float = -99.0
	for _t in range(6):
		await physics_frame
		for coin in machine.board_coins():
			bed_jump_y = maxf(bed_jump_y, coin.position.y)
	var box: Dictionary = {"cycles": 0, "settled": false, "lost_on_platform": 0}
	machine.pusher_cycle.connect(func(_i: int) -> void: box["cycles"] += 1)
	machine.settled.connect(func() -> void: box["settled"] = true)
	# 流失時幣仍然喺平台範圍之內（唔係邊坑、唔係飛出）= 跌穿地板
	machine.coin_lost.connect(func(coin: Coin, _side: int) -> void:
		var p: Vector3 = coin.position
		if absf(p.x) < MachineLayout.GUTTER_HALF_WIDTH - 0.2 and p.z < MachineLayout.SCORE_MIN_Z and p.y < MachineLayout.FLY_AWAY_Y:
			box["lost_on_platform"] += 1
			print("THROUGH_FLOOR pos=%s vel=%s" % [str(p), str(coin.linear_velocity)]))
	var fired: int = 0
	var ticks: int = 0
	for i in range(fire_count):
		var chute: int = MachineLayout.Chute.TOP if mode == "top" else (i % 2)
		if mode == "top":
			machine.set_aim_x(-6.0 + 12.0 * float(i % 5) / 4.0)
		if machine.fire(chute):
			fired += 1
		for _t in range(FIRE_GAP_TICKS):
			await physics_frame
			ticks += 1
	while ticks < TOTAL_TICKS:
		await physics_frame
		ticks += 1
	var positions: Array = []
	var max_y: float = -99.0
	for coin in machine.board_coins():
		positions.append(Vector3i((coin.position * 10.0).round()))
		max_y = maxf(max_y, coin.position.y)
	positions.sort()
	var result: Dictionary = {
		"bed_count": bed_count,
		"bed_layout": bed_layout,
		"fired": fired,
		"scored": machine.scored_count,
		"lost": machine.lost_count,
		"scored_value": machine.scored_value,
		"on_board": machine.coins_on_board(),
		"positions": positions,
		"cycles": box["cycles"],
		"settled": box["settled"],
		"clip_after": machine.clip,
		"max_y": max_y,
		"lost_on_platform": box["lost_on_platform"],
		"bed_jump_y": bed_jump_y,
	}
	machine.queue_free()
	await physics_frame
	return result


## reset 兩次（demo 嘅 N 鍵）：舊床幣唔應該同新床幣重疊炸飛。
func simulate_double_reset(seed_value: int) -> Dictionary:
	var machine: Machine = Machine.new()
	machine.tuning = load("res://game/machine/machine_tuning.tres")
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	for _t in range(30):
		await physics_frame
	machine.reset(seed_value + 1)
	var max_y: float = -99.0
	var max_speed: float = 0.0
	for _t in range(6):
		await physics_frame
		for coin in machine.board_coins():
			max_y = maxf(max_y, coin.position.y)
			max_speed = maxf(max_speed, coin.linear_velocity.length())
	machine.queue_free()
	await physics_frame
	return {"max_y": max_y, "max_speed": max_speed}
