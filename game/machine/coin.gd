class_name Coin
extends RigidBody3D
## 一枚幣（3D 圓柱剛體）。發出時先「滑行」（無碰撞、凍結、沿推板頂面橫向移動），被阻先落地變真物理體。
## 滑行期間嘅阻擋判定由 Machine 做；Coin 只負責狀態切換同佔位外觀。
## 唔識魔塔數值；value 只係一個數字畀上層用。

signal landed(coin: Coin)

var value: int = 1
var radius: float = 0.5
var thickness: float = 0.12
var uid: int = 0
var color: Color = Color(0.85, 0.58, 0.22)
var is_airborne: bool = false
var slide_dir: float = 1.0      # +1 向右、-1 向左
var slide_speed: float = 0.0
var land_scale: float = 1.0

var _shape: CylinderShape3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _init() -> void:
	_shape = CylinderShape3D.new()
	_shape.radius = radius
	_shape.height = thickness
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _shape
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	add_child(_mesh)
	_material = StandardMaterial3D.new()
	_material.roughness = 0.55
	_material.metallic = 0.25
	can_sleep = true
	contact_monitor = false
	collision_layer = 1
	collision_mask = 1


func setup(tuning: MachineTuning, coin_value: int, coin_uid: int, coin_color: Color) -> void:
	value = coin_value
	uid = coin_uid
	color = coin_color
	radius = tuning.coin_radius
	thickness = tuning.coin_thickness
	_shape.radius = radius
	_shape.height = thickness
	mass = tuning.coin_mass
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = tuning.friction
	mat.bounce = tuning.bounce
	physics_material_override = mat
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = 12
	mesh.rings = 1
	_mesh.mesh = mesh
	_material.albedo_color = color
	_mesh.material_override = _material


func apply_friction(f: float) -> void:
	if physics_material_override != null:
		physics_material_override.friction = f


## 直接放喺枱上（床幣用）。平放。
func place(at: Vector3) -> void:
	is_airborne = false
	freeze = false
	collision_layer = 1
	collision_mask = 1
	global_transform = Transform3D(Basis.IDENTITY, at)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## 由槽口開始橫向滑行；Machine 每 tick 叫 slide_next()，被阻時叫 land_at()。
func begin_slide(from: Vector3, dir_x: float, speed: float) -> void:
	slide_dir = signf(dir_x) if dir_x != 0.0 else 1.0
	slide_speed = speed
	is_airborne = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	global_transform = Transform3D(Basis.IDENTITY, from)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## 回傳下一 tick 嘅位置（唔改 position；由 Machine 決定接受定落地）。
func slide_next(delta: float) -> Vector3:
	return position + Vector3(slide_dir * slide_speed * delta, 0.0, 0.0)


func land_at(at: Vector3, landing_velocity: Vector3) -> void:
	is_airborne = false
	global_transform = Transform3D(Basis.IDENTITY, at)
	collision_layer = 1
	collision_mask = 1
	freeze = false
	linear_velocity = landing_velocity
	angular_velocity = Vector3.ZERO
	landed.emit(self)
