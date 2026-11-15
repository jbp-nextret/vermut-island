extends RigidBody3D
## Una llavor (o un altre objecte) que salta d'un cultiu en collir-lo. Es veu la seva
## icona petita; quan el jugador s'hi acosta, vola cap a ell i s'afegeix a l'inventari.

@export var tipus_llavor: String = "llavor_raim"
@export var quantitat: int = 1
@export var textura: Texture2D   # (opcional) si no n'hi ha, la icona del catàleg
var recollida = false

const ABAST_IMANT := 2.2
const TEMPS_ABANS_IMANT := 0.45

@onready var sprite = $MeshInstance3D
@onready var area = $Area3D
var icona: Label3D
var temps := 0.0

func _ready():
	gravity_scale = 1.0
	linear_velocity = Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1))
	if textura:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_texture = textura
		sprite.set_surface_override_material(0, material)
		sprite.scale = Vector3.ONE * 0.35
	else:
		# Abans era un quadrat de color enorme: ara, la icona de l'objecte, petita
		sprite.visible = false
		icona = Label3D.new()
		icona.text = str(CatalegObjectes.info(tipus_llavor).icona)
		icona.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icona.font_size = 48
		icona.pixel_size = 0.006
		icona.outline_size = 8
		icona.position = Vector3.UP * 0.15
		add_child(icona)
	if area:
		area.body_entered.connect(_on_area_entered)

func _physics_process(delta):
	temps += delta
	if recollida or temps < TEMPS_ABANS_IMANT:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador == null:
		return
	var cap := jugador.global_position + Vector3.UP * 0.6 - global_position
	if cap.length() < ABAST_IMANT:
		# Cap al jugador, cada cop més ràpid
		gravity_scale = 0.0
		linear_velocity = cap.normalized() * lerpf(9.0, 4.0, cap.length() / ABAST_IMANT)
		if cap.length() < 0.45:
			_recollir()
	else:
		gravity_scale = 1.0
	# Un petit bot perquè es vegi viu
	if icona:
		icona.position.y = 0.15 + 0.05 * sin(temps * 6.0)

func _on_area_entered(body):
	if body.is_in_group("player") and temps >= TEMPS_ABANS_IMANT:
		_recollir()

func _recollir():
	if recollida:
		return
	recollida = true
	Inventari.afegir(tipus_llavor, quantitat)
	queue_free()
