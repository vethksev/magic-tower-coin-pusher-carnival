class_name Coin
extends RigidBody3D
## 一枚幣（3D 圓柱剛體）。發出即係真物理體：由槽口以初速、傾角、自轉飛出，落地彈開滾動。
## 唔識魔塔數值；value 只係一個數字畀上層用。

var value: int = 1
var radius: float = 0.5
var thickness: float = 0.12
var uid: int = 0
var color: Color = Color(0.85, 0.58, 0.22)
## 發出後未落地嘅幣（用嚟計「仲有嘢飛緊」）
var is_airborne: bool = false
var _airborne_ticks: int = 0

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


func apply_bounce(b: float) -> void:
	if physics_material_override != null:
		physics_material_override.bounce = b


## 直接放喺枱上（床幣用）。平放。
func place(at: Vector3) -> void:
	is_airborne = false
	_airborne_ticks = 0
	freeze = false
	collision_layer = 1
	collision_mask = 1
	global_transform = Transform3D(Basis.IDENTITY, at)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## 由槽口射出：位置、姿勢（傾角）、初速、自轉。即時係真物理體。
func launch(from: Vector3, basis_rot: Basis, velocity: Vector3, spin: Vector3) -> void:
	is_airborne = true
	_airborne_ticks = 0
	freeze = false
	collision_layer = 1
	collision_mask = 1
	global_transform = Transform3D(basis_rot, from)
	linear_velocity = velocity
	angular_velocity = spin
	sleeping = false


## Machine 每 tick 叫：飛行中嘅幣減速到好慢（或者飛咗 3 秒）就當已落地。
func tick_airborne(delta: float) -> void:
	if not is_airborne:
		return
	_airborne_ticks += 1
	if linear_velocity.length() < 1.5 or _airborne_ticks * delta > 3.0:
		is_airborne = false
