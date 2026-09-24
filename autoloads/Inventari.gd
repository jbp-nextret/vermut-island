extends Node
## Inventari i diners del jugador. Es desa sol a user://inventari.save.

signal diners_canviats(diners: int)
signal items_canviats

const FITXER := "user://inventari.save"
const VERSIO := 2
const RAIM_INICIAL := 10

var items = {}
var diners: int = 0

var _desat_pendent := false

func _ready():
	if not carregar():
		# Partida nova: per provar, comencem amb llavors i una mica de raïm
		afegir("llavor_raim", 150)
		afegir("raim", RAIM_INICIAL)

func afegir(item: String, quantitat: int = 1):
	items[item] = items.get(item, 0) + quantitat
	items_canviats.emit()
	_desar_aviat()

func treure(item: String, quantitat: int = 1) -> bool:
	if tenir(item) < quantitat:
		return false
	items[item] -= quantitat
	items_canviats.emit()
	_desar_aviat()
	return true

func tenir(item: String) -> int:
	return items.get(item, 0)

func afegir_diners(quantitat: int) -> void:
	diners += quantitat
	diners_canviats.emit(diners)
	_desar_aviat()

func gastar_diners(quantitat: int) -> bool:
	if diners < quantitat:
		return false
	diners -= quantitat
	diners_canviats.emit(diners)
	_desar_aviat()
	return true

# ─────────────── Desar / carregar

# Diversos canvis en el mateix frame (p. ex. 3 porings pagant) = un sol desat
func _desar_aviat() -> void:
	if not _desat_pendent:
		_desat_pendent = true
		call_deferred("guardar")

func guardar() -> void:
	_desat_pendent = false
	var fitxer := FileAccess.open(FITXER, FileAccess.WRITE)
	if fitxer:
		fitxer.store_string(JSON.stringify({"versio": VERSIO, "items": items, "diners": diners}))
	else:
		push_error("No es pot desar l'inventari")

func carregar() -> bool:
	var fitxer := FileAccess.open(FITXER, FileAccess.READ)
	if not fitxer:
		return false
	var dades = JSON.parse_string(fitxer.get_as_text())
	if not dades is Dictionary:
		push_error("El fitxer d'inventari està malmès")
		return false
	items.clear()
	var items_desats = dades.get("items", {})
	if items_desats is Dictionary:
		for clau in items_desats:
			items[clau] = int(items_desats[clau])   # el JSON ho torna com a float
	diners = int(dades.get("diners", 0))
	if int(dades.get("versio", 1)) < 2:
		# Ara el vermut es fa amb raïm: les partides d'abans en reben una mica per començar
		items["raim"] = items.get("raim", 0) + RAIM_INICIAL
		_desar_aviat()
	return true

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()
