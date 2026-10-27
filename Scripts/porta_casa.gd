extends Area3D

@export var nom_casa: String = "Casa"
@export var escena_interior: PackedScene  # Assigna la escena interior
@export var posicio_entrada: Vector3 = Vector3.ZERO
@export var sortida_world: Vector3 = Vector3.ZERO

var jugador_dins = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		jugador_dins = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		jugador_dins = false

func _process(_delta):
	if jugador_dins and Input.is_action_just_pressed("accio_secundaria"):
		entrar_casa()

func entrar_casa():
	if not escena_interior:
		push_error("Falta assignar escena_interior a " + nom_casa)
		return

	print("Entrant a ", nom_casa)
	GestorPartida.guardar_mundo()
	EventBus.request_player_spawn(sortida_world)
	get_tree().change_scene_to_packed(escena_interior)
