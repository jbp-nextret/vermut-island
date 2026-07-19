extends Node

var mundo_actual: Node = null
var guardando: bool = false  # Previene recursión

func registrar_mundo(mundo: Node) -> void:
	if mundo and mundo.has_method("guardar_mundo"):
		mundo_actual = mundo

func desregistrar_mundo() -> void:
	mundo_actual = null

func guardar_mundo() -> void:
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
