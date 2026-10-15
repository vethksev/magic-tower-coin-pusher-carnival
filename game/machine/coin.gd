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
	queue_redraw()


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
	queue_redraw()
	landed.emit(self)


func _draw() -> void:
	var scale_up: float = 1.25 if is_airborne else 1.0
	var r: float = radius * scale_up
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 24, color.darkened(0.35), 1.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.25, color.lightened(0.4))
