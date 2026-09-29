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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pantalla_completa"):
		var finestra := get_window()
		finestra.mode = Window.MODE_WINDOWED if finestra.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func pot_atacar() -> bool:
	return mode == Mode.EXPLORAR and not dins_casa

func pot_moure() -> bool:
	return mode != Mode.CONSTRUIR

func pot_construir() -> bool:
	return dins_casa and mode == Mode.EXPLORAR

func pot_obrir_vermuteria() -> bool:
	return dins_casa and mode == Mode.EXPLORAR and GestorTemps.es_hora_de_servei()
