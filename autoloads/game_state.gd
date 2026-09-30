extends Node
## Única font de veritat sobre què està fent el jugador.
## Els altres sistemes pregunten aquí abans d'actuar.

signal mode_canviat(mode: Mode)

enum Mode { EXPLORAR, CONSTRUIR, SERVEI }

var mode: Mode = Mode.EXPLORAR:
	set(valor):
		if mode == valor:
			return
		mode = valor
		mode_canviat.emit(valor)

var dins_casa := false

# Preferències (es desen a user://configuracio.cfg)
const FITXER_CONFIG := "user://configuracio.cfg"
var postprocessat_actiu := true:
	set(valor):
		postprocessat_actiu = valor
		_desar_config()
var pantalla_completa := true:
	set(valor):
		pantalla_completa = valor
		_aplicar_pantalla()
		_desar_config()

func _ready():
	var config := ConfigFile.new()
	if config.load(FITXER_CONFIG) == OK:
		postprocessat_actiu = config.get_value("grafics", "postprocessat", true)
		pantalla_completa = config.get_value("grafics", "pantalla_completa", true)
	_aplicar_pantalla()

func _aplicar_pantalla():
	if not is_inside_tree():
		return
	var finestra := get_window()
	finestra.mode = Window.MODE_FULLSCREEN if pantalla_completa else Window.MODE_WINDOWED

func _desar_config():
	var config := ConfigFile.new()
	config.set_value("grafics", "postprocessat", postprocessat_actiu)
	config.set_value("grafics", "pantalla_completa", pantalla_completa)
	config.save(FITXER_CONFIG)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pantalla_completa"):
		pantalla_completa = not pantalla_completa

func pot_atacar() -> bool:
	return mode == Mode.EXPLORAR and not dins_casa

func pot_moure() -> bool:
	return mode != Mode.CONSTRUIR

func pot_construir() -> bool:
	return dins_casa and mode == Mode.EXPLORAR

func pot_obrir_vermuteria() -> bool:
	return dins_casa and mode == Mode.EXPLORAR and GestorTemps.es_hora_de_servei()
