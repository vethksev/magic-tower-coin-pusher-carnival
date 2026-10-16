extends SceneTree
## Headless 物理模擬。建議加 --fixed-fps 60 跑（約 5 秒）；唔加就係真實時間（約 1 分鐘）。

var checks: int = 0
var failures: int = 0

const FIRE_GAP_TICKS: int = 16     # 0.25s 冷卻 = 15 ticks，用 16 保證冷卻已過
const TOTAL_TICKS: int = 1200      # 20 秒


func _initialize() -> void:
	run()


func run() -> void:
	var a: Dictionary = await simulate(7)
	var b: Dictionary = await simulate(7)
	var c: Dictionary = await simulate(8)
	var idle: Dictionary = await simulate(7, 0)
	var bed: int = a["bed_count"]
	check(bed >= 350 and bed <= 450, "hex bed has roughly 400 coins (got %d)" % bed)
	check(idle["scored"] == 0 and idle["lost"] == 0, "bed is stable with no firing (scored %d lost %d)" % [idle["scored"], idle["lost"]])
	check(a["fired"] == 20, "all 20 clip coins fired (got %d)" % a["fired"])
	check(a["scored"] + a["lost"] + a["on_board"] == bed + 20, "every coin is scored, lost or on board")
	check(a["scored"] >= 5, "firing 20 coins drops at least 5 within 20s (got %d)" % a["scored"])
	check(a["scored"] > a["lost"], "more coins score than are lost to gutters (%d vs %d)" % [a["scored"], a["lost"]])
	check(a["scored_value"] == a["scored"], "copper-only board: scored value equals scored count")
	check(a["cycles"] >= 7, "pusher completes at least 7 cycles in 20s (got %d)" % a["cycles"])
	check(a["bed_layout"] == b["bed_layout"], "same seed gives identical bed layout")
	# Godot 物理跨 run 唔保證逐位元一致（RID／島序），只要求同 seed 結果相近
	check(absi(a["scored"] - b["scored"]) <= 3 and absi(a["lost"] - b["lost"]) <= 3, "same seed gives near-identical scored/lost (%d/%d vs %d/%d)" % [a["scored"], a["lost"], b["scored"], b["lost"]])
	check(a["positions"] != c["positions"] or a["scored"] != c["scored"] or a["lost"] != c["lost"], "different seed changes the outcome")
	check(a["clip_after"] == 0, "clip empty after firing 20")
	check(a["settled"], "machine reports settled after drops stop")
	print("MachineSim: seed7 scored=%d lost=%d on_board=%d cycles=%d | seed8 scored=%d lost=%d" % [a["scored"], a["lost"], a["on_board"], a["cycles"], c["scored"], c["lost"]])
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
	var bed_layout: Array[Vector2] = machine.bed_layout()
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
	for coin in machine.board_coins():
		positions.append(Vector2i(coin.position.round()))
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
	}
	machine.queue_free()
	await physics_frame
	return result
