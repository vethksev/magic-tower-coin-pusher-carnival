# Phase 0 機台手感 Demo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出一個可玩嘅 Windows EXE：推幣機台（推板、左右發幣槽、床幣、塔門計分、邊坑流失），佔位圖，有即場調手感嘅 debug 鍵，畀 owner 試推板速度／摩擦／發幣初速。

**Architecture:** 純 2D Godot 物理（RigidBody2D 幣 + AnimatableBody2D 推板），所有幾何同手感參數集中喺 `MachineLayout`（常數＋純函數）同 `MachineTuning`（Resource）。`Machine` 場景只負責物理同發信號（`coin_scored`／`coin_lost`／`pusher_cycle`／`settled`），唔識任何魔塔數值。Phase 0 主場景係一個 demo 控制器，接鍵盤、顯示統計同 tuning 值。

**Tech Stack:** Godot 4.7.1 standard（GDScript，gl_compatibility），Git LFS，PowerShell 打包腳本。

## Global Constraints

- 引擎：Godot 4.7.1 standard，GDScript，Compatibility／OpenGL renderer，唔用 Mono。Exe：`D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe`
- 解像度：橫向 640×360 邏輯像素，viewport stretch、整數倍放大、nearest filtering
- 機台區 400×300 邏輯像素，置中偏左；右邊 240 像素側欄
- 推板：週期 2.4 秒、行程 36 像素、正弦；每完成一週期發 `pusher_cycle`
- 幣：RigidBody2D 圓形；銅幣直徑 14；linear damp 3.0、摩擦 0.6、彈性 0.1
- 發幣：A／D／Space，長按連發，冷卻 0.25 秒，初速 180 像素／秒；飛行 0.3 秒後落地先開碰撞
- 床幣：y 90–270 每 17 像素一行、x 30–370 每 17 像素一列，±1 像素 seed 抖動
- 靜止判定：所有幣速度 < 4 像素／秒持續 2 秒
- 固定 60Hz physics；每場 seed 可重現
- 所有測試 `extends SceneTree`，用 `check(cond, msg)` 計 checks／failures，exit code 0＝全過；命令一律加 `-- --qa`
- 程式只入 `game/`、`tests/`、`tools/`、`project.godot`、`main.*`；`assets/` 係 Codex 範圍（字體例外，Phase 0 借用 OFL 字體）
- 分支 `feat/phase0-machine`，每個 task 一個 commit，commit message 結尾加 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`
- 每次 git 前 `git branch --show-current`

## 共用指令

```powershell
$Godot = 'D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe'
$Root  = 'D:/magic-tower-coin-pusher-carnival'
& $Godot --headless --path $Root --editor --import            # 新增／改 class_name 或素材後必跑一次
& $Godot --headless --path $Root --script res://tests/<name>.gd -- --qa
```

Git Bash 等價：`"/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe" --headless --path /d/magic-tower-coin-pusher-carnival --script res://tests/<name>.gd -- --qa`

## 檔案結構

| 檔 | 責任 |
|---|---|
| `project.godot` | 640×360、stretch、nearest、gravity 0、gl_compatibility |
| `main.tscn` | 主場景，掛 `game/demo/phase0_demo.gd` |
| `game/machine/machine_layout.gd` | `MachineLayout`：幾何常數、`pusher_front_y()`、`classify()`、`cycle_index()`（純函數） |
| `game/machine/machine_tuning.gd` + `.tres` | `MachineTuning` Resource：所有手感參數 |
| `game/machine/coin.gd` | `Coin`：RigidBody2D，飛行→落地，佔位 `_draw` |
| `game/machine/pusher.gd` | `Pusher`：AnimatableBody2D 正弦推板，`cycle_completed` 信號 |
| `game/machine/machine.gd` | `Machine`：牆、推板、床幣、發幣、分區判定、信號、靜止判定 |
| `game/demo/phase0_demo.gd` | Phase 0 控制器：鍵盤、HUD、即場調參 |
| `assets/fonts/fusion-pixel-12px-zh-hant.otf` + `OFL.txt` | 繁中像素字體（由 red-panda-forge 借用，OFL） |
| `tests/machine_layout_tests.gd` | 純函數測試 |
| `tests/machine_sim_tests.gd` | headless 物理模擬：數目守恆、同 seed 一致、不同 seed 不同 |
| `tests/smoke.gd` | headless 開主場景、發幣、檢查統計 |
| `tests/demo_capture.gd` | 真 renderer 截圖到 `.godot/qa/phase0.png` |
| `export_presets.cfg` + `tools/build.ps1` + `tools/install_export_templates.ps1` | 打包 |

---

### Task 1: 專案骨架 + 字體 + 測試慣例

**Files:**
- Create: `project.godot`, `main.tscn`, `game/demo/phase0_demo.gd`（暫時只印一句）, `assets/fonts/fusion-pixel-12px-zh-hant.otf`, `assets/fonts/OFL.txt`, `tests/_harness_example.gd`

**Interfaces:**
- Produces: 測試慣例（`extends SceneTree`、`check()`、`quit(0/1)`），之後所有測試照抄。

- [ ] **Step 1: 開分支**

```bash
cd /d/magic-tower-coin-pusher-carnival && git branch --show-current && git switch -c feat/phase0-machine
```

- [ ] **Step 2: 寫 `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="魔塔推幣機 · Phase 0 手感 demo"
config/version="0.1.0"
run/main_scene="res://main.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="MagicTowerCoinPusher"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/size/resizable=true
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[physics]

2d/default_gravity=0.0
2d/default_linear_damp=0.0
2d/default_angular_damp=0.0
common/physics_ticks_per_second=60

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
environment/defaults/default_clear_color=Color(0.07, 0.06, 0.09, 1)

[audio]

driver/enable_input=false

[internationalization]

locale/fallback="zh_TW"
```

- [ ] **Step 3: 寫 `main.tscn` 同暫時嘅 `game/demo/phase0_demo.gd`**

`main.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/demo/phase0_demo.gd" id="1_demo"]

[node name="Main" type="Node2D"]
script = ExtResource("1_demo")
```

`game/demo/phase0_demo.gd`（暫時）：

```gdscript
extends Node2D


func _ready() -> void:
	print("phase0 demo boot")
```

- [ ] **Step 4: 借字體**

```bash
mkdir -p /d/magic-tower-coin-pusher-carnival/assets/fonts
cp /d/red-panda-forge/assets/fonts/fusion-pixel-12px-zh-hant.otf /d/red-panda-forge/assets/fonts/fusion-pixel-12px-zh-hant.otf.import /d/red-panda-forge/assets/fonts/OFL.txt /d/magic-tower-coin-pusher-carnival/assets/fonts/
```

（`.import` 一齊抄，保留 antialiasing=1／hinting／subpixel 嘅像素設定；Godot 會自己換 uid。）

- [ ] **Step 5: 寫測試慣例範例 `tests/_harness_example.gd`**

```gdscript
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	check(1 + 1 == 2, "harness sanity")
	print("Harness: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
```

- [ ] **Step 6: 匯入 + 跑範例**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --editor --import; echo "import exit $?"
"$G" --headless --path $R --script res://tests/_harness_example.gd -- --qa; echo "test exit $?"
```

Expected：import exit 0；輸出 `Harness: 1 checks, 0 failures`，test exit 0。

- [ ] **Step 7: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git add -A && git commit -m "$(printf 'Phase 0: project skeleton, pixel font, test harness convention\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 2: `MachineLayout` 純函數 + `MachineTuning` Resource（TDD）

**Files:**
- Create: `game/machine/machine_layout.gd`, `game/machine/machine_tuning.gd`, `game/machine/machine_tuning.tres`
- Test: `tests/machine_layout_tests.gd`

**Interfaces:**
- Produces:
  - `MachineLayout` 常數：`WIDTH=400.0`, `HEIGHT=300.0`, `BEZEL_Y=40.0`, `FRONT_START_Y=150.0`, `DROP_Y=280.0`, `GUTTER_W=18.0`, `CHUTE_LEFT=Vector2(30,48)`, `CHUTE_RIGHT=Vector2(370,48)`
  - `enum Zone { BOARD, SCORED, LOST_LEFT, LOST_RIGHT }`
  - `static func pusher_front_y(time: float, period: float, stroke: float, rest_y: float) -> float`
  - `static func classify(pos: Vector2) -> Zone`
  - `static func cycle_index(time: float, period: float) -> int`
  - `MachineTuning` 欄位：`pusher_period, pusher_stroke, pusher_thickness, pusher_rest_y, linear_damp, friction, bounce, fire_speed, fire_forward_speed, fire_jitter_deg, fire_cooldown, fire_flight_time, settle_speed, settle_seconds, clip_size, coin_radius, bed_start_y, bed_end_y, bed_spacing, bed_x_start, bed_x_end, bed_jitter`

- [ ] **Step 1: 寫失敗測試 `tests/machine_layout_tests.gd`**

```gdscript
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	test_pusher_motion()
	test_classify()
	test_cycle_index()
	test_tuning_defaults()
	print("MachineLayout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func test_pusher_motion() -> void:
	check(is_equal_approx(MachineLayout.pusher_front_y(0.0, 2.4, 36.0, 40.0), 40.0), "pusher rests at t=0")
	check(is_equal_approx(MachineLayout.pusher_front_y(1.2, 2.4, 36.0, 40.0), 76.0), "pusher fully extended at half period")
	check(is_equal_approx(MachineLayout.pusher_front_y(2.4, 2.4, 36.0, 40.0), 40.0), "pusher back to rest after one period")
	var quarter: float = MachineLayout.pusher_front_y(0.6, 2.4, 36.0, 40.0)
	check(quarter > 40.0 and quarter < 76.0, "quarter period is between rest and extended")
	check(is_equal_approx(MachineLayout.pusher_front_y(5.0, 0.0, 36.0, 40.0), 40.0), "zero period stays at rest")


func test_classify() -> void:
	check(MachineLayout.classify(Vector2(200, 100)) == MachineLayout.Zone.BOARD, "back shelf centre is board")
	check(MachineLayout.classify(Vector2(5, 100)) == MachineLayout.Zone.BOARD, "back shelf has no gutter")
	check(MachineLayout.classify(Vector2(5, 200)) == MachineLayout.Zone.LOST_LEFT, "front platform left gutter loses")
	check(MachineLayout.classify(Vector2(395, 200)) == MachineLayout.Zone.LOST_RIGHT, "front platform right gutter loses")
	check(MachineLayout.classify(Vector2(18, 200)) == MachineLayout.Zone.BOARD, "gutter edge x=18 is still board")
	check(MachineLayout.classify(Vector2(200, 279.9)) == MachineLayout.Zone.BOARD, "just before drop line is board")
	check(MachineLayout.classify(Vector2(200, 280.0)) == MachineLayout.Zone.SCORED, "drop line scores")
	check(MachineLayout.classify(Vector2(5, 290)) == MachineLayout.Zone.SCORED, "drop line wins over gutter")


func test_cycle_index() -> void:
	check(MachineLayout.cycle_index(0.0, 2.4) == 0, "cycle 0 at start")
	check(MachineLayout.cycle_index(2.39, 2.4) == 0, "still cycle 0 just before period")
	check(MachineLayout.cycle_index(2.4, 2.4) == 1, "cycle 1 at exactly one period")
	check(MachineLayout.cycle_index(7.3, 2.4) == 3, "cycle 3 at 7.3s")


func test_tuning_defaults() -> void:
	var t: MachineTuning = load("res://game/machine/machine_tuning.tres")
	check(t != null, "tuning resource loads")
	check(is_equal_approx(t.pusher_period, 2.4), "default period 2.4")
	check(is_equal_approx(t.pusher_stroke, 36.0), "default stroke 36")
	check(is_equal_approx(t.linear_damp, 3.0), "default damp 3.0")
	check(is_equal_approx(t.fire_speed, 180.0), "default fire speed 180")
	check(is_equal_approx(t.fire_cooldown, 0.25), "default cooldown 0.25")
	check(t.clip_size == 20, "default clip 20")
	check(is_equal_approx(t.coin_radius, 7.0), "copper radius 7")
	check(is_equal_approx(t.bed_spacing, 17.0), "bed spacing 17")
```

- [ ] **Step 2: 跑，確認失敗**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --script res://tests/machine_layout_tests.gd -- --qa; echo "exit $?"
```

Expected：parse error（`MachineLayout` 未定義），exit 非 0。

- [ ] **Step 3: 寫 `game/machine/machine_layout.gd`**

```gdscript
class_name MachineLayout
extends RefCounted
## 機台幾何常數同純函數。唔持有狀態，所有嘢 static。
## 座標：機台左上角 (0,0)，x 向右，y 向前（向玩家／塔門）。

const WIDTH: float = 400.0
const HEIGHT: float = 300.0
const BEZEL_Y: float = 40.0          # 推板完全收回時嘅前沿 y
const FRONT_START_Y: float = 150.0   # 後台結束、前台（有邊坑）開始
const DROP_Y: float = 280.0          # 前緣：幣中心過呢條線即跌入塔門
const GUTTER_W: float = 18.0         # 前台左右邊坑闊度
const CHUTE_LEFT: Vector2 = Vector2(30.0, 48.0)
const CHUTE_RIGHT: Vector2 = Vector2(370.0, 48.0)

enum Zone { BOARD, SCORED, LOST_LEFT, LOST_RIGHT }


static func pusher_front_y(time: float, period: float, stroke: float, rest_y: float) -> float:
	if period <= 0.0:
		return rest_y
	var phase: float = fmod(time, period) / period
	return rest_y + stroke * (0.5 - 0.5 * cos(TAU * phase))


static func classify(pos: Vector2) -> Zone:
	if pos.y >= DROP_Y:
		return Zone.SCORED
	if pos.y >= FRONT_START_Y:
		if pos.x < GUTTER_W:
			return Zone.LOST_LEFT
		if pos.x > WIDTH - GUTTER_W:
			return Zone.LOST_RIGHT
	return Zone.BOARD


static func cycle_index(time: float, period: float) -> int:
	if period <= 0.0:
		return 0
	return int(floor(time / period))
```

- [ ] **Step 4: 寫 `game/machine/machine_tuning.gd`**

```gdscript
class_name MachineTuning
extends Resource
## 所有手感參數。調手感改 .tres，唔改 code。

@export_group("Pusher")
@export var pusher_period: float = 2.4
@export var pusher_stroke: float = 36.0
@export var pusher_thickness: float = 24.0
@export var pusher_rest_y: float = 40.0

@export_group("Coin physics")
@export var linear_damp: float = 3.0
@export var friction: float = 0.6
@export var bounce: float = 0.1
@export var coin_radius: float = 7.0

@export_group("Firing")
@export var fire_speed: float = 180.0
@export var fire_forward_speed: float = 40.0
@export var fire_jitter_deg: float = 6.0
@export var fire_cooldown: float = 0.25
@export var fire_flight_time: float = 0.3
@export var clip_size: int = 20

@export_group("Settle")
@export var settle_speed: float = 4.0
@export var settle_seconds: float = 2.0

@export_group("Bed")
@export var bed_start_y: float = 90.0
@export var bed_end_y: float = 270.0
@export var bed_spacing: float = 17.0
@export var bed_x_start: float = 30.0
@export var bed_x_end: float = 370.0
@export var bed_jitter: float = 1.0
```

- [ ] **Step 5: 寫 `game/machine/machine_tuning.tres`**

```
[gd_resource type="Resource" script_class="MachineTuning" load_steps=2 format=3]

[ext_resource type="Script" path="res://game/machine/machine_tuning.gd" id="1_tuning"]

[resource]
script = ExtResource("1_tuning")
pusher_period = 2.4
pusher_stroke = 36.0
pusher_thickness = 24.0
pusher_rest_y = 40.0
linear_damp = 3.0
friction = 0.6
bounce = 0.1
coin_radius = 7.0
fire_speed = 180.0
fire_forward_speed = 40.0
fire_jitter_deg = 6.0
fire_cooldown = 0.25
fire_flight_time = 0.3
clip_size = 20
settle_speed = 4.0
settle_seconds = 2.0
bed_start_y = 90.0
bed_end_y = 270.0
bed_spacing = 17.0
bed_x_start = 30.0
bed_x_end = 370.0
bed_jitter = 1.0
```

- [ ] **Step 6: 匯入（新 class_name 要刷 class cache）再跑測試**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --editor --import
"$G" --headless --path $R --script res://tests/machine_layout_tests.gd -- --qa; echo "exit $?"
```

Expected：`MachineLayout: 26 checks, 0 failures`，exit 0。

- [ ] **Step 7: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git add -A && git commit -m "$(printf 'Phase 0: MachineLayout pure geometry + MachineTuning resource (TDD)\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 3: `Coin`（飛行→落地）同 `Pusher`

**Files:**
- Create: `game/machine/coin.gd`, `game/machine/pusher.gd`
- Test: `tests/coin_pusher_tests.gd`

**Interfaces:**
- Consumes: `MachineLayout`, `MachineTuning`（Task 2）
- Produces:
  - `Coin extends RigidBody2D`：`value: int`, `radius: float`, `uid: int`, `is_airborne: bool`；`setup(tuning: MachineTuning, coin_value: int, coin_uid: int, coin_color: Color) -> void`；`launch(from: Vector2, to: Vector2, flight_time: float, landing_velocity: Vector2) -> void`；`place(at: Vector2) -> void`；signal `landed(coin: Coin)`
  - `Pusher extends AnimatableBody2D`：`time: float`, `cycles_completed: int`；`configure(tuning: MachineTuning) -> void`；`step(delta: float) -> void`；`front_y() -> float`；`set_period_keep_phase(new_period: float) -> void`；signal `cycle_completed(index: int)`

- [ ] **Step 1: 寫失敗測試 `tests/coin_pusher_tests.gd`**

```gdscript
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var tuning: MachineTuning = load("res://game/machine/machine_tuning.tres")
	await test_coin_setup(tuning)
	await test_coin_flight(tuning)
	await test_pusher(tuning)
	print("CoinPusher: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func test_coin_setup(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 3, 42, Color.WHITE)
	root.add_child(coin)
	await physics_frame
	check(coin.value == 3 and coin.uid == 42, "coin keeps value and uid")
	check(is_equal_approx(coin.radius, tuning.coin_radius), "coin radius from tuning")
	check(is_zero_approx(coin.gravity_scale), "coin has no gravity")
	check(coin.linear_damp_mode == RigidBody2D.DAMP_MODE_REPLACE, "damp replaces project default")
	check(is_equal_approx(coin.linear_damp, tuning.linear_damp), "coin damp from tuning")
	check(coin.physics_material_override != null and is_equal_approx(coin.physics_material_override.friction, tuning.friction), "friction from tuning")
	var shape: CollisionShape2D = coin.get_node("Shape")
	check(shape != null and shape.shape is CircleShape2D and is_equal_approx((shape.shape as CircleShape2D).radius, tuning.coin_radius), "circle collider matches radius")
	coin.place(Vector2(100, 100))
	await physics_frame
	check(not coin.is_airborne and coin.collision_layer == 1 and coin.collision_mask == 1, "placed coin is solid")
	coin.queue_free()
	await physics_frame


func test_coin_flight(tuning: MachineTuning) -> void:
	var coin: Coin = Coin.new()
	coin.setup(tuning, 1, 1, Color.WHITE)
	root.add_child(coin)
	var landed_box: Dictionary = {"count": 0}
	coin.landed.connect(func(_c: Coin) -> void: landed_box["count"] += 1)
	coin.launch(Vector2(30, 48), Vector2(90, 70), 0.3, Vector2(60, 20))
	await physics_frame
	check(coin.is_airborne and coin.collision_layer == 0 and coin.collision_mask == 0, "airborne coin does not collide")
	check(coin.freeze, "airborne coin is frozen (kinematic)")
	for _i in range(8):
		await physics_frame
	check(coin.position.x > 30.0 and coin.position.x < 90.0, "coin moves along flight path")
	for _i in range(16):
		await physics_frame
	check(not coin.is_airborne, "coin lands after flight time")
	check(coin.position.distance_to(Vector2(90, 70)) < 1.5, "coin lands at target")
	check(landed_box["count"] == 1, "landed emitted exactly once")
	check(not coin.freeze and coin.collision_layer == 1, "landed coin is physical")
	check(coin.linear_velocity.length() > 10.0, "landing velocity applied")
	coin.queue_free()
	await physics_frame


func test_pusher(tuning: MachineTuning) -> void:
	var pusher: Pusher = Pusher.new()
	root.add_child(pusher)
	pusher.configure(tuning)
	await physics_frame
	check(is_equal_approx(pusher.front_y(), tuning.pusher_rest_y), "pusher starts at rest")
	check(is_equal_approx(pusher.position.x, MachineLayout.WIDTH / 2.0), "pusher centred horizontally")
	check(is_equal_approx(pusher.position.y, tuning.pusher_rest_y - tuning.pusher_thickness / 2.0), "pusher body sits behind its front face")
	var cycles_box: Dictionary = {"count": 0, "last": -1}
	pusher.cycle_completed.connect(func(i: int) -> void:
		cycles_box["count"] += 1
		cycles_box["last"] = i)
	var dt: float = 1.0 / 60.0
	for _i in range(72):
		pusher.step(dt)
	check(absf(pusher.front_y() - (tuning.pusher_rest_y + tuning.pusher_stroke)) < 1.5, "after half period pusher is near full extension")
	for _i in range(72):
		pusher.step(dt)
	check(cycles_box["count"] == 1 and cycles_box["last"] == 1, "one cycle completed after full period")
	check(absf(pusher.front_y() - tuning.pusher_rest_y) < 1.5, "pusher back near rest")
	var before_phase: float = fmod(pusher.time, tuning.pusher_period) / tuning.pusher_period
	pusher.set_period_keep_phase(1.2)
	var after_phase: float = fmod(pusher.time, 1.2) / 1.2
	check(absf(before_phase - after_phase) < 0.01, "changing period keeps phase")
	check(is_equal_approx(tuning.pusher_period, 1.2), "period written back to tuning")
	tuning.pusher_period = 2.4
	pusher.queue_free()
	await physics_frame
```

- [ ] **Step 2: 跑，確認失敗**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --script res://tests/coin_pusher_tests.gd -- --qa; echo "exit $?"
```

Expected：parse error（`Coin`／`Pusher` 未定義），exit 非 0。

- [ ] **Step 3: 寫 `game/machine/coin.gd`**

```gdscript
class_name Coin
extends RigidBody2D
## 一枚幣。發出時先「飛行」（無碰撞、凍結、沿直線移動），落地先變真物理體。
## 唔識魔塔數值；value 只係一個數字畀上層用。

signal landed(coin: Coin)

var value: int = 1
var radius: float = 7.0
var uid: int = 0
var color: Color = Color(0.80, 0.50, 0.20)
var is_airborne: bool = false

var _shape: CircleShape2D
var _flight_from: Vector2
var _flight_to: Vector2
var _flight_time: float = 0.0
var _flight_elapsed: float = 0.0
var _landing_velocity: Vector2 = Vector2.ZERO


func _init() -> void:
	_shape = CircleShape2D.new()
	_shape.radius = radius
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Shape"
	cs.shape = _shape
	add_child(cs)
	gravity_scale = 0.0
	can_sleep = true
	contact_monitor = false
	collision_layer = 1
	collision_mask = 1


func setup(tuning: MachineTuning, coin_value: int, coin_uid: int, coin_color: Color) -> void:
	value = coin_value
	uid = coin_uid
	color = coin_color
	radius = tuning.coin_radius
	_shape.radius = radius
	gravity_scale = 0.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = tuning.linear_damp
	angular_damp = tuning.linear_damp
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = tuning.friction
	mat.bounce = tuning.bounce
	physics_material_override = mat
	queue_redraw()


func apply_damp(damp: float) -> void:
	linear_damp = damp
	angular_damp = damp


## 直接放喺枱上（床幣用）。
func place(at: Vector2) -> void:
	is_airborne = false
	freeze = false
	collision_layer = 1
	collision_mask = 1
	position = at
	linear_velocity = Vector2.ZERO


## 由槽口飛去落點，flight_time 秒後落地變物理體並帶 landing_velocity。
func launch(from: Vector2, to: Vector2, flight_time: float, landing_velocity: Vector2) -> void:
	_flight_from = from
	_flight_to = to
	_flight_time = maxf(flight_time, 0.0001)
	_flight_elapsed = 0.0
	_landing_velocity = landing_velocity
	is_airborne = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	position = from
	linear_velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_airborne:
		return
	_flight_elapsed += delta
	var t: float = clampf(_flight_elapsed / _flight_time, 0.0, 1.0)
	position = _flight_from.lerp(_flight_to, t)
	if t >= 1.0:
		_land()


func _land() -> void:
	is_airborne = false
	position = _flight_to
	collision_layer = 1
	collision_mask = 1
	freeze = false
	linear_velocity = _landing_velocity
	landed.emit(self)


func _draw() -> void:
	var scale_up: float = 1.25 if is_airborne else 1.0
	var r: float = radius * scale_up
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 24, color.darkened(0.35), 1.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.25, color.lightened(0.4))
```

- [ ] **Step 4: 寫 `game/machine/pusher.gd`**

```gdscript
class_name Pusher
extends AnimatableBody2D
## 正弦來回推板。position 每個 physics tick 由 step() 設定；sync_to_physics 令佈真正推動幣。

signal cycle_completed(index: int)

var tuning: MachineTuning
var time: float = 0.0
var cycles_completed: int = 0

var _shape: RectangleShape2D


func _init() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 1
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(MachineLayout.WIDTH, 24.0)
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.name = "Shape"
	cs.shape = _shape
	add_child(cs)


func configure(t: MachineTuning) -> void:
	tuning = t
	_shape.size = Vector2(MachineLayout.WIDTH, t.pusher_thickness)
	time = 0.0
	cycles_completed = 0
	_apply()
	queue_redraw()


func step(delta: float) -> void:
	var before: int = MachineLayout.cycle_index(time, tuning.pusher_period)
	time += delta
	var after: int = MachineLayout.cycle_index(time, tuning.pusher_period)
	_apply()
	if after > before:
		cycles_completed = after
		cycle_completed.emit(after)


func front_y() -> float:
	return MachineLayout.pusher_front_y(time, tuning.pusher_period, tuning.pusher_stroke, tuning.pusher_rest_y)


## 預測 seconds_ahead 秒後嘅前沿 y（發幣落點用）。
func front_y_after(seconds_ahead: float) -> float:
	return MachineLayout.pusher_front_y(time + seconds_ahead, tuning.pusher_period, tuning.pusher_stroke, tuning.pusher_rest_y)


func set_period_keep_phase(new_period: float) -> void:
	var old_period: float = tuning.pusher_period
	var cycles: float = floor(time / old_period)
	var phase: float = fmod(time, old_period) / old_period
	tuning.pusher_period = new_period
	time = (cycles + phase) * new_period


func _apply() -> void:
	position = Vector2(MachineLayout.WIDTH / 2.0, front_y() - tuning.pusher_thickness / 2.0)


func _draw() -> void:
	var half: float = (tuning.pusher_thickness if tuning else 24.0) / 2.0
	var w: float = MachineLayout.WIDTH
	draw_rect(Rect2(-w / 2.0, -half, w, half * 2.0), Color(0.36, 0.33, 0.42))
	draw_rect(Rect2(-w / 2.0, half - 3.0, w, 3.0), Color(0.78, 0.70, 0.52))
	draw_rect(Rect2(-w / 2.0, -half, w, 2.0), Color(0.22, 0.20, 0.27))
```

- [ ] **Step 5: 匯入 + 跑測試**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --editor --import
"$G" --headless --path $R --script res://tests/coin_pusher_tests.gd -- --qa; echo "exit $?"
```

Expected：`CoinPusher: 23 checks, 0 failures`，exit 0。如果 `after half period pusher is near full extension` 失敗，檢查 `step()` 有冇先加 time 再 `_apply()`。

- [ ] **Step 6: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git add -A && git commit -m "$(printf 'Phase 0: Coin (flight then physics) and sinusoidal Pusher\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 4: `Machine` 場景：牆、床幣、發幣、分區、信號、靜止判定

**Files:**
- Create: `game/machine/machine.gd`
- Test: `tests/machine_sim_tests.gd`

**Interfaces:**
- Consumes: `MachineLayout`, `MachineTuning`, `Coin`, `Pusher`
- Produces: `Machine extends Node2D`
  - signals：`coin_scored(coin: Coin)`, `coin_lost(coin: Coin, side: int)`, `pusher_cycle(index: int)`, `settled()`, `clip_changed(remaining: int)`
  - vars：`tuning: MachineTuning`, `seed_value: int`, `clip: int`, `scored_count: int`, `lost_count: int`, `scored_value: int`
  - funcs：`reset(new_seed: int) -> void`, `refill(count: int) -> void`, `fire(side: int) -> bool`（0 左 1 右）, `coins_on_board() -> int`, `board_coins() -> Array[Coin]`, `set_pusher_period(p: float) -> void`, `apply_tuning_to_coins() -> void`, `is_settled() -> bool`
  - child node 名：`Walls`, `Pusher`, `Coins`

- [ ] **Step 1: 寫失敗測試 `tests/machine_sim_tests.gd`**

```gdscript
extends SceneTree
## Headless 物理模擬。每場 ~20 秒遊戲時間；三場合共約 1 分鐘真實時間。

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
	var bed: int = a["bed_count"]
	check(bed >= 200 and bed <= 260, "bed has roughly 230 coins (got %d)" % bed)
	check(a["fired"] == 20, "all 20 clip coins fired (got %d)" % a["fired"])
	check(a["scored"] + a["lost"] + a["on_board"] == bed + 20, "every coin is scored, lost or on board")
	check(a["scored"] > 0, "some coins reach the drop edge within 20s (got %d)" % a["scored"])
	check(a["scored_value"] == a["scored"], "copper-only board: scored value equals scored count")
	check(a["cycles"] >= 7, "pusher completes at least 7 cycles in 20s (got %d)" % a["cycles"])
	check(a["scored"] == b["scored"] and a["lost"] == b["lost"], "same seed gives same scored/lost (%d/%d vs %d/%d)" % [a["scored"], a["lost"], b["scored"], b["lost"]])
	check(a["positions"] == b["positions"], "same seed gives identical final positions")
	check(a["positions"] != c["positions"] or a["scored"] != c["scored"], "different seed changes the outcome")
	check(a["clip_after"] == 0, "clip empty after firing 20")
	print("MachineSim: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)


func simulate(seed_value: int) -> Dictionary:
	var machine: Machine = Machine.new()
	machine.tuning = load("res://game/machine/machine_tuning.tres")
	root.add_child(machine)
	await physics_frame
	machine.reset(seed_value)
	var bed_count: int = machine.coins_on_board()
	var box: Dictionary = {"cycles": 0, "settled": false}
	machine.pusher_cycle.connect(func(_i: int) -> void: box["cycles"] += 1)
	machine.settled.connect(func() -> void: box["settled"] = true)
	var fired: int = 0
	var ticks: int = 0
	for i in range(20):
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
```

- [ ] **Step 2: 跑，確認失敗**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --script res://tests/machine_sim_tests.gd -- --qa; echo "exit $?"
```

Expected：parse error（`Machine` 未定義），exit 非 0。

- [ ] **Step 3: 寫 `game/machine/machine.gd`**

```gdscript
class_name Machine
extends Node2D
## 推幣機台：牆、推板、床幣、發幣、分區判定、靜止判定。
## 只發信號，唔識魔塔數值。上層（rules）聽信號。

signal coin_scored(coin: Coin)
signal coin_lost(coin: Coin, side: int)
signal pusher_cycle(index: int)
signal settled()
signal clip_changed(remaining: int)

const COPPER_COLOR: Color = Color(0.80, 0.50, 0.20)

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
var _still_time: float = 0.0
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
	_still_time = 0.0
	_settled_emitted = false
	_pusher.configure(tuning)
	_spawn_bed()
	clip = tuning.clip_size
	clip_changed.emit(clip)


func refill(count: int) -> void:
	clip += count
	_settled_emitted = false
	_still_time = 0.0
	clip_changed.emit(clip)


func coins_on_board() -> int:
	return _coins.size()


func board_coins() -> Array[Coin]:
	return _coins.duplicate()


func is_settled() -> bool:
	return _settled_emitted


## side: 0 左槽、1 右槽。回傳 true 代表真係發咗一枚。
func fire(side: int) -> bool:
	if clip <= 0 or _cooldown[side] > 0.0:
		return false
	var origin: Vector2 = MachineLayout.CHUTE_LEFT if side == 0 else MachineLayout.CHUTE_RIGHT
	var dir_x: float = 1.0 if side == 0 else -1.0
	var jitter: float = deg_to_rad(rng.randf_range(-tuning.fire_jitter_deg, tuning.fire_jitter_deg))
	var vel: Vector2 = Vector2(dir_x * tuning.fire_speed, tuning.fire_forward_speed).rotated(jitter)
	# 落點 = 槽口 + 速度 × 飛行時間；y 最少係推板落地一刻前沿 + 半徑 + 2，保證唔會落入推板身體
	var target: Vector2 = origin + vel * tuning.fire_flight_time
	var min_y: float = _pusher.front_y_after(tuning.fire_flight_time) + tuning.coin_radius + 2.0
	target.y = maxf(target.y, min_y)
	target.x = clampf(target.x, tuning.coin_radius + 1.0, MachineLayout.WIDTH - tuning.coin_radius - 1.0)
	var coin: Coin = _make_coin(1, COPPER_COLOR)
	coin.launch(origin, target, tuning.fire_flight_time, vel * 0.4)
	_coins_root.add_child(coin)
	_coins.append(coin)
	clip -= 1
	_cooldown[side] = tuning.fire_cooldown
	_settled_emitted = false
	_still_time = 0.0
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


func _spawn_bed() -> void:
	var y: float = tuning.bed_start_y
	while y <= tuning.bed_end_y + 0.001:
		var x: float = tuning.bed_x_start
		while x <= tuning.bed_x_end + 0.001:
			var jitter: Vector2 = Vector2(
				rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter),
				rng.randf_range(-tuning.bed_jitter, tuning.bed_jitter))
			var coin: Coin = _make_coin(1, COPPER_COLOR)
			_coins_root.add_child(coin)
			coin.place(Vector2(x, y) + jitter)
			_coins.append(coin)
			x += tuning.bed_spacing
		y += tuning.bed_spacing


func _build_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 1
	add_child(walls)
	_add_box(walls, Rect2(-10.0, 0.0, 10.0, MachineLayout.HEIGHT))                     # 左牆
	_add_box(walls, Rect2(MachineLayout.WIDTH, 0.0, 10.0, MachineLayout.HEIGHT))       # 右牆
	_add_box(walls, Rect2(0.0, 0.0, MachineLayout.WIDTH, 16.0))                        # 後牆（推板後面）


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	cs.position = rect.position + rect.size / 2.0
	body.add_child(cs)


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	_cooldown[0] = maxf(0.0, _cooldown[0] - delta)
	_cooldown[1] = maxf(0.0, _cooldown[1] - delta)
	_pusher.step(delta)
	var moving: bool = false
	var i: int = _coins.size() - 1
	while i >= 0:
		var coin: Coin = _coins[i]
		if coin.is_airborne:
			moving = true
			i -= 1
			continue
		var zone: MachineLayout.Zone = MachineLayout.classify(coin.position)
		if zone == MachineLayout.Zone.SCORED:
			_coins.remove_at(i)
			scored_count += 1
			scored_value += coin.value
			coin_scored.emit(coin)
			coin.queue_free()
		elif zone == MachineLayout.Zone.LOST_LEFT or zone == MachineLayout.Zone.LOST_RIGHT:
			_coins.remove_at(i)
			lost_count += 1
			coin_lost.emit(coin, 0 if zone == MachineLayout.Zone.LOST_LEFT else 1)
			coin.queue_free()
		elif coin.linear_velocity.length() >= tuning.settle_speed:
			moving = true
		i -= 1
	if clip == 0 and not moving:
		_still_time += delta
		if _still_time >= tuning.settle_seconds and not _settled_emitted:
			_settled_emitted = true
			settled.emit()
	else:
		_still_time = 0.0


func _draw() -> void:
	var w: float = MachineLayout.WIDTH
	var h: float = MachineLayout.HEIGHT
	# 枱面：後台深、前台淺
	draw_rect(Rect2(0, 0, w, h), Color(0.16, 0.14, 0.20))
	draw_rect(Rect2(0, MachineLayout.FRONT_START_Y, w, MachineLayout.DROP_Y - MachineLayout.FRONT_START_Y), Color(0.22, 0.20, 0.26))
	# 邊坑
	var gutter_h: float = MachineLayout.DROP_Y - MachineLayout.FRONT_START_Y
	draw_rect(Rect2(0, MachineLayout.FRONT_START_Y, MachineLayout.GUTTER_W, gutter_h), Color(0.05, 0.04, 0.07))
	draw_rect(Rect2(w - MachineLayout.GUTTER_W, MachineLayout.FRONT_START_Y, MachineLayout.GUTTER_W, gutter_h), Color(0.05, 0.04, 0.07))
	# 塔門（跌落帶）
	draw_rect(Rect2(0, MachineLayout.DROP_Y, w, h - MachineLayout.DROP_Y), Color(0.55, 0.42, 0.12))
	draw_line(Vector2(0, MachineLayout.DROP_Y), Vector2(w, MachineLayout.DROP_Y), Color(0.95, 0.80, 0.30), 1.0)
	# 槽口
	draw_rect(Rect2(MachineLayout.CHUTE_LEFT - Vector2(10, 8), Vector2(20, 16)), Color(0.50, 0.50, 0.58))
	draw_rect(Rect2(MachineLayout.CHUTE_RIGHT - Vector2(10, 8), Vector2(20, 16)), Color(0.50, 0.50, 0.58))
	# 外框
	draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(0.45, 0.30, 0.15), false, 2.0)
```

- [ ] **Step 4: 匯入 + 跑測試**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --editor --import
"$G" --headless --path $R --script res://tests/machine_sim_tests.gd -- --qa; echo "exit $?"
```

Expected：`MachineSim: 10 checks, 0 failures`，exit 0；約 60 秒。

- 如果 `some coins reach the drop edge` 失敗：床幣由 y=90 起、推板最遠觸及中心 y≈85，發出嘅幣落喺 47–85 帶再被推入床。先將 `bed_start_y` 改 86 試；仍唔得就加 `pusher_stroke` 到 44。改完更新 `.tres` 同 Task 2 測試嘅預期值。
- 如果 `identical final positions` 偶然失敗（物理非完全確定）：將呢條 check 降級為 `a["scored"] == b["scored"]` 同 `positions.size()` 相等，並喺 AGENTS.md 記低。

- [ ] **Step 5: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git add -A && git commit -m "$(printf 'Phase 0: Machine scene with walls, bed coins, firing, zones, settle detection\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 5: Phase 0 demo 控制器（鍵盤、HUD、即場調參）+ smoke + 截圖

**Files:**
- Modify: `game/demo/phase0_demo.gd`（整份換）
- Test: `tests/smoke.gd`, `tests/demo_capture.gd`

**Interfaces:**
- Consumes: `Machine`、`MachineTuning`
- Produces: 主場景可玩；`tests/smoke.gd` headless 驗證主場景開到、發幣有效；`tests/demo_capture.gd` 出 `.godot/qa/phase0.png`

- [ ] **Step 1: 寫 `tests/smoke.gd`（先寫，先失敗）**

```gdscript
extends SceneTree
## Headless 開主場景，模擬發幣，驗證統計有變。

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run()


func run() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var machine: Machine = main.get_node_or_null("Machine")
	check(machine != null, "main scene has a Machine child named Machine")
	var hud: Label = main.get_node_or_null("Hud")
	check(hud != null and hud.text.length() > 0, "HUD label exists and has text")
	if machine == null:
		finish()
		return
	var bed: int = machine.coins_on_board()
	check(bed > 100, "bed coins spawned (got %d)" % bed)
	check(machine.clip == 20, "clip starts at 20")
	main.call("demo_fire", 0)
	await physics_frame
	check(machine.clip == 19, "demo_fire(0) fires one coin")
	check(machine.coins_on_board() == bed + 1, "fired coin is on board")
	main.call("demo_adjust", "period", 1)
	check(machine.tuning.pusher_period > 2.4, "period adjust up works")
	main.call("demo_adjust", "period", -1)
	check(is_equal_approx(machine.tuning.pusher_period, 2.4), "period adjust down restores")
	main.call("demo_adjust", "damp", 1)
	check(is_equal_approx(machine.tuning.linear_damp, 3.5), "damp adjust +0.5")
	main.call("demo_adjust", "damp", -1)
	check(hud.text.find("彈匣") >= 0, "HUD shows clip label in Chinese")
	finish()


func finish() -> void:
	print("Smoke: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
```

- [ ] **Step 2: 跑，確認失敗**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --script res://tests/smoke.gd -- --qa; echo "exit $?"
```

Expected：`main scene has a Machine child` 失敗，exit 1。

- [ ] **Step 3: 整份換 `game/demo/phase0_demo.gd`**

```gdscript
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
			tuning.fire_speed = clampf(tuning.fire_speed + 20.0 * d, 40.0, 400.0)
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
		"發幣初速 , .  %.0f" % tuning.fire_speed,
		"",
		"A 左發   D 右發   Space 雙發",
		"R 補 20 幣   N 新 seed   F1 收起",
		"",
		"試完話我知邊組數字手感最好。",
	])
	hud.text = "\n".join(lines)
```

- [ ] **Step 4: 跑 smoke**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --script res://tests/smoke.gd -- --qa; echo "exit $?"
```

Expected：`Smoke: 11 checks, 0 failures`，exit 0。

- [ ] **Step 5: 寫 `tests/demo_capture.gd`（真 renderer 截圖）**

```gdscript
extends SceneTree
## 用真 renderer 開主場景、發 20 幣、等 6 秒、截圖到 .godot/qa/phase0.png。
## 要唔加 --headless 跑；會短暫彈一個視窗。

func _initialize() -> void:
	run()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _i in range(10):
		await process_frame
	for i in range(20):
		main.call("demo_fire", i % 2)
		for _t in range(16):
			await physics_frame
	for _t in range(360):
		await physics_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://.godot/qa/phase0.png")
	var err: int = img.save_png(path)
	print("capture %s -> %s (%dx%d)" % ["ok" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	quit(0 if err == OK else 1)
```

- [ ] **Step 6: 跑截圖並睇圖**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --path $R --script res://tests/demo_capture.gd --resolution 1280x720 -- --qa; echo "exit $?"
```

然後用 Read 睇 `D:\magic-tower-coin-pusher-carnival\.godot\qa\phase0.png`。Expected：見到深色機台、幾百枚銅色圓幣鋪滿前台、推板喺上方、金色跌落帶喺下方、右邊中文 HUD。有幣喺跌落帶下面唔應該出現（佈們應已被移除）。

- [ ] **Step 7: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git add -A && git commit -m "$(printf 'Phase 0: demo controller with keyboard firing, HUD, live tuning; smoke + capture tests\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 6: 打包 Windows EXE

**Files:**
- Create: `export_presets.cfg`, `tools/build.ps1`, `tools/install_export_templates.ps1`
- Modify: `.gitignore`（確認 `windows-v*/`、`*.zip`、`*.exe` 已忽略）

**Interfaces:**
- Produces: `D:\magic-tower-coin-pusher-carnival\windows-v0.1.0\MagicTowerCoinPusher.exe`（內嵌 pck）同 `D:\MagicTowerCoinPusher-Windows-v0.1.0.zip`

- [ ] **Step 1: 裝 export templates `tools/install_export_templates.ps1`**

```powershell
param(
    [string]$Tpz = "",
    [string]$Version = "4.7.1.stable"
)
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:APPDATA "Godot/export_templates/$Version"
if (Test-Path (Join-Path $dest 'windows_release_x86_64.exe')) {
    Write-Host "Templates already installed at $dest"
    exit 0
}
if (-not $Tpz) {
    $Tpz = Join-Path $env:TEMP "Godot_v$($Version.Replace('.stable','-stable'))_export_templates.tpz"
    if (-not (Test-Path $Tpz)) {
        $url = "https://github.com/godotengine/godot/releases/download/$($Version.Replace('.stable','-stable'))/Godot_v$($Version.Replace('.stable','-stable'))_export_templates.tpz"
        Write-Host "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $Tpz
    }
}
$tmp = Join-Path $env:TEMP "godot-templates-extract"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null
$zip = "$Tpz.zip"
Copy-Item $Tpz $zip -Force
Expand-Archive -Path $zip -DestinationPath $tmp -Force
New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Move-Item (Join-Path $tmp 'templates') $dest
Remove-Item $zip -Force
Write-Host "Installed to $dest"
Get-ChildItem $dest -Filter 'windows_*x86_64.exe' | ForEach-Object { Write-Host $_.Name }
```

執行（tpz 已經由背景下載到 scratchpad，傳路徑入去）：

```powershell
powershell -ExecutionPolicy Bypass -File D:\magic-tower-coin-pusher-carnival\tools\install_export_templates.ps1 -Tpz "C:\Users\pongh\AppData\Local\Temp\claude\C--Users-pongh\8f1a9499-9826-4e29-af60-423c50e110ec\scratchpad\godot-templates\Godot_v4.7.1-stable_export_templates.tpz"
```

Expected：印 `Installed to ...\4.7.1.stable`、`windows_debug_x86_64.exe`、`windows_release_x86_64.exe`。

- [ ] **Step 2: 寫 `export_presets.cfg`**

```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="assets/**/*.json,assets/fonts/OFL.txt"
exclude_filter="windows-v*/*,*.zip,*.ps1,tools/*,docs/*,tests/*,*.md"
export_path="windows-v0.1.0/MagicTowerCoinPusher.exe"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
binary_format/architecture="x86_64"
texture_format/bptc=false
texture_format/s3tc=true
codesign/enable=false
application/modify_resources=false
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version="0.1.0.0"
application/product_version="0.1.0.0"
application/company_name=""
application/product_name="Magic Tower Coin Pusher"
application/file_description="Magic Tower Coin Pusher - Phase 0 feel demo"
application/copyright=""
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
ssh_remote_deploy/enabled=false
ssh_remote_deploy/host=""
ssh_remote_deploy/port="22"
ssh_remote_deploy/extra_args_ssh=""
ssh_remote_deploy/extra_args_scp=""
ssh_remote_deploy/run_script=""
ssh_remote_deploy/cleanup_script=""
```

- [ ] **Step 3: 寫 `tools/build.ps1`**

```powershell
param(
    [string]$Godot = 'D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [ValidatePattern('^[0-9]+\.[0-9]+(?:\.[0-9]+)?$')]
    [string]$Version = '0.1.0',
    [switch]$SkipZip
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot ('windows-v' + $Version)
$presetFile = Join-Path $projectRoot 'export_presets.cfg'
$exeFile = Join-Path $buildRoot 'MagicTowerCoinPusher.exe'
$zipFile = Join-Path (Split-Path $projectRoot -Parent) ('MagicTowerCoinPusher-Windows-v' + $Version + '.zip')

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) { throw 'project.godot not found beside tools/.' }
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
$templateRoot = Join-Path $env:APPDATA 'Godot/export_templates/4.7.1.stable'
$releaseTemplate = Join-Path $templateRoot 'windows_release_x86_64.exe'
$debugTemplate = Join-Path $templateRoot 'windows_debug_x86_64.exe'
if (-not (Test-Path -LiteralPath $releaseTemplate)) { throw "Run tools/install_export_templates.ps1 first. Missing: $releaseTemplate" }

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$originalPresets = Get-Content -LiteralPath $presetFile -Raw
$configured = $originalPresets.Replace('custom_template/release=""', 'custom_template/release="' + $releaseTemplate.Replace('\', '/') + '"')
$configured = $configured.Replace('custom_template/debug=""', 'custom_template/debug="' + $debugTemplate.Replace('\', '/') + '"')
$parts = @($Version.Split('.')); while ($parts.Count -lt 4) { $parts += '0' }
$fileVersion = $parts -join '.'
$configured = [regex]::Replace($configured, '(?m)^application/(file_version|product_version)="[^"]*"', { param($m) 'application/' + $m.Groups[1].Value + '="' + $fileVersion + '"' })
$configured = [regex]::Replace($configured, '(?m)^export_path="[^"]*"', 'export_path="windows-v' + $Version + '/MagicTowerCoinPusher.exe"')
$started = Get-Date
try {
    [System.IO.File]::WriteAllText($presetFile, $configured, [System.Text.UTF8Encoding]::new($false))
    $log = Join-Path $buildRoot 'export.log'
    $err = Join-Path $buildRoot 'export.errors.log'
    $p = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', ('"' + $projectRoot + '"'), '--export-release', '"Windows Desktop"', ('"' + $exeFile + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
    if ($p.ExitCode -ne 0) { Get-Content $err | Write-Host; throw "Export failed with exit code $($p.ExitCode)" }
    $bad = Select-String -LiteralPath $log, $err -Pattern '(^|\s)(SCRIPT ERROR|ERROR):'
    if ($bad) { $bad | ForEach-Object { Write-Host $_.Line }; throw 'Export reported engine errors.' }
    $exe = Get-Item -LiteralPath $exeFile
    if ($exe.Length -lt 1000000 -or $exe.LastWriteTime -lt $started) { throw 'No fresh executable produced.' }
    Write-Host ("EXE: {0} ({1:N1} MB)" -f $exeFile, ($exe.Length / 1MB))
} finally {
    [System.IO.File]::WriteAllText($presetFile, $originalPresets, [System.Text.UTF8Encoding]::new($false))
}
if (-not $SkipZip) {
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
    Compress-Archive -Path (Join-Path $buildRoot '*.exe') -DestinationPath $zipFile
    Write-Host "ZIP: $zipFile"
}
```

- [ ] **Step 4: 打包**

```powershell
powershell -ExecutionPolicy Bypass -File D:\magic-tower-coin-pusher-carnival\tools\build.ps1 -Version 0.1.0
```

Expected：`EXE: D:\magic-tower-coin-pusher-carnival\windows-v0.1.0\MagicTowerCoinPusher.exe (xx.x MB)` 同 `ZIP: D:\MagicTowerCoinPusher-Windows-v0.1.0.zip`。`git status` 唔應該見到 `windows-v0.1.0/`（已 ignore）同 `export_presets.cfg` 冇被改（finally 還原）。

- [ ] **Step 5: 真 EXE 開一次確認唔會即 crash**

```powershell
$p = Start-Process -FilePath D:\magic-tower-coin-pusher-carnival\windows-v0.1.0\MagicTowerCoinPusher.exe -PassThru; Start-Sleep -Seconds 4; $alive = -not $p.HasExited; if ($alive) { Stop-Process -Id $p.Id -Force }; Write-Host "alive after 4s: $alive"
```

Expected：`alive after 4s: True`。

- [ ] **Step 6: Commit**

```bash
cd /d/magic-tower-coin-pusher-carnival && git status --short && git add -A && git commit -m "$(printf 'Phase 0: Windows export preset, build script, export template installer\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')"
```

---

### Task 7: 全套測試、文件、PR、merge

**Files:**
- Modify: `AGENTS.md`（進度段）, `README.md`（Phase 0 操作）, `docs/superpowers/specs/2026-10-16-magic-tower-coin-pusher-design.md`（如 Task 4 改咗 bed／stroke 數值要同步）

- [ ] **Step 1: 跑全部測試**

```bash
G="/d/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe"; R=/d/magic-tower-coin-pusher-carnival
"$G" --headless --path $R --editor --import
for t in machine_layout_tests coin_pusher_tests machine_sim_tests smoke; do "$G" --headless --path $R --script res://tests/$t.gd -- --qa 2>&1 | grep -E "checks|FAILED|ERROR"; echo "$t exit ${PIPESTATUS[0]}"; done
```

Expected：四組全部 `0 failures`，exit 0。

- [ ] **Step 2: 更新 `AGENTS.md` 進度段**

喺 `## 進度` 下面加：

```markdown
### 2026-10-16 Phase 0 機台手感 demo ✅

- 完成：`game/machine/`（MachineLayout／MachineTuning／Coin／Pusher／Machine）、`game/demo/phase0_demo.gd`、四組測試、`tools/build.ps1`、EXE `windows-v0.1.0/MagicTowerCoinPusher.exe`（ZIP 喺 `D:\MagicTowerCoinPusher-Windows-v0.1.0.zip`）。
- 驗證：machine_layout 26／coin_pusher 23／machine_sim 10／smoke 11 checks 全過；`tests/demo_capture.gd` 截圖 `.godot/qa/phase0.png` 已目視；EXE 開 4 秒無 crash。
- 操作：A／D／Space 發幣，R 補幣，N 新 seed，`[ ]` 推板週期、`; '` 行程、`- =` 摩擦、`, .` 初速，F1 收起 HUD。
- 等 owner 試手感，話我知邊組數字最好 → 寫入 `machine_tuning.tres`。
- 未做：任何魔塔數值、商店、UI 流程（Phase 1）。Export templates 已裝喺 `%APPDATA%\Godot\export_templates\4.7.1.stable`。
```

- [ ] **Step 3: 更新 `README.md`**

喺列表後面加：

```markdown
## Phase 0 手感 demo（v0.1.0）

解壓 ZIP 開 `MagicTowerCoinPusher.exe`。A／D 左右發幣、Space 雙發、R 補 20 幣、N 新 seed。
`[` `]` 調推板週期、`;` `'` 調行程、`-` `=` 調枱面摩擦、`,` `.` 調發幣初速，F1 收起面板。
試完請話我知邊組數字手感最好。
```

- [ ] **Step 4: Commit、push、開 PR、merge**

```bash
cd /d/magic-tower-coin-pusher-carnival && git branch --show-current && git add -A && git commit -m "$(printf 'Phase 0: docs, progress log, README controls\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>')" && git push -u origin feat/phase0-machine && gh pr create --title "Phase 0: coin pusher machine feel demo (v0.1.0)" --body "$(cat <<'EOF'
## Summary
- Machine physics: walls, bed coins, L/R chutes with flight-then-land coins, sinusoidal pusher, drop zone / gutters, settle detection
- Phase 0 demo controller: keyboard firing, Chinese HUD, live tuning keys
- Tests: machine_layout (26), coin_pusher (23), machine_sim (10, seeded determinism), smoke (11); capture script for screenshots
- Windows export preset + build.ps1 + template installer; v0.1.0 EXE built and launched

## Test plan
- [x] All four headless suites green with `-- --qa`
- [x] `.godot/qa/phase0.png` visually checked
- [x] EXE runs 4s without crash
- [ ] Owner plays the demo and reports preferred tuning

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" && gh pr merge --squash --delete-branch --subject "Phase 0: coin pusher machine feel demo (v0.1.0)" && git switch main && git pull
```

Expected：PR 建立並 squash merge，本機 `main` 同步。

---

## Self-review

- **Spec coverage（Phase 0 範圍）**：1.1 版面 ✅ Task 2/4；1.2 幣物理 ✅ Task 3；1.3 推板 ✅ Task 3；1.4 發幣（飛行→落地、冷卻、彈匣）✅ Task 3/4；1.4a 床幣 ✅ Task 4；1.5 確定性／調參 ✅ Task 2/4（seed 測試）；第 7 節 `machine_sim_tests`／`smoke` ✅ Task 4/5；第 9 節 Phase 0 EXE ✅ Task 6。魔塔數值、幣效果、商店屬 Phase 1，唔喺本 plan。
- **Placeholder scan**：無 TBD／TODO；每步有完整 code 同預期輸出。
- **Type consistency**：`Coin.setup(tuning, value, uid, color)` 喺 Task 3 定義、Task 4 `_make_coin` 照用；`Pusher.front_y_after()` Task 3 定義、Task 4 `fire()` 用；`Machine.board_coins()/scored_value/set_pusher_period()/apply_tuning_to_coins()` Task 4 定義、Task 4 測試同 Task 5 demo 用；`demo_fire()/demo_adjust()` Task 5 定義、smoke／capture 用；HUD node 名 `Hud`、machine node 名 `Machine` 兩邊一致。
