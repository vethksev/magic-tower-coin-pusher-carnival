class_name Pusher
extends AnimatableBody3D
## 正弦來回推板（長方體）。position 每個 physics tick 由 step() 設定；sync_to_physics 令佔真正推動幣。
## 頂面係「上層架」，發出嘅幣先落喺頂面，推板後退時被固定刮板掃落下層平台。

signal cycle_completed(index: int)

var tuning: MachineTuning
var time: float = 0.0
var cycles_completed: int = 0

var _shape: BoxShape3D
var _mesh: MeshInstance3D


func _init() -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 1
	_shape = BoxShape3D.new()
	_shape.size = Vector3(MachineLayout.HALF_WIDTH * 2.0, MachineLayout.PUSHER_HEIGHT, MachineLayout.PUSHER_DEPTH)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _shape
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = _shape.size
	_mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.36, 0.48)
	mat.roughness = 0.8
	_mesh.material_override = mat
	add_child(_mesh)


## 設定參數並瞬移返後退位。sync_to_physics 嘅 AnimatableBody3D 任何 position 改動都當係「有速度移動」，
## 會掃飛路徑上嘅幣（第一次由原點去後退位會撞飛前排床幣），所以入咗 tree 就先離開再加入，令佢係真瞬移。
func configure(t: MachineTuning) -> void:
	tuning = t
	time = 0.0
	cycles_completed = 0
	var parent: Node = get_parent()
	if parent != null and is_inside_tree():
		parent.remove_child(self)
		_apply()
		parent.add_child(self)
	else:
		_apply()


func step(delta: float) -> void:
	var before: int = MachineLayout.cycle_index(time, tuning.pusher_period)
	time += delta
	var after: int = MachineLayout.cycle_index(time, tuning.pusher_period)
	_apply()
	if after > before:
		cycles_completed = after
		cycle_completed.emit(after)


## 前面 z（向 +z 推出）。
func front_z() -> float:
	return MachineLayout.pusher_front_z(time, tuning.pusher_period, tuning.pusher_stroke, MachineLayout.PUSHER_REST_FRONT_Z)


func front_z_after(seconds_ahead: float) -> float:
	return MachineLayout.pusher_front_z(time + seconds_ahead, tuning.pusher_period, tuning.pusher_stroke, MachineLayout.PUSHER_REST_FRONT_Z)


func top_y() -> float:
	return MachineLayout.PUSHER_HEIGHT


func set_period_keep_phase(new_period: float) -> void:
	var old_period: float = tuning.pusher_period
	var cycles: float = floor(time / old_period)
	var phase: float = fmod(time, old_period) / old_period
	tuning.pusher_period = new_period
	time = (cycles + phase) * new_period


func _apply() -> void:
	position = Vector3(0.0, MachineLayout.PUSHER_HEIGHT / 2.0, front_z() - MachineLayout.PUSHER_DEPTH / 2.0)
