extends Node

var mundo_actual: Node = null
var guardando: bool = false  # Previene recursión

func registrar_mundo(mundo: Node) -> void:
	if mundo and mundo.has_method("guardar_mundo"):
		mundo_actual = mundo

func desregistrar_mundo() -> void:
	mundo_actual = null

## Desa-ho tot: temps, inventari, món i (si hi ets) la decoració de la casa.
## És el que fa el menú de pausa.
func guardar_partida() -> void:
	guardar_mundo()
	var escena := get_tree().current_scene
	if escena and escena.has_method("guardar_decoracio"):
		escena.guardar_decoracio()

func guardar_mundo() -> void:
	Inventari.guardar()   # l'inventari i els diners es desen sempre, siguis on siguis
	GestorTemps.guardar()
	Progres.guardar()
	Progressio.guardar()
	if guardando or not is_instance_valid(mundo_actual):
		return
	
	guardando = true
	
	if mundo_actual.has_method("guardar_mundo"):
		mundo_actual.guardar_mundo()
	
	guardando = false

func cargar_mundo():
	if not is_instance_valid(mundo_actual):
		return
	 
	if mundo_actual.has_method("cargar_mundo"):
		mundo_actual.cargar_mundo()
