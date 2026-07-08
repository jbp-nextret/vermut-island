extends CharacterBody3D

@export var nom_enemic: String = "Zombi"
@export var vida_maxima: int = 20
@export var dany: int = 10
@export var velocitat: float = 2.0
@export var rango_deteccio: float = 15.0
@export var rango_atac: float = 1.5
@export var cooldown_atac: float = 1.5
@export var textura_enemic: Texture2D
@export var es_volador: bool = false  # Marca si és volador o terrestre
@export var altura_vol: float = 2.0  # Altura a la que vola

var vida_actual = 0
var objectiu: Node3D = null
var temps_darrer_atac: float = 0.0
var velocitat_moviment = Vector3.ZERO
var gravity = 20.0
var escala_original = Vector3.ONE
var material_original: StandardMaterial3D = null
var temps_feedback: float = 0.0

var jugador: Node3D = null

@onready var sprite = $Sprite
@onready var area_deteccio = $Area3D

func _ready():
	vida_actual = vida_maxima

	add_to_group("enemics")

	if es_volador:
		add_to_group("enemics_voladors")
	else:
		add_to_group("enemics_terrestres")

	escala_original = scale

	material_original = StandardMaterial3D.new()
	material_original.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_original.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material_original.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_original.cull_mode = BaseMaterial3D.CULL_DISABLED

	if textura_enemic:
		material_original.albedo_texture = textura_enemic
	else:
		material_original.albedo_color = Color(0.8, 0.2, 0.2)

	sprite.set_surface_override_material(0, material_original)

	jugador = get_tree().get_first_node_in_group("jugador")

	if jugador == null:
		jugador = get_parent().get_node_or_null("Personatge")

	if es_volador:
		global_position.y = altura_vol

func _physics_process(delta):

	if temps_feedback > 0:
		temps_feedback -= delta
		if temps_feedback <= 0:
			restaurar_aparenca()

	if not es_volador:
		if not is_on_floor():
			velocitat_moviment.y -= gravity * delta
		else:
			velocitat_moviment.y = 0

	temps_darrer_atac += delta

	objectiu = obtenir_objectiu()

	if objectiu:

		var distancia = global_position.distance_to(objectiu.global_position)

		if distancia <= rango_deteccio:

			if distancia <= rango_atac:

				velocitat_moviment = Vector3.ZERO

				if temps_darrer_atac >= cooldown_atac:
					atacar_objectiu()
					temps_darrer_atac = 0.0

			else:

				var direccio = (objectiu.global_position - global_position).normalized()

				if es_volador:
					velocitat_moviment = direccio * velocitat
				else:
					direccio.y = 0
					velocitat_moviment.x = direccio.x * velocitat
					velocitat_moviment.z = direccio.z * velocitat

	if es_volador:
		global_position += velocitat_moviment * delta
	else:
		velocity = velocitat_moviment
		move_and_slide()

func atacar_objectiu():

	if objectiu == null:
		return

	if objectiu.is_in_group("cultius"):
		objectiu.prendre_dany(dany)
	else:
		SalutJugador.prendre_dany(dany)

	print(nom_enemic, " ataca ", objectiu.name)

func obtenir_objectiu() -> Node3D:
	var cultius = get_tree().get_nodes_in_group("cultius")

	var mes_proper: Node3D = null
	var distancia_min = INF

	for cultiu in cultius:
		if not is_instance_valid(cultiu):
			continue

		var d = global_position.distance_to(cultiu.global_position)

		if d < distancia_min:
			distancia_min = d
			mes_proper = cultiu

	if mes_proper:
		return mes_proper

	return jugador
	
func atacar_jugador():
	if objectiu == null:
		return

	# Si l'objectiu és un cultiu
	if objectiu.is_in_group("cultius"):
		if objectiu.has_method("prendre_dany"):
			objectiu.prendre_dany(dany)
			print(nom_enemic, " ataca un cultiu!")
	# Si és el jugador
	else:
		SalutJugador.prendre_dany(dany)
		print(nom_enemic, " ataca el jugador!")

func prendre_dany(quantitat: int):
	vida_actual -= quantitat
	print(nom_enemic, " pren ", quantitat, " dany. Vida: ", vida_actual)
	
	# Feedback visual
	mostrar_feedback_dany()
	
	if vida_actual <= 0:
		morir()

func mostrar_feedback_dany():
	# Pintar en vermell
	var material_dany = material_original.duplicate()
	material_dany.albedo_color = Color.RED
	sprite.set_surface_override_material(0, material_dany)
	
	# Scalat
	scale = escala_original * 1.2
	
	# Timer per restaurar
	temps_feedback = 0.2

func restaurar_aparenca():
	sprite.set_surface_override_material(0, material_original)
	scale = escala_original

func morir():
	print(nom_enemic, " ha mort!")
	
	# Partícules al morir
	mostrar_particules_mort()
	
	queue_free()

func mostrar_particules_mort():
	var particules = GPUParticles3D.new()
	particules.global_position = global_position
	get_parent().add_child(particules)
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.gravity = Vector3(0, -9.8, 0)
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.3
	
	particules.process_material = process_mat
	particules.one_shot = true
	particules.explosiveness = 0.9
	particules.amount = 30
	particules.lifetime = 1.5
	
	particules.emitting = true
	
	await get_tree().create_timer(2.0).timeout
	particules.queue_free()
