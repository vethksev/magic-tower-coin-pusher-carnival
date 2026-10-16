class_name Machine
extends Node3D
## 3D 推幣機台：下層平台、側牆、固定刮板、推板、床幣、發幣（橫滑直至被阻）、分區判定、靜止判定。
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

var _coins: Array[Coin] = []
var _next_uid: int = 1
var _cooldown: Array[float] = [0.0, 0.0]
var _last_event_cycle: int = 0
var _settled_emitted: bool = false
var _pusher: Pusher
var _coins_root: Node3D
var _ready_done: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = load("res://game/machine/machine_tuning.tres")
	_build_static()
	_pusher = Pusher.new()
	_pusher.name = "Pusher"
	add_child(_pusher)
	_pusher.configure(tuning)
	_pusher.cycle_completed.connect(func(i: int) -> void: pusher_cycle.emit(i))
	_coins_root = Node3D.new()
	_coins_root.name = "Coins"
	add_child(_coins_root)
	_ready_done = true
	reset(seed_value)


func reset(new_seed: int) -> void:
	seed_value = new_seed
	rng.seed = new_seed
	for coin in _coins:
		coin.queue_free()
	_coins.clear()
	_next_uid = 1
	scored_count = 0
	lost_count = 0
	scored_value = 0
	_cooldown = [0.0, 0.0]
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


## 床幣初始位置（純由 seed 同 tuning 決定，唔經物理），畀測試驗證 RNG 可重現。
func bed_layout() -> Array[Vector3]:
	var saved_state: int = rng.state
	rng.seed = seed_value
	var out: Array[Vector3] = []
	for p in _bed_positions():
		out.append(p)
	rng.state = saved_state
	return out


## side: 0 左槽、1 右槽。回傳 true 代表真係發咗一枚。
## 幣由推板頂面嘅左／右邊緣橫向滑行，撞到幣或對面牆先落地。
func fire(side: int) -> bool:
	if clip <= 0 or _cooldown[side] > 0.0:
		return false
	var dir_x: float = 1.0 if side == 0 else -1.0
	var r: float = tuning.coin_radius
	var x: float = -(MachineLayout.HALF_WIDTH - r - 0.1) if side == 0 else (MachineLayout.HALF_WIDTH - r - 0.1)
	var y: float = _pusher.top_y() + tuning.coin_thickness / 2.0 + 0.02
	var z: float = MachineLayout.CHUTE_Z + rng.randf_range(-tuning.fire_jitter, tuning.fire_jitter)
	var coin: Coin = _make_coin(1, COPPER_COLOR)
	coin.land_scale = rng.randf_range(0.8, 1.2)
	_coins_root.add_child(coin)
	coin.begin_slide(Vector3(x, y, z), dir_x, tuning.fire_speed)
	_coins.append(coin)
	clip -= 1
	_cooldown[side] = tuning.fire_cooldown
	_settled_emitted = false
	_last_event_cycle = _pusher.cycles_completed
	clip_changed.emit(clip)
	return true


func set_pusher_period(p: float) -> void:
	_pusher.set_period_keep_phase(maxf(p, 0.2))


func apply_tuning_to_coins() -> void:
	for coin in _coins:
		coin.apply_friction(tuning.friction)


func _make_coin(value: int, color: Color) -> Coin:
	var coin: Coin = Coin.new()
	coin.setup(tuning, value, _next_uid, color)
	_next_uid += 1
	return coin


## 六角密鋪一層喺下層平台：z 由推板最前位置 + gap 到 bed_z_end；邊坑段（z > GUTTER_START_Z）收窄。
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
	var floor_col: Color = Color(0.20, 0.19, 0.26)
	var wall_col: Color = Color(0.42, 0.28, 0.16)
	var wiper_col: Color = Color(0.16, 0.14, 0.20)
	# 下層平台：後段全闊，前段（邊坑段）收窄
	_add_box(body, Vector3(0.0, -0.5, (back + gz) / 2.0), Vector3(hw * 2.0, 1.0, gz - back), floor_col)
	_add_box(body, Vector3(0.0, -0.5, (gz + front) / 2.0), Vector3(ghw * 2.0, 1.0, front - gz), floor_col)
	# 側牆（全長，高 4）
	_add_box(body, Vector3(-hw - 0.5, 2.0, (back + front) / 2.0), Vector3(1.0, 5.0, front - back), wall_col)
	_add_box(body, Vector3(hw + 0.5, 2.0, (back + front) / 2.0), Vector3(1.0, 5.0, front - back), wall_col)
	# 後牆
	_add_box(body, Vector3(0.0, 2.0, back - 0.5), Vector3(hw * 2.0 + 2.0, 5.0, 1.0), wall_col)
	# 固定刮板：推板頂面之上，由後牆到 WIPER_FRONT_Z
	var wz: float = MachineLayout.WIPER_FRONT_Z
	_add_box(body, Vector3(0.0, MachineLayout.PUSHER_HEIGHT + 1.45, (back + wz) / 2.0), Vector3(hw * 2.0, 2.8, wz - back), wiper_col)
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


## 滑行中嘅幣：下一位置會撞到同一高度嘅已落地幣、或撞到對面牆，就喺現位落地。
func _is_blocked(pos: Vector3, self_coin: Coin) -> bool:
	var r: float = tuning.coin_radius
	if absf(pos.x) > MachineLayout.HALF_WIDTH - r - 0.1:
		return true
	var min_dist: float = 2.0 * r + 0.05
	var min_dist_sq: float = min_dist * min_dist
	for other in _coins:
		if other == self_coin or other.is_airborne:
			continue
		var op: Vector3 = other.position
		if absf(op.y - pos.y) > 0.6:
			continue
		var dx: float = op.x - pos.x
		var dz: float = op.z - pos.z
		if dx * dx + dz * dz < min_dist_sq:
			return true
	return false


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	_cooldown[0] = maxf(0.0, _cooldown[0] - delta)
	_cooldown[1] = maxf(0.0, _cooldown[1] - delta)
	_pusher.step(delta)
	var any_airborne: bool = false
	var i: int = _coins.size() - 1
	while i >= 0:
		var coin: Coin = _coins[i]
		if coin.is_airborne:
			any_airborne = true
			var next_pos: Vector3 = coin.slide_next(delta)
			if _is_blocked(next_pos, coin):
				coin.land_at(coin.position, Vector3(coin.slide_dir * tuning.fire_speed * 0.15, 0.0, tuning.fire_forward_speed) * coin.land_scale)
			else:
				coin.position = next_pos
			i -= 1
			continue
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
