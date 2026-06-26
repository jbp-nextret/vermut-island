extends RigidBody3D

@export var tipus_llavor: String = "llavor_raim"
@export var quantitat: int = 1
@export var textura: Texture2D  # Assigna la textura a l'Inspector
var recollida = false

@onready var sprite = $MeshInstance3D
@onready var area = $Area3D

func _ready():
	# Configuració del RigidBody3D
	gravity_scale = 1.0
	linear_velocity = Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))
	
	# Material del sprite
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if textura:
		material.albedo_texture = textura
	else:
		material.albedo_color = Color(0.8, 0.6, 0.2)
	
	sprite.set_surface_override_material(0, material)
	
	# Connecta l'Area3D
	if area:
		area.body_entered.connect(_on_area_entered)

func _on_area_entered(body):
	if recollida: return
	if body.name == "Personatge":
		recollida = true
		Inventari.afegir(tipus_llavor, quantitat)
		print("Llavor recollida! +", quantitat, " ", tipus_llavor)
		queue_free()
