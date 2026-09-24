extends Area3D
@export var velocitat: float = 15.0
@export var dany: int = 3
@export var vida_util: float = 3.0
@onready var particules: GPUParticles3D = $GPUParticles3D
var direccio: Vector3 = Vector3.ZERO
var temps_viu: float = 0.0
const TEXTURA_TRAIL := preload("res://Sprites/Misc/particle_3.PNG")
const TEXTURA_EXPLOSIO := preload("res://Sprites/Misc/particle_0.PNG")

func _ready():
	body_entered.connect(_on_body_entered)
	particules.local_coords = false
	_configurar_trail()

static var _trail_mat: ParticleProcessMaterial
static var _trail_quad: QuadMesh
static var _explosio_mat: ParticleProcessMaterial
static var _explosio_quad: QuadMesh

func _configurar_trail():
	if _trail_mat == null:
		_trail_mat = _nou_trail_mat()
		_trail_quad = QuadMesh.new()
		_trail_quad.size = Vector2(0.60, 0.60)
		_trail_quad.material = _crear_material_particula(TEXTURA_TRAIL)
	particules.process_material = _trail_mat
	particules.draw_pass_1 = _trail_quad
	particules.amount = 20
	particules.lifetime = 0.4
	particules.emitting = true

func _nou_trail_mat() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.50
	mat.scale_max = 1.50
	mat.color = Color(1.0, 0.5, 0.1, 0.8)
	return mat

func _physics_process(delta):
	global_position += direccio * velocitat * delta
	temps_viu += delta
	if temps_viu >= vida_util:
		_desaparixer_sense_impacte()

func _on_body_entered(body):
	if body.is_in_group("player"):
		return   # abans buscava el grup "jugador", que no existeix, i podia explotar contra tu
	if body.has_method("prendre_dany"):
		if body.is_in_group("enemics"):
			body.prendre_dany(dany, global_position - direccio)   # l'empeny en la direcció de la bola
		else:
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

	if _explosio_mat == null:
		_explosio_mat = _nou_explosio_mat()
		_explosio_quad = QuadMesh.new()
		_explosio_quad.size = Vector2(0.30, 0.30)
		_explosio_quad.material = _crear_material_particula(TEXTURA_EXPLOSIO)
	explosio.process_material = _explosio_mat
	explosio.draw_pass_1 = _explosio_quad

	explosio.one_shot = true
	explosio.explosiveness = 0.9
	explosio.amount = 25
	explosio.lifetime = 0.6
	explosio.emitting = true
	explosio.finished.connect(explosio.queue_free)

func _nou_explosio_mat() -> ParticleProcessMaterial:
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
	return mat

func _desaparixer_sense_impacte():
	_alliberar_particules()
	queue_free()

func _alliberar_particules():
	particules.emitting = false
	particules.reparent(get_tree().current_scene)
	get_tree().create_timer(particules.lifetime).timeout.connect(particules.queue_free)

static var _materials := {}

## Un material per textura, compartit entre totes les boles de foc
func _crear_material_particula(textura: Texture2D) -> StandardMaterial3D:
	if _materials.has(textura):
		return _materials[textura]
	var textura_mat := StandardMaterial3D.new()
	_materials[textura] = textura_mat
	textura_mat.albedo_texture = textura
	textura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	textura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	textura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	textura_mat.vertex_color_use_as_albedo = true
	textura_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return textura_mat
