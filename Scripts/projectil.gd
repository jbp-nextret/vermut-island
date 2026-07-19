extends Area3D

@export var speed: float = 18.0
@export var dany: int = 8
@export var range: float = 12.0

var direction: Vector3 = Vector3.ZERO
var travelled: float = 0.0
var target: Node3D = null
var shooter: Node = null

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	set_physics_process(true)

func inicialitzar(target_node: Node3D, damage: int, speed_value: float = 18.0, range_value: float = 12.0, shooter_node: Node = null):
	target = target_node
	dany = damage
	speed = speed_value
	range = range_value
	shooter = shooter_node
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
	else:
		direction = -transform.basis.z.normalized()

func _process(delta):
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
	elif travelled >= range:
		queue_free()
		return

	var step = direction * speed * delta
	global_position += step
	travelled += step.length()

	if travelled >= range:
		queue_free()

func _on_body_entered(body):
	if body == shooter:
		return
	if not body.is_in_group("enemics"):
		return
	if body.has_method("prendre_dany"):
		body.prendre_dany(dany)
	queue_free()
