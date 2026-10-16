extends SceneTree
## 手感參數掃描（開發工具，唔係 pass/fail 測試）。
## 用法：godot --headless --fixed-fps 60 --path . --script res://tests/tuning_sweep.gd -- --qa --bed-spacing=15 --bed-start=90 --bed-end=270 --stroke=36 --ticks=1200 --seed=7
## 印一行 CSV：spacing,start,end,stroke,bed,scored,lost,on_board,cycles,settled

var _args: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.find("=") > 0:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	run()


func argf(key: String, default_value: float) -> float:
	return float(_args[key]) if _args.has(key) else default_value


func argi(key: String, default_value: int) -> int:
	return int(_args[key]) if _args.has(key) else default_value


func run() -> void:
	var tuning: MachineTuning = (load("res://game/machine/machine_tuning.tres") as MachineTuning).duplicate(true)
	tuning.bed_spacing = argf("bed-spacing", tuning.bed_spacing)
	tuning.bed_start_y = argf("bed-start", tuning.bed_start_y)
	tuning.bed_end_y = argf("bed-end", tuning.bed_end_y)
	tuning.pusher_stroke = argf("stroke", tuning.pusher_stroke)
	tuning.bed_jitter = argf("bed-jitter", tuning.bed_jitter)
	tuning.linear_damp = argf("damp", tuning.linear_damp)
	tuning.fire_forward_speed = argf("fire-forward", tuning.fire_forward_speed)
	tuning.fire_speed = argf("fire-speed", tuning.fire_speed)
	var ticks_total: int = argi("ticks", 1200)
	var seed_value: int = argi("seed", 7)
	var fire_count: int = argi("fire", 20)

	var machine: Machine = Machine.new()
	machine.tuning = tuning
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	var bed: int = machine.coins_on_board()
	var box: Dictionary = {"cycles": 0, "settled": false}
	machine.pusher_cycle.connect(func(_i: int) -> void: box["cycles"] += 1)
	machine.settled.connect(func() -> void: box["settled"] = true)
	var ticks: int = 0
	if fire_count > tuning.clip_size:
		machine.refill(fire_count - tuning.clip_size)
	for i in range(fire_count):
		machine.fire(i % 2)
		for _t in range(16):
			await physics_frame
			ticks += 1
	while ticks < ticks_total:
		await physics_frame
		ticks += 1
	var bands: Array[int] = [0, 0, 0, 0, 0, 0]   # y<83, 83-120, 120-160, 160-200, 200-240, >=240
	var max_y: float = 0.0
	var min_x: float = 999.0
	var max_x: float = 0.0
	for coin in machine.board_coins():
		var y: float = coin.position.y
		max_y = maxf(max_y, y)
		min_x = minf(min_x, coin.position.x)
		max_x = maxf(max_x, coin.position.x)
		var b: int = 0 if y < 83.0 else (1 if y < 120.0 else (2 if y < 160.0 else (3 if y < 200.0 else (4 if y < 240.0 else 5))))
		bands[b] += 1
	print("DIAG bands=%s max_y=%.1f x_range=%.0f..%.0f" % [str(bands), max_y, min_x, max_x])
	print("SWEEP,%.1f,%.0f,%.0f,%.0f,%d,%d,%d,%d,%d,%s" % [
		tuning.bed_spacing, tuning.bed_start_y, tuning.bed_end_y, tuning.pusher_stroke,
		bed, machine.scored_count, machine.lost_count, machine.coins_on_board(), box["cycles"], str(box["settled"])])
	quit(0)
