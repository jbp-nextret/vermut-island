extends Area3D

@export var velocitat: float = 15.0
@export var dany: int = 3
@export var vida_util: float = 3.0  # es destrueix si no impacta en X segons
@onready var particules: GPUParticles3D = $GPUParticles3D

var direccio: Vector3 = Vector3.ZERO
var temps_viu: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	_configurar_trail()

func _physics_process(delta):
	global_position += direccio * velocitat * delta
	temps_viu += delta
	if temps_viu >= vida_util:
		queue_free()

func _on_body_entered(body):
	if body == get_tree().get_first_node_in_group("jugador"):
		return
	if body.has_method("prendre_dany"):
		body.prendre_dany(dany)
	_impacte()

func _impacte():
	_crear_cercle_alquimia()
	particules.emitting = false
	particules.reparent(get_tree().current_scene)  # es queden soles
	get_tree().create_timer(particules.lifetime).timeout.connect(particules.queue_free)
	queue_free()

func _crear_cercle_alquimia():
	var cercle := Sprite3D.new()
	cercle.texture = preload("res://sprites/Misc/magic-3.png")
	cercle.pixel_size = 0.01
	cercle.billboard = 0
	cercle.rotation_degrees.x = -90
	cercle.scale = Vector3.ONE * 0.3
	cercle.modulate.a = 0.0

	get_tree().current_scene.add_child(cercle)   # primer afegir a l'arbre
	cercle.global_position = global_position      # després assignar posició

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cercle, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cercle, "modulate:a", 1.0, 0.15)
	tween.tween_property(cercle, "rotation_degrees:y", 180.0, 2.0)
	tween.chain().tween_interval(1.0)
	tween.tween_callback(func():
		var fade_out = create_tween()
		fade_out.set_parallel(true)
		fade_out.tween_property(cercle, "modulate:a", 0.0, 0.5)
		fade_out.tween_property(cercle, "scale", Vector3.ONE * 1.3, 0.5)
		fade_out.chain().tween_callback(cercle.queue_free)
	)
	
func _configurar_trail():
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)  # cap enrere respecte al moviment; ajustarem amb emission
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color(1.0, 0.5, 0.1, 0.8)  # taronja foc

	particules.process_material = mat
	particules.amount = 20
	particules.lifetime = 0.4
	particules.emitting = true
