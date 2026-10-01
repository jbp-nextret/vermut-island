extends Node3D
class_name Barrica
## D'aquí surten els vermuts. Va com a fill de l'escena de moble de la barrica.

const VERMUT := preload("res://Scenes/Vermut.tscn")

@export var producte := "vermut"
@export var vermuts_per_raim := 3

## Vermuts que es poden servir amb el que hi ha a la barrica i a l'inventari
static func vermuts_disponibles(per_raim: int = 3) -> int:
	return Inventari.tenir("dosis_vermut") + Inventari.tenir("raim") * per_raim

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
	if jugador.porta_objecte():
		return "Tornar el got"
	var queden := vermuts_disponibles(vermuts_per_raim)
	return "Omplir un %s (%d)" % [producte, queden] if queden > 0 else "Sense raïm per fer vermut"

func interactuar(jugador: InteraccioJugador) -> void:
	if jugador.porta_objecte():
		jugador.deixar_objecte().queue_free()
		Inventari.afegir("dosis_vermut", 1)   # el vermut torna a la barrica
		return
	if not _gastar_una_dosi():
		TextFlotant.mostrar(get_parent().get_parent(), global_position + Vector3.UP, "Cal raïm! 🍇", Color(1, 0.5, 0.5))
		return
	var got: Drink = VERMUT.instantiate()
	got.product = producte
	jugador.agafar(got)
	# Petit bot de la barrica
	var moble := get_parent() as Node3D
	var t := moble.create_tween()
	t.tween_property(moble, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
	t.tween_property(moble, "scale", Vector3.ONE, 0.12)

## Treu un vermut: primer del que ja hi ha fet, si no, trepitja un raïm (que en dona uns quants)
func _gastar_una_dosi() -> bool:
	if Inventari.treure("dosis_vermut"):
		return true
	if Inventari.treure("raim"):
		Inventari.afegir("dosis_vermut", vermuts_per_raim - 1)
		return true
	return false
