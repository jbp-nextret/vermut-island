extends Node
## Els NPCs que s'han unit al grup del jugador: el segueixen i l'ajuden.
## Cada NPC diu com ajuda amb el seu `ajudes` (vegeu npc.gd):
##   "regar"        rega els cultius amb set que hi ha a prop
##   "transportar"  porta coses: +ESPAIS_TRANSPORT espais a la motxilla
##
## Des dels diàlegs:
##   if Grup.es_membre("marta"): ...
##   if Grup.ple(): ...
##   do Grup.unir("marta")
##   do Grup.separar("marta")

signal grup_canviat

const MAXIM := 2
const ESPAIS_TRANSPORT := 4
const FITXER := "user://grup.save"

var membres: Array[String] = []

func _ready():
	carregar()

func es_membre(id: String) -> bool:
	return id in membres

func ple() -> bool:
	return membres.size() >= MAXIM

func unir(id: String) -> void:
	if es_membre(id) or ple():
		return
	membres.append(id)
	_canvi()

func separar(id: String) -> void:
	if not es_membre(id):
		return
	membres.erase(id)
	_canvi()

## Els NPCs del grup que hi ha a l'escena
func npcs() -> Array:
	return get_tree().get_nodes_in_group("npcs").filter(func(n): return es_membre(n.id))

## Espais de motxilla que aporten els companys que transporten
func espais_extra() -> int:
	var total := 0
	for n in npcs():
		if "transportar" in n.ajudes:
			total += ESPAIS_TRANSPORT
	return total

func _canvi():
	guardar()
	grup_canviat.emit()
	Progressio._aplicar_efectes()   # els espais de la motxilla

func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(membres))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Array:
		membres.clear()
		for id in d:
			membres.append(str(id))
