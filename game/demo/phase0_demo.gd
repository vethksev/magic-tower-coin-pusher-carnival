extends Node2D
## Phase 0 手感 demo 控制器：鍵盤發幣、HUD 統計、即場調參。
## 唔係正式遊戲流程；Phase 1 會換成 run 場景。

const TUNING_PATH: String = "res://game/machine/machine_tuning.tres"
const FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-zh-hant.otf"
const MACHINE_ORIGIN: Vector2 = Vector2(20, 30)

var machine: Machine
var hud: Label
var tuning: MachineTuning
var hud_visible: bool = true
var _status: String = "準備"


func _ready() -> void:
	_setup_input()
	var base: MachineTuning = load(TUNING_PATH)
	tuning = base.duplicate(true)      # 即場調參唔污染 .tres
	machine = Machine.new()
	machine.name = "Machine"
	machine.tuning = tuning
	machine.position = MACHINE_ORIGIN
	add_child(machine)
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
	add_child(hud)
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


func _setup_input() -> void:
	_bind("fire_left", KEY_A)
	_bind("fire_right", KEY_D)
	_bind("fire_both", KEY_SPACE)
	_bind("refill", KEY_R)
	_bind("new_seed", KEY_N)
	_bind("toggle_hud", KEY_F1)
	_bind("period_down", KEY_BRACKETLEFT)
	_bind("period_up", KEY_BRACKETRIGHT)
	_bind("damp_down", KEY_MINUS)
	_bind("damp_up", KEY_EQUAL)
	_bind("speed_down", KEY_COMMA)
	_bind("speed_up", KEY_PERIOD)
	_bind("stroke_down", KEY_SEMICOLON)
	_bind("stroke_up", KEY_APOSTROPHE)


func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("fire_both"):
		demo_fire(0)
		demo_fire(1)
	else:
		if Input.is_action_pressed("fire_left"):
			demo_fire(0)
		if Input.is_action_pressed("fire_right"):
			demo_fire(1)


func _unhandled_input(event: InputEvent) -> void:
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
	elif event.is_action("damp_down"):
		demo_adjust("damp", -1)
	elif event.is_action("damp_up"):
		demo_adjust("damp", 1)
	elif event.is_action("speed_down"):
		demo_adjust("speed", -1)
	elif event.is_action("speed_up"):
		demo_adjust("speed", 1)
	elif event.is_action("stroke_down"):
		demo_adjust("stroke", -1)
	elif event.is_action("stroke_up"):
		demo_adjust("stroke", 1)
	else:
		return
	_refresh()


## 畀測試同鍵盤共用。
func demo_fire(side: int) -> bool:
	return machine.fire(side)


## what: "period" | "damp" | "speed" | "stroke"；direction: +1 / -1
func demo_adjust(what: String, direction: int) -> void:
	var d: float = float(signi(direction))
	match what:
		"period":
			machine.set_pusher_period(clampf(tuning.pusher_period + 0.2 * d, 0.6, 6.0))
		"damp":
			tuning.linear_damp = clampf(tuning.linear_damp + 0.5 * d, 0.0, 12.0)
			machine.apply_tuning_to_coins()
		"speed":
			tuning.fire_speed = clampf(tuning.fire_speed + 20.0 * d, 40.0, 600.0)
		"stroke":
			tuning.pusher_stroke = clampf(tuning.pusher_stroke + 4.0 * d, 8.0, 100.0)
	_refresh()


func _refresh() -> void:
	if hud == null or machine == null:
		return
	var lines: PackedStringArray = PackedStringArray([
		"魔塔推幣機 · Phase 0 手感 demo",
		"",
		"彈匣 %d   跌落 %d   流失 %d" % [machine.clip, machine.scored_count, machine.lost_count],
		"枱上 %d   seed %d   狀態 %s" % [machine.coins_on_board(), machine.seed_value, _status],
		"",
		"推板週期 [ ]  %.1f 秒" % tuning.pusher_period,
		"推板行程 ; '  %.0f 像素" % tuning.pusher_stroke,
		"枱面摩擦 - =  %.1f" % tuning.linear_damp,
		"發幣滑速 , .  %.0f" % tuning.fire_speed,
		"",
		"A 左發   D 右發   Space 雙發",
		"R 補 20 幣   N 新 seed   F1 收起",
		"",
		"試完話我知邊組數字手感最好。",
	])
	hud.text = "\n".join(lines)
