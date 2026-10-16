extends Node3D
## Phase 0c 3D 手感 demo 控制器：三槽發幣（左／右／上）、滑鼠瞄準、2D HUD 疊層、即場調參。
## 唔係正式遊戲流程；Phase 1 會換成 run 場景。

const TUNING_PATH: String = "res://game/machine/machine_tuning.tres"
const FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-zh-hant.otf"

var machine: Machine
var hud: Label
var tuning: MachineTuning
var cam: Camera3D
var hud_visible: bool = true
var _status: String = "準備"


func _ready() -> void:
	_setup_input()
	var base: MachineTuning = load(TUNING_PATH)
	tuning = base.duplicate(true)      # 即場調參唔污染 .tres
	machine = Machine.new()
	machine.name = "Machine"
	machine.tuning = tuning
	add_child(machine)
	_build_camera_and_lights()
	_build_hud()
	machine.coin_scored.connect(func(_c: Coin) -> void: _refresh())
	machine.coin_lost.connect(func(_c: Coin, _s: int) -> void: _refresh())
	machine.clip_changed.connect(func(_n: int) -> void:
		_status = "發幣中" if machine.clip > 0 else "結算中"
		_refresh())
	machine.settled.connect(func() -> void:
		_status = "靜止"
		_refresh())
	machine.pusher_cycle.connect(func(_i: int) -> void: _refresh())
	_refresh()


func _build_camera_and_lights() -> void:
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0.0, 28.0, 23.0)
	cam.fov = 30.0
	cam.h_offset = 5.0      # 機台靠左，右邊留位畀 2D HUD
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.0, -1.0), Vector3.UP)
	cam.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	env_node.name = "Env"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.60)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	add_child(env_node)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)
	hud = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(440, 24)
	hud.size = Vector2(190, 320)
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font: Font = load(FONT_PATH)
	if font != null:
		hud.add_theme_font_override("font", font)
	hud.add_theme_font_size_override("font_size", 12)
	hud.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	layer.add_child(hud)


func _setup_input() -> void:
	_bind("fire_left", KEY_A)
	_bind("fire_right", KEY_D)
	_bind("fire_top", KEY_W)
	_bind("fire_both", KEY_SPACE)
	_bind("aim_left", KEY_LEFT)
	_bind("aim_right", KEY_RIGHT)
	_bind("refill", KEY_R)
	_bind("new_seed", KEY_N)
	_bind("toggle_hud", KEY_F1)
	_bind("period_down", KEY_BRACKETLEFT)
	_bind("period_up", KEY_BRACKETRIGHT)
	_bind("friction_down", KEY_MINUS)
	_bind("friction_up", KEY_EQUAL)
	_bind("speed_down", KEY_COMMA)
	_bind("speed_up", KEY_PERIOD)
	_bind("stroke_down", KEY_SEMICOLON)
	_bind("stroke_up", KEY_APOSTROPHE)
	_bind("bounce_down", KEY_9)
	_bind("bounce_up", KEY_0)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("fire_both"):
		demo_fire(MachineLayout.Chute.LEFT)
		demo_fire(MachineLayout.Chute.RIGHT)
	else:
		if Input.is_action_pressed("fire_left"):
			demo_fire(MachineLayout.Chute.LEFT)
		if Input.is_action_pressed("fire_right"):
			demo_fire(MachineLayout.Chute.RIGHT)
	if Input.is_action_pressed("fire_top"):
		demo_fire(MachineLayout.Chute.TOP)
	if Input.is_action_pressed("aim_left"):
		machine.set_aim_x(machine.aim_x - 8.0 * delta)
	if Input.is_action_pressed("aim_right"):
		machine.set_aim_x(machine.aim_x + 8.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_aim_from_mouse((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_aim_from_mouse(mb.position)
			demo_fire(MachineLayout.Chute.TOP)
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("refill"):
		machine.refill(tuning.clip_size)
		_status = "發幣中"
	elif event.is_action("new_seed"):
		machine.reset(machine.seed_value + 1)
		_status = "準備"
	elif event.is_action("toggle_hud"):
		hud_visible = not hud_visible
		hud.visible = hud_visible
	elif event.is_action("period_down"):
		demo_adjust("period", -1)
	elif event.is_action("period_up"):
		demo_adjust("period", 1)
	elif event.is_action("friction_down"):
		demo_adjust("friction", -1)
	elif event.is_action("friction_up"):
		demo_adjust("friction", 1)
	elif event.is_action("speed_down"):
		demo_adjust("speed", -1)
	elif event.is_action("speed_up"):
		demo_adjust("speed", 1)
	elif event.is_action("stroke_down"):
		demo_adjust("stroke", -1)
	elif event.is_action("stroke_up"):
		demo_adjust("stroke", 1)
	elif event.is_action("bounce_down"):
		demo_adjust("bounce", -1)
	elif event.is_action("bounce_up"):
		demo_adjust("bounce", 1)
	else:
		return
	_refresh()


## 滑鼠喺 3D 畫面上嘅位置 → 上方槽瞄準 x（以瞄準高度平面投影）。
func _aim_from_mouse(screen_pos: Vector2) -> void:
	if cam == null or machine == null:
		return
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane_y: float = MachineLayout.TOP_CHUTE_Y
	if absf(dir.y) < 0.0001:
		return
	var t: float = (plane_y - from.y) / dir.y
	if t <= 0.0:
		return
	var hit: Vector3 = from + dir * t
	machine.set_aim_x(hit.x)


## 畀測試同鍵盤共用。chute: 0 左、1 右、2 上
func demo_fire(chute: int) -> bool:
	return machine.fire(chute)


## what: "period" | "friction" | "speed" | "stroke" | "bounce"；direction: +1 / -1
func demo_adjust(what: String, direction: int) -> void:
	var d: float = float(signi(direction))
	match what:
		"period":
			machine.set_pusher_period(clampf(tuning.pusher_period + 0.2 * d, 0.6, 6.0))
		"friction":
			tuning.friction = clampf(tuning.friction + 0.05 * d, 0.0, 1.5)
			machine.apply_tuning_to_coins()
		"bounce":
			tuning.bounce = clampf(tuning.bounce + 0.05 * d, 0.0, 0.9)
			machine.apply_tuning_to_coins()
		"speed":
			tuning.fire_speed = clampf(tuning.fire_speed + 2.0 * d, 2.0, 60.0)
		"stroke":
			tuning.pusher_stroke = clampf(tuning.pusher_stroke + 0.5 * d, 1.0, 7.0)
	_refresh()


func _refresh() -> void:
	if hud == null or machine == null:
		return
	var lines: PackedStringArray = PackedStringArray([
		"魔塔推幣機 · 3D 手感 demo",
		"",
		"彈匣 %d   跌落 %d   流失 %d" % [machine.clip, machine.scored_count, machine.lost_count],
		"枱上 %d   seed %d   狀態 %s" % [machine.coins_on_board(), machine.seed_value, _status],
		"",
		"推板週期 [ ]  %.1f 秒" % tuning.pusher_period,
		"推板行程 ; '  %.1f 幣" % tuning.pusher_stroke,
		"摩擦 - =  %.2f  彈性 9 0  %.2f" % [tuning.friction, tuning.bounce],
		"側槽初速 , .  %.0f" % tuning.fire_speed,
		"",
		"A 左槽  D 右槽  Space 雙槽",
		"W／滑鼠左鍵 上方落幣",
		"滑鼠移動／←→ 瞄準（x %.1f）" % machine.aim_x,
		"R 補 20 幣  N 新 seed  F1 收起",
		"",
		"試完話我知邊組數字手感最好。",
	])
	hud.text = "\n".join(lines)
