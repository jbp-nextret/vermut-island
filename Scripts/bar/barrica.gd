extends Node3D
class_name Barrica
## D'aquí surten els vermuts. Va com a fill de l'escena de moble de la barrica.

const VERMUT := preload("res://Scenes/Vermut.tscn")

@export var producte := "vermut"

func _ready():
	# La preview del mode construcció no és a "mobles_base": així no s'hi pot interactuar
	if get_parent().is_in_group("mobles_base"):
		add_to_group("interactuables")

func punt_interaccio() -> Vector3:
	return global_position

func pot_interactuar(jugador: InteraccioJugador) -> bool:
	# Sempre es pot tornar un got; omplir-ne només mentre la vermuteria és oberta
	return jugador.porta_objecte() or GameState.mode == GameState.Mode.SERVEI

func text_interaccio(jugador: InteraccioJugador) -> String:
	return "Tornar el got" if jugador.porta_objecte() else "Omplir un " + producte

func interactuar(jugador: InteraccioJugador) -> void:
	if jugador.porta_objecte():
		jugador.deixar_objecte().queue_free()
		return
	var got: Drink = VERMUT.instantiate()
	got.product = producte
	jugador.agafar(got)
	# Petit bot de la barrica
	var moble := get_parent() as Node3D
	var t := moble.create_tween()
	t.tween_property(moble, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
	t.tween_property(moble, "scale", Vector3.ONE, 0.12)
