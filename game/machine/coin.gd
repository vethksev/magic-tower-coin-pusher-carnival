class_name Coin
extends RigidBody2D
## 一枚幣。發出時先「滑行」（無碰撞、凍結、沿推板前嘅條帶橫向移動），被阻先落地變真物理體。
## 滑行期間嘅阻擋判定由 Machine 做（佈知道所有幣喺邊）；Coin 只負責狀態切換同繪圖。
## 唔識魔塔數值；value 只係一個數字畀上層用。

signal landed(coin: Coin)

var value: int = 1
var radius: float = 7.0
var uid: int = 0
var color: Color = Color(0.80, 0.50, 0.20)
var is_airborne: bool = false
var slide_dir: float = 1.0      # +1 向右、-1 向左
var slide_speed: float = 0.0
var land_scale: float = 1.0     # 落地速度隨機倍率（Machine 用 seed 設定）

var _shape: CircleShape2D


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
	queue_redraw()


## 由槽口開始橫向滑行；Machine 每 tick 叫 slide_step()，被阻時叫 land_at()。
func begin_slide(from: Vector2, dir_x: float, speed: float) -> void:
	slide_dir = signf(dir_x) if dir_x != 0.0 else 1.0
	slide_speed = speed
	is_airborne = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	position = from
	linear_velocity = Vector2.ZERO
	queue_redraw()


## 回傳下一 tick 嘅位置（唔改 position；由 Machine 決定接受定落地）。
func slide_next(delta: float) -> Vector2:
	return position + Vector2(slide_dir * slide_speed * delta, 0.0)


func land_at(at: Vector2, landing_velocity: Vector2) -> void:
	is_airborne = false
	position = at
	collision_layer = 1
	collision_mask = 1
	freeze = false
	linear_velocity = landing_velocity
	queue_redraw()
	landed.emit(self)


func _draw() -> void:
	var scale_up: float = 1.2 if is_airborne else 1.0
	var r: float = radius * scale_up
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 24, color.darkened(0.35), 1.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.25, color.lightened(0.4))
