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
	if body.name == "Personatge":
		jugador_dins = true
		print("Entrant a ", nom_casa)
		if Input.is_action_just_pressed("accio_secundaria"):
			entrar_casa()

func _on_body_exited(body):
	if body.name == "Personatge":
		jugador_dins = false

func _process(delta):
	if jugador_dins and Input.is_action_just_pressed("accio_secundaria"):
		entrar_casa()

func entrar_casa():
	if not escena_interior:
		print("Falta assignar escena_interior!")
		return
	
	print("Entrant a ", nom_casa)
	EventBus.request_player_spawn(sortida_world)
	get_tree().change_scene_to_file("res://Scenes/CasaInterior.tscn")
