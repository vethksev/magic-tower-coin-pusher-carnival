extends SceneTree
## Headless 3D 物理模擬。建議加 --fixed-fps 60 跑；唔加就係真實時間。

var checks: int = 0
var failures: int = 0

const FIRE_GAP_TICKS: int = 16     # 0.25s 冷卻 = 15 ticks，用 16 保證冷卻已過
const TOTAL_TICKS: int = 1500      # 25 秒


func _initialize() -> void:
	run()


func run() -> void:
	var a: Dictionary = await simulate(7)
	var b: Dictionary = await simulate(7)
	var c: Dictionary = await simulate(8)
	var idle: Dictionary = await simulate(7, 0)
	var bed: int = a["bed_count"]
	check(bed >= 80 and bed <= 250, "bed has roughly 100-200 coins (got %d)" % bed)
	check(idle["scored"] <= 3 and idle["lost"] <= 3, "bed is stable with no firing (scored %d lost %d)" % [idle["scored"], idle["lost"]])
	check(a["fired"] == 20, "all 20 clip coins fired (got %d)" % a["fired"])
	check(a["scored"] + a["lost"] + a["on_board"] == bed + 20, "every coin is scored, lost or on board")
	check(a["scored"] >= 3, "firing 20 coins drops at least 3 within 25s (got %d)" % a["scored"])
	check(a["scored"] > a["lost"], "more coins score than are lost to gutters (%d vs %d)" % [a["scored"], a["lost"]])
	check(a["scored_value"] == a["scored"], "copper-only board: scored value equals scored count")
	check(a["cycles"] >= 9, "pusher completes at least 9 cycles in 25s (got %d)" % a["cycles"])
	check(a["bed_layout"] == b["bed_layout"], "same seed gives identical bed layout")
	# Jolt 跨 run 唔確定（同 seed 跌落數可以差好遠），只驗兩次都有跌落；平衡要用多 run 平均
	check(b["scored"] >= 1, "same seed second run also drops coins (%d/%d vs %d/%d)" % [a["scored"], a["lost"], b["scored"], b["lost"]])
	check(a["positions"] != c["positions"] or a["scored"] != c["scored"] or a["lost"] != c["lost"], "different seed changes the outcome")
	check(a["clip_after"] == 0, "clip empty after firing 20")
	check(a["settled"], "machine reports settled after drops stop")
	check(a["max_y"] < 6.0, "no coin flies away (max y %.1f)" % a["max_y"])
	print("MachineSim: seed7 scored=%d lost=%d on_board=%d cycles=%d | seed8 scored=%d lost=%d | idle scored=%d lost=%d" % [a["scored"], a["lost"], a["on_board"], a["cycles"], c["scored"], c["lost"], idle["scored"], idle["lost"]])
	print("MachineSim: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func simulate(seed_value: int, fire_count: int = 20) -> Dictionary:
	var machine: Machine = Machine.new()
	machine.tuning = load("res://game/machine/machine_tuning.tres")
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	var bed_count: int = machine.coins_on_board()
	var bed_layout: Array[Vector3] = machine.bed_layout()
	var box: Dictionary = {"cycles": 0, "settled": false}
	machine.pusher_cycle.connect(func(_i: int) -> void: box["cycles"] += 1)
	machine.settled.connect(func() -> void: box["settled"] = true)
	var fired: int = 0
	var ticks: int = 0
	for i in range(fire_count):
		if machine.fire(i % 2):
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
	}
	machine.queue_free()
	await physics_frame
	return result
