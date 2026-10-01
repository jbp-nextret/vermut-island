extends Node
## Diari de la partida: què ha passat cada dia (servei de la vermuteria, onades).
## Ho fa servir el menú d'inventari per mostrar el progrés. Es desa a user://progres.save.

const FITXER := "user://progres.save"

var serveis := {}   # dia (text) -> {clients, guanys, enfadats}
var onades := {}    # dia (text) -> {superada, morts, total, cultius_perduts}

func _ready():
	carregar()

func registrar_servei(dia: int, clients: int, guanys: int, enfadats: int) -> void:
	serveis[str(dia)] = {"clients": clients, "guanys": guanys, "enfadats": enfadats}
	guardar()

func registrar_onada(dia: int, resum: Dictionary) -> void:
	onades[str(dia)] = {
		"superada": resum.get("superada", false),
		"morts": resum.get("morts", 0),
		"total": resum.get("total", 0),
		"cultius_perduts": resum.get("cultius_perduts", 0),
	}
	guardar()

func servei_de(dia: int) -> Dictionary:
	return serveis.get(str(dia), {})

func onada_de(dia: int) -> Dictionary:
	return onades.get(str(dia), {})

func guardar() -> void:
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"serveis": serveis, "onades": onades}))

func carregar() -> void:
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var dades = JSON.parse_string(f.get_as_text())
	if dades is Dictionary:
		serveis = dades.get("serveis", {})
		onades = dades.get("onades", {})
