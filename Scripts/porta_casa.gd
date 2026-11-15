extends Area3D
## La porta de casa (a fora): F per entrar.

@export var nom_casa: String = "Casa"
@export var escena_interior: PackedScene  # Assigna la escena interior
@export var posicio_entrada: Vector3 = Vector3.ZERO
@export var sortida_world: Vector3 = Vector3.ZERO   # (antic: ara es calcula amb punt_sortida)
const DISTANCIA_SORTIDA := 1.3

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
	EventBus.request_player_spawn(punt_sortida())
	get_tree().change_scene_to_packed(escena_interior)

## On apareix el jugador en sortir: just davant de la porta, cap a fora de la casa.
## (Abans era una posició fixa, `sortida_world`, que s'havia quedat lluny en moure la casa.)
func punt_sortida() -> Vector3:
	var porta := punt_interaccio()
	var casa := owner as Node3D if owner is Node3D else get_parent() as Node3D
	var fora := Vector3(porta.x - casa.global_position.x, 0.0, porta.z - casa.global_position.z)
	if fora.length() < 0.01:
		fora = global_transform.basis.z
		fora.y = 0.0
	return porta + fora.normalized() * DISTANCIA_SORTIDA
