extends CharacterBody3D

@export var nom_enemic: String = "Zombi"
@export var vida_maxima: int = 20
@export var dany: int = 10
@export var velocitat: float = 2.0
@export var rango_deteccio: float = 15.0
@export var rango_atac: float = 1.5
@export var cooldown_atac: float = 1.5
@export var textura_enemic: Texture2D  # Assigna a l'Inspector

var vida_actual = 0
var jugador: Node3D = null
var temps_darrer_atac: float = 0.0
var velocitat_moviment = Vector3.ZERO
var gravity = 20.0

@onready var sprite = $Sprite
@onready var area_deteccio = $Area3D

func _ready():
	vida_actual = vida_maxima
	add_to_group("enemics")
	
	# Material del sprite
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if textura_enemic:
		material.albedo_texture = textura_enemic
	else:
		material.albedo_color = Color(0.8, 0.2, 0.2)  # Color per defecte si no hi ha textura
	
	sprite.set_surface_override_material(0, material)
	
	# Busca el jugador
	jugador = get_tree().get_first_node_in_group("jugador")
	if not jugador:
		jugador = get_parent().get_node_or_null("Personatge")

func _physics_process(delta):
	if not is_on_floor():
		velocitat_moviment.y -= gravity * delta
	else:
		velocitat_moviment.y = 0
	
	temps_darrer_atac += delta
	
	if jugador:
		var distancia = global_position.distance_to(jugador.global_position)
		
		if distancia < rango_deteccio:
			if distancia < rango_atac:
				if temps_darrer_atac >= cooldown_atac:
					atacar_jugador()
					temps_darrer_atac = 0.0
			else:
				var direccio = (jugador.global_position - global_position).normalized()
				direccio.y = 0
				velocitat_moviment.x = direccio.x * velocitat
				velocitat_moviment.z = direccio.z * velocitat
	
	velocity = velocitat_moviment
	move_and_slide()

func atacar_jugador():
	SalutJugador.prendre_dany(dany)
	print(nom_enemic, " ataca! Dany: ", dany)

func prendre_dany(quantitat: int):
	vida_actual -= quantitat
	print(nom_enemic, " pren ", quantitat, " dany. Vida: ", vida_actual)
	
	if vida_actual <= 0:
		morir()

func morir():
	print(nom_enemic, " ha mort!")
	queue_free()
