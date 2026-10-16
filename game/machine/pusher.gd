class_name Pusher
extends AnimatableBody2D
## 正弦來回推板。position 每個 physics tick 由 step() 設定；sync_to_physics 令佔真正推動幣。

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
