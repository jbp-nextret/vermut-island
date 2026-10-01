extends Node

signal dia_nou
signal hora_saltada(hora: float)   # quan el temps avança de cop (p. ex. en tancar la vermuteria)

# Durada d'un dia complet en segons reals
@export var durada_dia: float = 120.0
# Franja en què es pot obrir la vermuteria; en tancar-la es salta a hora_nit
@export var hora_obertura: float = 6.0
@export var hora_nit: float = 20.0

var dia_actual = 1
var hora_actual: float = 6.0  # comença a les 6 del matí (0-24)

# Pausa manual (menús, cinemàtiques...). Dins de casa el temps també s'atura.
var pausat := false

const FITXER := "user://temps.save"

func _ready():
	carregar()

## El dia i l'hora es desen amb la partida (GestorPartida)
func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"dia": dia_actual, "hora": hora_actual}))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var dades = JSON.parse_string(f.get_as_text())
	if dades is Dictionary:
		dia_actual = int(dades.get("dia", dia_actual))
		hora_actual = float(dades.get("hora", hora_actual))

func _process(delta):
	if pausat or GameState.dins_casa:
		return
	hora_actual += (24.0 / durada_dia) * delta
	if hora_actual >= 24.0:
		hora_actual -= 24.0
		passar_dia()

func passar_dia():
	dia_actual += 1
	emit_signal("dia_nou")
	# Avisa tots els cultius
	get_tree().call_group("cultius", "passar_dia")
	GestorPartida.guardar_mundo()  # Guarda després de cada dia

## Avança el rellotge fins a `hora_objectiu`. Si ja l'hem passada, va fins a la del dia següent.
func avancar_fins(hora_objectiu: float) -> void:
	if hora_objectiu <= hora_actual:
		hora_actual = hora_objectiu
		passar_dia()
	else:
		hora_actual = hora_objectiu
	hora_saltada.emit(hora_actual)

func es_nit() -> bool:
	return hora_actual < 6.0 or hora_actual >= 20.0

func es_hora_de_servei() -> bool:
	return hora_actual >= hora_obertura and hora_actual < hora_nit
