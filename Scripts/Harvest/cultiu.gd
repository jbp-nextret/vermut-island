extends Node3D

enum Estat { LLAVOR, CREIXENT, MIG, GRAN, MADUR }
@export var dies_per_fase = 2
@export var textures: Array[Texture2D] = []
@export var llavor_drop_escena: PackedScene  # Assigna a l'Inspector

var estat_actual = Estat.LLAVOR
var dies_passats = 0
var recollit = false
var jugador_a_prop = false

@onready var sprite = $Sprite
@onready var area = $Area3D
@onready var icona = $IconaRecollir

func _ready():
	icona.text = "🖱️"
	icona.visible = false
	icona.position.y = 1.2
	icona.font_size = 32
	icona.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_to_group("cultius")
	
	var quad = $Sprite.mesh
	actualitzar_sprite()

func passar_dia():
	if recollit or estat_actual == Estat.MADUR:
		return
	
	dies_passats += 1
	
	if dies_passats >= dies_per_fase:
		dies_passats = 0
		if estat_actual < Estat.MADUR:
			estat_actual += 1
			actualitzar_sprite()

func actualitzar_sprite():
	if textures.size() <= estat_actual:
		return
	
	var material = sprite.get_surface_override_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		sprite.set_surface_override_material(0, material)
	
	material = material.duplicate()
	material.albedo_texture = textures[estat_actual]
	sprite.set_surface_override_material(0, material)

func _process(delta):
	if recollit or estat_actual != Estat.MADUR:
		return
	
	var personatge = get_node("../Personatge")
	if personatge == null:
		return
	
	var distancia = global_position.distance_to(personatge.global_position)
	
	# Feedback visual quan el jugador és a prop
	if distancia < 1.5:
		icona.visible = true
		if not jugador_a_prop:
			jugador_a_prop = true
		# Pulsació contínua
		var escala = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.2
		icona.modulate = Color(1.0, 1.0, 1.0, escala)
		icona.font_size = int(32 * escala)
		
		if Input.is_action_just_pressed("accio_secundaria"):
			recollit = true
			Inventari.afegir("raim", 1)
			
			# Genera drops de llavors
			for i in range(randi_range(1, 3)):  # 1-2 llavors
				generar_llavor_drop()
			
			EventBus.emit_signal("cultiu_recollit", global_position)
			queue_free()
	else:
		# Torna a mida normal quan s'allunya
		icona.visible = false
		if jugador_a_prop:
			jugador_a_prop = false
			$Sprite.scale = Vector3.ONE

func generar_llavor_drop():
	if not llavor_drop_escena:
		print("Falta assignar llavor_drop_escena a l'Inspector")
		return
	
	var drop = llavor_drop_escena.instantiate()
	get_parent().add_child(drop)
	
	# Posiciona al voltant del cultiu
	var offset = Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
	drop.global_position = global_position + offset
	drop.tipus_llavor = "llavor_raim"
	drop.quantitat = 1
