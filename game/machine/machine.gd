class_name Machine
extends Node3D
## 3D 推幣機台：下層平台、側牆、固定刮板、推板、床幣、三個發幣槽（左／右／上，全部真物理）、分區判定、靜止判定。
## 只發信號，唔識魔塔數值。上層（rules）聽信號。

signal coin_scored(coin: Coin)
signal coin_lost(coin: Coin, side: int)
signal pusher_cycle(index: int)
signal settled()
signal clip_changed(remaining: int)

const COPPER_COLOR: Color = Color(0.85, 0.58, 0.22)
const HEX_ROW_FACTOR: float = 0.8660254

@export var tuning: MachineTuning

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 1
var clip: int = 0
var scored_count: int = 0
var lost_count: int = 0
var scored_value: int = 0
## 上方槽瞄準 x（由 demo／UI 設定）
var aim_x: float = 0.0

var _coins: Array[Coin] = []
var _next_uid: int = 1
var _cooldown: Array[float] = [0.0, 0.0, 0.0]
var _last_event_cycle: int = 0
var _settled_emitted: bool = false
var _pusher: Pusher
var _coins_root: Node3D
var _aim_marker: MeshInstance3D
var _ready_done: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = load("res://game/machine/machine_tuning.tres")
	_build_static()
	_build_chute_visuals()
	_pusher = Pusher.new()
	_pusher.name = "Pusher"
	_pusher.configure(tuning)   # 入 tree 前先放好位置，物理體一出世就喺後退位
	add_child(_pusher)
	_pusher.cycle_completed.connect(func(i: int) -> void: pusher_cycle.emit(i))
	_coins_root = Node3D.new()
	_coins_root.name = "Coins"
	add_child(_coins_root)
	_ready_done = true
	reset(seed_value)


func reset(new_seed: int) -> void:
	seed_value = new_seed
	rng.seed = new_seed
	# 舊幣要即時離開物理世界：queue_free 要等到 frame 尾，新舊床幣會重疊一個 physics step 然後炸飛
	for coin in _coins:
		if coin.get_parent() != null:
			coin.get_parent().remove_child(coin)
		coin.queue_free()
	_coins.clear()
	_next_uid = 1
	scored_count = 0
	lost_count = 0
	scored_value = 0
	_cooldown = [0.0, 0.0, 0.0]
	_last_event_cycle = 0
	_settled_emitted = false
	_pusher.configure(tuning)
	_spawn_bed()
	clip = tuning.clip_size
	clip_changed.emit(clip)


func refill(count: int) -> void:
	clip += count
	_settled_emitted = false
	_last_event_cycle = _pusher.cycles_completed
	clip_changed.emit(clip)


func coins_on_board() -> int:
	return _coins.size()


func board_coins() -> Array[Coin]:
	return _coins.duplicate()


func is_settled() -> bool:
	return _settled_emitted


func pusher_front_z() -> float:
	return _pusher.front_z()


func set_aim_x(x: float) -> void:
	aim_x = clampf(x, MachineLayout.TOP_AIM_MIN_X, MachineLayout.TOP_AIM_MAX_X)
	if _aim_marker != null:
		_aim_marker.position = MachineLayout.top_chute_origin(aim_x) + Vector3(0.0, 0.6, 0.0)


## 床幣初始位置（純由 seed 同 tuning 決定，唔經物理），畀測試驗證 RNG 可重現。
func bed_layout() -> Array[Vector3]:
	var saved_state: int = rng.state
	rng.seed = seed_value
	var out: Array[Vector3] = []
	for p in _bed_positions():
		out.append(p)
	rng.state = saved_state
	return out


## chute: MachineLayout.Chute.LEFT(0) / RIGHT(1) / TOP(2)。回傳 true 代表真係發咗一枚。
## 全部真物理：幣帶傾角同自轉由槽口飛出，落地彈開、滾動、撞散其他幣。
func fire(chute: int) -> bool:
	if clip <= 0 or chute < 0 or chute > 2 or _cooldown[chute] > 0.0:
		return false
	var origin: Vector3
	var vel: Vector3
	var speed_scale: float = 1.0 + rng.randf_range(-tuning.fire_speed_jitter, tuning.fire_speed_jitter)
	var yaw: float = deg_to_rad(rng.randf_range(-tuning.fire_yaw_jitter_deg, tuning.fire_yaw_jitter_deg))
	var basis_rot: Basis
	var spin: Vector3
	var tilt: float = deg_to_rad(rng.randf_range(tuning.fire_tilt_min_deg, tuning.fire_tilt_max_deg))
	if chute == MachineLayout.Chute.TOP:
		origin = MachineLayout.top_chute_origin(aim_x)
		vel = Vector3(0.0, -tuning.top_drop_speed, tuning.top_forward_speed) * speed_scale
		vel = vel.rotated(Vector3.UP, yaw)
		# 上方槽：幣以隨機傾角跌落，自轉令佔落地後碌開
		basis_rot = Basis(Vector3.RIGHT, tilt).rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		spin = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * tuning.fire_spin
	else:
		origin = MachineLayout.side_chute_origin(chute)
		vel = MachineLayout.side_chute_velocity(chute, tuning.fire_speed * speed_scale, tuning.fire_angle_deg)
		vel = vel.rotated(Vector3.UP, yaw)
		# 側槽：幣企直（軸沿 z）向內滾動；tilt 90 = 完全企直
		var dir_x: float = 1.0 if chute == MachineLayout.Chute.LEFT else -1.0
		basis_rot = Basis(Vector3.FORWARD, tilt * dir_x)
		# 滾動：沿 x 前進嘅幣繞 z 軸轉，ω = v / r
		var roll: float = -dir_x * vel.x * dir_x / tuning.coin_radius
		spin = Vector3(0.0, 0.0, roll) + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3), 0.0) * tuning.fire_spin
	var coin: Coin = _make_coin(1, COPPER_COLOR)
	_coins_root.add_child(coin)
	coin.launch(origin, basis_rot, vel, spin)
	_coins.append(coin)
	clip -= 1
	_cooldown[chute] = tuning.fire_cooldown
	_settled_emitted = false
	_last_event_cycle = _pusher.cycles_completed
	clip_changed.emit(clip)
	return true


func set_pusher_period(p: float) -> void:
	_pusher.set_period_keep_phase(maxf(p, 0.2))


func apply_tuning_to_coins() -> void:
	for coin in _coins:
		coin.apply_friction(tuning.friction)
		coin.apply_bounce(tuning.bounce)


func _make_coin(value: int, color: Color) -> Coin:
	var coin: Coin = Coin.new()
	coin.setup(tuning, value, _next_uid, color)
	_next_uid += 1
	return coin


## 六角密鋪一層喺下層平台：z 由推板最前位置 + gap 到 bed_z_end；邊坑段收窄；前段加第二層。
func _bed_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var s: float = tuning.bed_spacing
	var row_pitch: float = s * HEX_ROW_FACTOR
	var y: float = tuning.coin_thickness / 2.0 + 0.01
	var z: float = MachineLayout.PUSHER_REST_FRONT_Z + tuning.pusher_stroke + tuning.bed_z_gap
	var row: int = 0
	while z <= tuning.bed_z_end + 0.001:
		var half_span: float = tuning.bed_x_half
		if z > MachineLayout.GUTTER_START_Z:
			half_span = minf(half_span, MachineLayout.GUTTER_HALF_WIDTH - tuning.coin_radius - 0.1)
		var offset: float = 0.0 if row % 2 == 0 else s / 2.0
		var k: int = 0
		while true:
			var dx: float = offset + k * s
			if dx > half_span:
				break
			var ja: Vector3 = Vector3(rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter), 0.0, rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter))
			out.append(Vector3(dx, y, z) + ja)
			if dx > 0.0001:
				var jb: Vector3 = Vector3(rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter), 0.0, rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter))
				out.append(Vector3(-dx, y, z) + jb)
			# 前段第二層：疊喺兩枚之間（x 偏半格），高一層幣厚
			if z >= tuning.bed_layer2_from_z and dx + s / 2.0 <= half_span:
				var y2: float = y + tuning.coin_thickness + 0.02
				out.append(Vector3(dx + s / 2.0, y2, z))
				if dx > 0.0001:
					out.append(Vector3(-(dx + s / 2.0), y2, z))
			k += 1
		z += row_pitch
		row += 1
	return out


func _spawn_bed() -> void:
	for p in _bed_positions():
		var coin: Coin = _make_coin(1, COPPER_COLOR)
		_coins_root.add_child(coin)
		coin.place(p)
		_coins.append(coin)


func _build_static() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Static"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	var hw: float = MachineLayout.HALF_WIDTH
	var back: float = MachineLayout.PLATFORM_BACK_Z
	var front: float = MachineLayout.FRONT_EDGE_Z
	var gz: float = MachineLayout.GUTTER_START_Z
	var ghw: float = MachineLayout.GUTTER_HALF_WIDTH
	var wh: float = MachineLayout.WALL_HEIGHT
	var floor_col: Color = Color(0.20, 0.19, 0.26)
	var wall_col: Color = Color(0.42, 0.28, 0.16)
	var wiper_col: Color = Color(0.16, 0.14, 0.20)
	# 下層平台：後段全闊，前段（邊坑段）收窄
	_add_box(body, Vector3(0.0, -0.5, (back + gz) / 2.0), Vector3(hw * 2.0, 1.0, gz - back), floor_col)
	_add_box(body, Vector3(0.0, -0.5, (gz + front) / 2.0), Vector3(ghw * 2.0, 1.0, front - gz), floor_col)
	# 側牆（全長）
	_add_box(body, Vector3(-hw - 0.5, wh / 2.0, (back + front) / 2.0), Vector3(1.0, wh, front - back), wall_col)
	_add_box(body, Vector3(hw + 0.5, wh / 2.0, (back + front) / 2.0), Vector3(1.0, wh, front - back), wall_col)
	# 後牆
	_add_box(body, Vector3(0.0, wh / 2.0, back - 0.5), Vector3(hw * 2.0 + 2.0, wh, 1.0), wall_col)
	# 固定刮板：推板頂面之上，由後牆到 WIPER_FRONT_Z
	var wz: float = MachineLayout.WIPER_FRONT_Z
	var wiper_h: float = wh - MachineLayout.PUSHER_HEIGHT - 0.05
	_add_box(body, Vector3(0.0, MachineLayout.PUSHER_HEIGHT + 0.05 + wiper_h / 2.0, (back + wz) / 2.0), Vector3(hw * 2.0, wiper_h, wz - back), wiper_col)
	# 塔門視覺（前緣下面一塊金色板，無碰撞）
	var tray: MeshInstance3D = MeshInstance3D.new()
	var tray_mesh: BoxMesh = BoxMesh.new()
	tray_mesh.size = Vector3(hw * 2.0 + 2.0, 0.4, 3.0)
	tray.mesh = tray_mesh
	tray.position = Vector3(0.0, -2.6, front + 1.6)
	var tray_mat: StandardMaterial3D = StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.72, 0.55, 0.16)
	tray.material_override = tray_mat
	add_child(tray)


## 槽口視覺（無碰撞）：左右兩條斜槽、上方一個可移動瞄準標記。
func _build_chute_visuals() -> void:
	var chute_col: Color = Color(0.55, 0.55, 0.62)
	for side in [MachineLayout.Chute.LEFT, MachineLayout.Chute.RIGHT]:
		var o: Vector3 = MachineLayout.side_chute_origin(side)
		var dir_x: float = 1.0 if side == MachineLayout.Chute.LEFT else -1.0
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(2.2, 0.25, 1.4)
		mi.mesh = box
		mi.position = o + Vector3(-dir_x * 0.9, 0.15, 0.0)
		mi.rotation = Vector3(0.0, 0.0, -dir_x * deg_to_rad(20.0))
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = chute_col
		mi.material_override = mat
		add_child(mi)
	_aim_marker = MeshInstance3D.new()
	_aim_marker.name = "AimMarker"
	var am: BoxMesh = BoxMesh.new()
	am.size = Vector3(1.4, 0.3, 1.4)
	_aim_marker.mesh = am
	var amat: StandardMaterial3D = StandardMaterial3D.new()
	amat.albedo_color = Color(0.95, 0.85, 0.35)
	_aim_marker.material_override = amat
	add_child(_aim_marker)
	set_aim_x(aim_x)


func _add_box(body: StaticBody3D, centre: Vector3, size: Vector3, color: Color) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.position = centre
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = centre
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	body.add_child(mi)


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	for c in range(3):
		_cooldown[c] = maxf(0.0, _cooldown[c] - delta)
	_pusher.step(delta)
	var any_airborne: bool = false
	var i: int = _coins.size() - 1
	while i >= 0:
		var coin: Coin = _coins[i]
		coin.tick_airborne(delta)
		if coin.is_airborne:
			any_airborne = true
		var zone: MachineLayout.Zone = MachineLayout.classify(coin.position)
		if zone == MachineLayout.Zone.SCORED:
			_coins.remove_at(i)
			scored_count += 1
			scored_value += coin.value
			_last_event_cycle = _pusher.cycles_completed
			coin_scored.emit(coin)
			coin.queue_free()
		elif zone == MachineLayout.Zone.LOST_LEFT or zone == MachineLayout.Zone.LOST_RIGHT:
			_coins.remove_at(i)
			lost_count += 1
			_last_event_cycle = _pusher.cycles_completed
			coin_lost.emit(coin, 0 if zone == MachineLayout.Zone.LOST_LEFT else 1)
			coin.queue_free()
		i -= 1
	if clip == 0 and not any_airborne and not _settled_emitted \
			and _pusher.cycles_completed - _last_event_cycle >= tuning.settle_cycles:
		_settled_emitted = true
		settled.emit()
