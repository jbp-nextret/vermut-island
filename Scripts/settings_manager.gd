extends Node
## Totes les opcions del joc, en un sol lloc. Es desen a user://settings.cfg.
## Els altres sistemes les llegeixen amb `valor(clau)` i s'assabenten dels canvis amb
## el senyal `opcio_canviada`.

signal opcio_canviada(clau: String, valor)

const CONFIG_PATH := "user://settings.cfg"

const PER_DEFECTE := {
	# Gràfics
	"pantalla_completa": true,
	"vsync": true,
	"postprocessat": true,
	"vores": true,
	"sacseig": 1.0,
	"suavitat_camera": 0.25,   # 0 = enganxada al personatge, 1 = molt suau
	"particules_meteo": true,
	# Joc
	"numeros_dany": true,
	"boles_guiades": true,
	"ajudes": true,
	# So (0..1)
	"volum_general": 0.8,
	"volum_musica": 0.7,
	"volum_efectes": 0.8,
}

## Accions que es poden canviar de tecla des de les opcions: [acció, nom visible]
const ACCIONS_REMAPEJABLES := [
	["move_up", "Amunt"], ["move_down", "Avall"], ["move_left", "Esquerra"], ["move_right", "Dreta"],
	["jump", "Saltar"], ["sprint", "Córrer"], ["interactuar", "Interactuar"],
	["mode_combat", "Mode combat"], ["atac_magia", "Bola de foc"],
	["plantar", "Plantar"], ["regar", "Regar"], ["llaurar", "Llaurar"],
	["girar_camera_esquerra", "Girar càmera ←"], ["girar_camera_dreta", "Girar càmera →"],
	["inclinar_camera_avall", "Càmera més de costat"], ["inclinar_camera_amunt", "Càmera més des de dalt"],
	["decorar", "Construir (a casa)"], ["inventari", "Motxilla"],
]

const BUSOS := {"volum_general": "Master", "volum_musica": "Music", "volum_efectes": "SFX"}

var valors := {}

func _ready():
	_crear_busos()
	carregar()
	aplicar_tot()
	ajustar_fisica_al_monitor()
	get_window().size_changed.connect(ajustar_fisica_al_monitor)

## Tants tics de física com Hz té el monitor (entre 60 i 240): així cada fotograma de la
## pantalla correspon a un tic i el moviment és igual de suau a 60, 120 o 144 Hz.
## (Tot el codi de moviment fa servir `delta`, així que el joc va a la mateixa velocitat.)
func ajustar_fisica_al_monitor():
	var hz := DisplayServer.screen_get_refresh_rate(get_window().current_screen) if get_window() else -1.0
	# Alguns controladors no la saben (retornen -1 o NaN): llavors, 120
	var tics := 120 if is_nan(hz) or hz < 1.0 else clampi(roundi(hz), 60, 240)
	if Engine.physics_ticks_per_second != tics:
		Engine.physics_ticks_per_second = tics
		# Si en un fotograma no hi caben tots els tics (el joc va lent), que no s'acumulin
		Engine.max_physics_steps_per_frame = maxi(8, tics / 15)

func valor(clau: String):
	return valors.get(clau, PER_DEFECTE.get(clau))

func canviar(clau: String, nou) -> void:
	valors[clau] = nou
	_aplicar(clau)
	opcio_canviada.emit(clau, nou)
	desar()

func aplicar_tot():
	for clau in PER_DEFECTE:
		_aplicar(clau)

func _aplicar(clau: String):
	var v = valor(clau)
	match clau:
		"pantalla_completa":
			var finestra := get_window()
			if finestra:
				finestra.mode = Window.MODE_FULLSCREEN if v else Window.MODE_WINDOWED
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)
		"volum_general", "volum_musica", "volum_efectes":
			var bus := AudioServer.get_bus_index(BUSOS[clau])
			if bus >= 0:
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
				AudioServer.set_bus_mute(bus, v <= 0.001)

## Els busos de música i efectes (si el projecte encara no en té)
func _crear_busos():
	for nom in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nom) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nom)
			AudioServer.set_bus_send(i, "Master")

# ─────────────── Tecles

func tecla_de(accio: String) -> String:
	for ev in InputMap.action_get_events(accio):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
	for ev in InputMap.action_get_events(accio):
		if ev is InputEventMouseButton:
			return ["", "Clic esq.", "Clic dret", "Clic mig"][clampi(ev.button_index, 0, 3)]
	return "—"

## Canvia la tecla d'una acció (els botons del ratolí que tingui es mantenen)
func remapejar(accio: String, tecla: InputEventKey) -> void:
	for ev in InputMap.action_get_events(accio):
		if ev is InputEventKey:
			InputMap.action_erase_event(accio, ev)
	var nova := InputEventKey.new()
	nova.physical_keycode = tecla.physical_keycode if tecla.physical_keycode != 0 else tecla.keycode
	InputMap.action_add_event(accio, nova)
	desar()

func restaurar_per_defecte():
	valors.clear()
	InputMap.load_from_project_settings()
	aplicar_tot()
	for clau in PER_DEFECTE:
		opcio_canviada.emit(clau, valor(clau))
	desar()

# ─────────────── Desar / carregar

func desar():
	var config := ConfigFile.new()
	for clau in PER_DEFECTE:
		config.set_value("opcions", clau, valor(clau))
	for a in ACCIONS_REMAPEJABLES:
		for ev in InputMap.action_get_events(a[0]):
			if ev is InputEventKey:
				config.set_value("tecles", a[0], ev.physical_keycode)
	config.save(CONFIG_PATH)

## Les preferències que abans desava GameState (postprocessat i pantalla completa)
func _migrar_config_antiga():
	var antiga := ConfigFile.new()
	if antiga.load("user://configuracio.cfg") != OK:
		return
	valors["postprocessat"] = antiga.get_value("grafics", "postprocessat", true)
	valors["pantalla_completa"] = antiga.get_value("grafics", "pantalla_completa", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://configuracio.cfg"))
	desar()

## Compatibilitat amb el menú antic
func save_settings():
	desar()

func carregar():
	_migrar_config_antiga()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for clau in PER_DEFECTE:
		if config.has_section_key("opcions", clau):
			valors[clau] = config.get_value("opcions", clau)
	for a in ACCIONS_REMAPEJABLES:
		if config.has_section_key("tecles", a[0]):
			var ev := InputEventKey.new()
			ev.physical_keycode = config.get_value("tecles", a[0])
			for vell in InputMap.action_get_events(a[0]):
				if vell is InputEventKey:
					InputMap.action_erase_event(a[0], vell)
			InputMap.action_add_event(a[0], ev)
