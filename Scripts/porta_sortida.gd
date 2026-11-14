extends Area3D
## La porta de casa (a dins): F per sortir. Mentre la vermuteria és oberta no es pot sortir.

signal salir_casa

func _ready():
	add_to_group("interactuables")

func pot_interactuar(_jugador: Node) -> bool:
	return GameState.mode != GameState.Mode.CONSTRUIR

func text_interaccio(_jugador: Node) -> String:
	if GameState.mode == GameState.Mode.SERVEI:
		return "🔒 Tanca la vermuteria per sortir"
	return "🚪 Sortir"

func punt_interaccio() -> Vector3:
	return global_position + Vector3.UP * 0.2

func interactuar(_interaccio: Node) -> void:
	if GameState.mode == GameState.Mode.SERVEI:
		EventBus.avis.emit("Ara no pots sortir: estàs servint. Tanca la vermuteria primer.")
		return
	salir_casa.emit()
