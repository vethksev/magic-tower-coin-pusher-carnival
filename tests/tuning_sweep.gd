extends SceneTree
## 手感參數掃描（開發工具，唔係 pass/fail 測試）。3D 版。
## 用法：godot --headless --fixed-fps 60 --path . --script res://tests/tuning_sweep.gd -- --qa --bed-spacing=1.02 --stroke=4 --friction=0.35 --fire-speed=14 --fire=20 --ticks=1500 --seed=7
## 印一行 CSV：spacing,stroke,friction,fire_speed,bed,scored,lost,on_board,cycles,settled,max_y

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
	tuning.bed_z_gap = argf("bed-gap", tuning.bed_z_gap)
	tuning.bed_z_end = argf("bed-end", tuning.bed_z_end)
	tuning.pusher_stroke = argf("stroke", tuning.pusher_stroke)
	tuning.pusher_period = argf("period", tuning.pusher_period)
	tuning.friction = argf("friction", tuning.friction)
	tuning.coin_thickness = argf("thickness", tuning.coin_thickness)
	tuning.fire_speed = argf("fire-speed", tuning.fire_speed)
	var ticks_total: int = argi("ticks", 1500)
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
	var bands: Array[int] = [0, 0, 0, 0, 0]   # z<-4, -4..0, 0..3, 3..5, >=5
	var max_y: float = -99.0
	var max_z: float = -99.0
	var on_top: int = 0
	var stacked: int = 0
	for coin in machine.board_coins():
		var p: Vector3 = coin.position
		max_y = maxf(max_y, p.y)
		max_z = maxf(max_z, p.z)
		if p.y > 1.0:
			on_top += 1
		elif p.y > 0.25:
			stacked += 1
		var b: int = 0 if p.z < -4.0 else (1 if p.z < 0.0 else (2 if p.z < 3.0 else (3 if p.z < 5.0 else 4)))
		bands[b] += 1
	print("DIAG bands=%s max_y=%.2f max_z=%.2f on_pusher_top=%d stacked=%d" % [str(bands), max_y, max_z, on_top, stacked])
	print("SWEEP,%.2f,%.1f,%.2f,%.0f,%d,%d,%d,%d,%d,%s,%.1f" % [
		tuning.bed_spacing, tuning.pusher_stroke, tuning.friction, tuning.fire_speed,
		bed, machine.scored_count, machine.lost_count, machine.coins_on_board(), box["cycles"], str(box["settled"]), max_y])
	quit(0)
