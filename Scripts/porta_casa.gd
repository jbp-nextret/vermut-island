extends Area3D
## La porta de casa (a fora): F per entrar.

@export var nom_casa: String = "Casa"
@export var escena_interior: PackedScene  # Assigna la escena interior
@export var posicio_entrada: Vector3 = Vector3.ZERO
@export var sortida_world: Vector3 = Vector3.ZERO

var jugador_dins = false

func _ready():
	add_to_group("interactuables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		jugador_dins = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		jugador_dins = false

# ─────────────── Interacció (F)

func pot_interactuar(_jugador: Node) -> bool:
	return jugador_dins

func text_interaccio(_jugador: Node) -> String:
	return "🚪 Entrar"

func punt_interaccio() -> Vector3:
	var forma := get_node_or_null("CollisionShape3D") as Node3D
	return forma.global_position if forma else global_position

func interactuar(_interaccio: Node) -> void:
	entrar_casa()

func entrar_casa():
	if not escena_interior:
		push_error("Falta assignar escena_interior a " + nom_casa)
		return
	GestorPartida.guardar_mundo()
	EventBus.request_player_spawn(sortida_world)
	get_tree().change_scene_to_packed(escena_interior)
