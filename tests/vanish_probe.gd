extends SceneTree
## 診斷工具：追蹤每枚幣，逐 tick 記位置／速度，報告「喺平台範圍內消失」嘅幣同異常（穿地／入推板／超速）。
## 用法：godot --headless --fixed-fps 60 --path . --script res://tests/vanish_probe.gd -- --qa --seed=7 --mode=sides --fire=40 --ticks=2400

var _args: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.find("=") > 0:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	run()


func argi(key: String, default_value: int) -> int:
	return int(_args[key]) if _args.has(key) else default_value


func run() -> void:
	var mode: String = String(_args.get("mode", "sides"))
	var seed_value: int = argi("seed", 7)
	var fire_count: int = argi("fire", 40)
	var ticks_total: int = argi("ticks", 2400)
	var machine: Machine = Machine.new()
	machine.tuning = load("res://game/machine/machine_tuning.tres")
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	# 等床幣安定（reset 會同舊幣重疊一 frame，先放 120 tick 唔記錄）
	for _w in range(120):
		await physics_frame
	if fire_count > machine.tuning.clip_size:
		machine.refill(fire_count - machine.tuning.clip_size)
	var last: Dictionary = {}   # uid -> {pos, vel, tick}
	var anomalies: int = 0
	var vanished_mid: int = 0
	var ticks: int = 0
	var anom_printed: int = 0
	var next_fire_tick: int = 0
	var fired: int = 0
	while ticks < ticks_total:
		await physics_frame
		# 記錄現時所有幣
		var seen: Dictionary = {}
		for coin in machine.board_coins():
			var p: Vector3 = coin.position
			var v: Vector3 = coin.linear_velocity
			seen[coin.uid] = true
			last[coin.uid] = {"pos": p, "vel": v, "tick": ticks}
			var on_platform_xz: bool = absf(p.x) < 9.3 and p.z > -12.0 and p.z < 6.0
			var pz: float = machine.pusher_front_z()
			if on_platform_xz and p.y < -0.15:
				anomalies += 1
				anom_printed += 1
				if anom_printed <= 30: print("ANOM t=%d uid=%d FLOOR_PENETRATION pos=%s vel=%s pusher_z=%.2f" % [ticks, coin.uid, str(p), str(v), pz])
			elif absf(p.x) < 9.8 and p.y > 0.1 and p.y < 1.1 and p.z < pz - 0.6 and p.z > pz - 7.4:
				anomalies += 1
				anom_printed += 1
				if anom_printed <= 30: print("ANOM t=%d uid=%d INSIDE_PUSHER pos=%s vel=%s pusher_z=%.2f" % [ticks, coin.uid, str(p), str(v), pz])
			elif v.length() > 60.0:
				anomalies += 1
				anom_printed += 1
				if anom_printed <= 30: print("ANOM t=%d uid=%d FAST speed=%.1f pos=%s vel=%s pusher_z=%.2f" % [ticks, coin.uid, v.length(), str(p), str(v), pz])
		# 搵消失咗嘅
		for uid in last.keys():
			if not seen.has(uid):
				var rec: Dictionary = last[uid]
				var p: Vector3 = rec["pos"]
				var v: Vector3 = rec["vel"]
				var zone: int = MachineLayout.classify(p)
				var legit_front: bool = p.z >= 5.0 and p.y < -1.0
				var legit_gutter: bool = absf(p.x) > 9.2 and p.z > 4.5 and p.y < -1.0
				if not (legit_front or legit_gutter):
					vanished_mid += 1
					print("VANISH t=%d uid=%d zone=%d lastpos=%s lastvel=%s speed=%.1f pusher_z=%.2f" % [ticks, uid, zone, str(p), str(v), v.length(), machine.pusher_front_z()])
				last.erase(uid)
		# 發幣
		if fired < fire_count and ticks >= next_fire_tick:
			var chute: int = MachineLayout.Chute.TOP if mode == "top" else (fired % 2)
			if mode == "top":
				machine.set_aim_x(-6.0 + 12.0 * float(fired % 5) / 4.0)
			if machine.fire(chute):
				fired += 1
				next_fire_tick = ticks + 16
		ticks += 1
	print("PROBE seed=%d mode=%s fired=%d scored=%d lost=%d on_board=%d vanished_mid=%d anomalies=%d" % [seed_value, mode, fired, machine.scored_count, machine.lost_count, machine.coins_on_board(), vanished_mid, anomalies])
	quit(0)
