class_name Machine
extends Node2D
## 推幣機台：牆、推板、床幣、發幣（橫滑直至被阻）、分區判定、靜止判定。
## 只發信號，唔識魔塔數值。上層（rules）聽信號。

signal coin_scored(coin: Coin)
signal coin_lost(coin: Coin, side: int)
signal pusher_cycle(index: int)
signal settled()
signal clip_changed(remaining: int)

const COPPER_COLOR: Color = Color(0.80, 0.50, 0.20)
const HEX_ROW_FACTOR: float = 0.8660254   # sqrt(3)/2

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
var _last_event_cycle: int = 0      # 最後一次有幣跌落／流失／發幣時嘅推板週期
var _settled_emitted: bool = false
var _pusher: Pusher
var _coins_root: Node2D
var _ready_done: bool = false


func _ready() -> void:
	if tuning == null:
		tuning = load("res://game/machine/machine_tuning.tres")
	_build_walls()
	_pusher = Pusher.new()
	_pusher.name = "Pusher"
	add_child(_pusher)
	_pusher.configure(tuning)
	_pusher.cycle_completed.connect(func(i: int) -> void: pusher_cycle.emit(i))
	_coins_root = Node2D.new()
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


## 床幣初始位置（純由 seed 同 tuning 決定，唔經物理），畀測試驗證 RNG 可重現。
func bed_layout() -> Array[Vector2]:
	var saved_state: int = rng.state
	rng.seed = seed_value
	var out: Array[Vector2] = []
	for p in _bed_positions():
		out.append(p)
	rng.state = saved_state
	return out


## side: 0 左槽、1 右槽。回傳 true 代表真係發咗一枚。
## 幣由槽口沿推板前條帶橫向滑行，撞到幣或對面牆先落地（RACCOIN 式）。
func fire(side: int) -> bool:
	if clip <= 0 or _cooldown[side] > 0.0:
		return false
	var dir_x: float = 1.0 if side == 0 else -1.0
	var r: float = tuning.coin_radius
	# 條帶 y：推板當刻前沿 + 半徑 + 2；最少喺槽口高度、最多唔超過床幣後排（避免一出就撞床）
	var y: float = _pusher.front_y() + r + 2.0 + rng.randf_range(-tuning.fire_jitter, tuning.fire_jitter)
	y = clampf(y, MachineLayout.CHUTE_LEFT.y, tuning.bed_start_y - 2.0 * r)
	var x: float = (r + 1.0) if side == 0 else (MachineLayout.WIDTH - r - 1.0)
	var coin: Coin = _make_coin(1, COPPER_COLOR)
	coin.land_scale = rng.randf_range(0.8, 1.2)
	coin.begin_slide(Vector2(x, y), dir_x, tuning.fire_speed)
	_coins_root.add_child(coin)
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
		coin.apply_damp(tuning.linear_damp)


func _make_coin(value: int, color: Color) -> Coin:
	var coin: Coin = Coin.new()
	coin.setup(tuning, value, _next_uid, color)
	_next_uid += 1
	return coin


## 六角密鋪：列以 x=200 對稱，奇數行偏移半格；行距 spacing × 0.866。
func _bed_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var s: float = tuning.bed_spacing
	var row_pitch: float = s * HEX_ROW_FACTOR
	var centre: float = MachineLayout.WIDTH / 2.0
	# 前台（有邊坑）行只鋪到 bed_x_start..bed_x_end；後台行鋪到牆邊，唔留橫向空隙吸收推力
	var front_half_span: float = minf(centre - tuning.bed_x_start, tuning.bed_x_end - centre)
	var back_half_span: float = centre - tuning.coin_radius - 1.0
	var y: float = tuning.bed_start_y
	var row: int = 0
	while y <= tuning.bed_end_y + 0.001:
		var half_span: float = back_half_span if y < MachineLayout.GUTTER_START_Y else front_half_span
		var offset: float = 0.0 if row % 2 == 0 else s / 2.0
		var k: int = 0
		while true:
			var dx: float = offset + k * s
			if dx > half_span:
				break
			var jitter_a: Vector2 = Vector2(rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter), rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter))
			out.append(Vector2(centre + dx, y) + jitter_a)
			if dx > 0.0001:
				var jitter_b: Vector2 = Vector2(rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter), rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter))
				out.append(Vector2(centre - dx, y) + jitter_b)
			k += 1
		y += row_pitch
		row += 1
	return out


func _spawn_bed() -> void:
	for p in _bed_positions():
		var coin: Coin = _make_coin(1, COPPER_COLOR)
		_coins_root.add_child(coin)
		coin.place(p)
		_coins.append(coin)


func _build_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 1
	add_child(walls)
	_add_box(walls, Rect2(-40.0, -40.0, 40.0, MachineLayout.HEIGHT + 80.0))            # 左牆（厚，防穿）
	_add_box(walls, Rect2(MachineLayout.WIDTH, -40.0, 40.0, MachineLayout.HEIGHT + 80.0))  # 右牆
	_add_box(walls, Rect2(0.0, -24.0, MachineLayout.WIDTH, 40.0))                      # 後牆（推板後面）


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	cs.position = rect.position + rect.size / 2.0
	body.add_child(cs)


## 滑行中嘅幣：下一位置會撞到任何已落地幣、或撞到對面牆，就喺現位落地。
func _is_blocked(pos: Vector2, self_coin: Coin) -> bool:
	var r: float = tuning.coin_radius
	if pos.x < r + 1.0 or pos.x > MachineLayout.WIDTH - r - 1.0:
		return true
	var min_dist: float = 2.0 * r + 0.5
	var min_dist_sq: float = min_dist * min_dist
	for other in _coins:
		if other == self_coin or other.is_airborne:
			continue
		if other.position.distance_squared_to(pos) < min_dist_sq:
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
			var next_pos: Vector2 = coin.slide_next(delta)
			# 滑行中貼住推板前沿，避免推板前進時將幣包入身體、落地被彈到推板後面
			next_pos.y = maxf(next_pos.y, _pusher.front_y() + tuning.coin_radius + 2.0)
			if _is_blocked(next_pos, coin):
				coin.land_at(coin.position, Vector2(coin.slide_dir * tuning.fire_speed * 0.2, tuning.fire_forward_speed) * coin.land_scale)
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
	# 靜止 = 彈匣空、無幣滑行中、而且連續 settle_cycles 個推板週期無任何幣跌落／流失
	if clip == 0 and not any_airborne and not _settled_emitted 			and _pusher.cycles_completed - _last_event_cycle >= tuning.settle_cycles:
		_settled_emitted = true
		settled.emit()


func _draw() -> void:
	var w: float = MachineLayout.WIDTH
	var h: float = MachineLayout.HEIGHT
	# 枱面：後台深、前台淺
	draw_rect(Rect2(0, 0, w, h), Color(0.16, 0.14, 0.20))
	draw_rect(Rect2(0, MachineLayout.FRONT_START_Y, w, MachineLayout.DROP_Y - MachineLayout.FRONT_START_Y), Color(0.22, 0.20, 0.26))
	# 邊坑（只喺最前段）
	var gutter_h: float = MachineLayout.DROP_Y - MachineLayout.GUTTER_START_Y
	draw_rect(Rect2(0, MachineLayout.GUTTER_START_Y, MachineLayout.GUTTER_W, gutter_h), Color(0.05, 0.04, 0.07))
	draw_rect(Rect2(w - MachineLayout.GUTTER_W, MachineLayout.GUTTER_START_Y, MachineLayout.GUTTER_W, gutter_h), Color(0.05, 0.04, 0.07))
	# 塔門（跌落帶）
	draw_rect(Rect2(0, MachineLayout.DROP_Y, w, h - MachineLayout.DROP_Y), Color(0.55, 0.42, 0.12))
	draw_line(Vector2(0, MachineLayout.DROP_Y), Vector2(w, MachineLayout.DROP_Y), Color(0.95, 0.80, 0.30), 1.0)
	# 槽口
	draw_rect(Rect2(MachineLayout.CHUTE_LEFT - Vector2(10, 8), Vector2(20, 16)), Color(0.50, 0.50, 0.58))
	draw_rect(Rect2(MachineLayout.CHUTE_RIGHT - Vector2(10, 8), Vector2(20, 16)), Color(0.50, 0.50, 0.58))
	# 外框
	draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(0.45, 0.30, 0.15), false, 2.0)
