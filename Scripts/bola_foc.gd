extends Area3D
@export var velocitat: float = 15.0
@export var dany: int = 3
@export var vida_util: float = 3.0
@onready var particules: GPUParticles3D = $GPUParticles3D
var direccio: Vector3 = Vector3.ZERO
var temps_viu: float = 0.0
const TEXTURA_TRAIL := preload("res://sprites/Misc/particle_3.PNG")
const TEXTURA_EXPLOSIO := preload("res://sprites/Misc/particle_0.PNG")

func _ready():
	body_entered.connect(_on_body_entered)
	particules.local_coords = false
	_configurar_trail()

func _configurar_trail():
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.50
	mat.scale_max = 1.50
	mat.color = Color(1.0, 0.5, 0.1, 0.8)
	particules.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.60, 0.60)
	quad.material = _crear_material_particula(TEXTURA_TRAIL)
	particules.draw_pass_1 = quad

	particules.amount = 20
	particules.lifetime = 0.4
	particules.emitting = true

func _physics_process(delta):
	global_position += direccio * velocitat * delta
	temps_viu += delta
	if temps_viu >= vida_util:
		_desaparixer_sense_impacte()

func _on_body_entered(body):
	if body == get_tree().get_first_node_in_group("jugador"):
		return
	if body.has_method("prendre_dany"):
		body.prendre_dany(dany)
	_impacte()

func _impacte():
	_explosio_particules()
	_alliberar_particules()
	queue_free()
	
func _explosio_particules():
	var explosio := GPUParticles3D.new()
	get_tree().current_scene.add_child(explosio)   # primer afegir a l'arbre
	explosio.global_position = global_position       # després assignar posició

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color(0.508, 0.511, 0.507, 0.9)
	mat.angular_velocity_min = -720.0
	mat.angular_velocity_max = 720.0

	explosio.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30)
	quad.material = _crear_material_particula(TEXTURA_EXPLOSIO)
	explosio.draw_pass_1 = quad

	explosio.one_shot = true
	explosio.explosiveness = 0.9
	explosio.amount = 25
	explosio.lifetime = 0.6
	explosio.emitting = true

	get_tree().create_timer(1.0).timeout.connect(explosio.queue_free)

func _desaparixer_sense_impacte():
	_alliberar_particules()
	queue_free()

func _alliberar_particules():
	particules.emitting = false
	particules.reparent(get_tree().current_scene)
	get_tree().create_timer(particules.lifetime).timeout.connect(particules.queue_free)

func _crear_material_particula(textura: Texture2D) -> StandardMaterial3D:
	var textura_mat := StandardMaterial3D.new()
	textura_mat.albedo_texture = textura
	textura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	textura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	textura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	textura_mat.vertex_color_use_as_albedo = true
	textura_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return textura_mat
