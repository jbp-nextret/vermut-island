extends Node3D

enum Estat { LLAVOR, CREIXENT, MIG, GRAN, MADUR }

@export var dies_per_fase = 2      # dies de joc per pujar de fase
@export var textures: Array[Texture2D] = []  # assigna els 5 sprites a l'Inspector


var estat_actual = Estat.LLAVOR
var dies_passats = 0
var recollit = false

@onready var sprite = $Sprite
@onready var area = $Area3D

func _ready():
	add_to_group("cultius")
	
	# Alinea el sprite amb el terra automàticament
	var quad = $Sprite.mesh
	$Sprite.position.y = quad.size.y / 2.0
	
	area.body_entered.connect(_jugador_a_prop)
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

func _jugador_a_prop(body):
	if body.name == "Personatge" and estat_actual == Estat.MADUR:
		recollit = true
		# Avisa al gestor de cultius que s'ha collit
		# EventBus.emit_signal("cultiu_recollit", self)
		queue_free()
		
func _process(delta):
	if recollit or estat_actual != Estat.MADUR:
		return
	
	var personatge = get_node("../Personatge")
	if personatge == null:
		return
	
	var distancia = global_position.distance_to(personatge.global_position)
	if distancia < 1.5 and Input.is_action_just_pressed("ui_accept"):
		recollit = true
		print("Recollit: " + name)
		Inventari.afegir("raim", 1)
		EventBus.emit_signal("cultiu_recollit", global_position)
		queue_free()
