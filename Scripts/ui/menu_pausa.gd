extends CanvasLayer
## Menú de pausa (autoload). Esc l'obre i el tanca durant la partida, sempre que no
## l'hagi fet servir abans una altra cosa (sortir del mode plantar, de construcció...).
## Atura el joc i permet: continuar, opcions, desar, desar i tornar al menú, i sortir.

const ESCENES_DE_JOC := ["res://Scenes/World.tscn", "res://Scenes/CasaInterior.tscn"]
const MENU_PRINCIPAL := "res://Scenes/MainMenu.tscn"

var fons: ColorRect
var caixa: PanelContainer
var boto_continuar: Button
var avis: Label
var opcions: PanellOpcions
var tween_avis: Tween

func _ready():
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	fons = ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.6)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fons)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	caixa = PanelContainer.new()
	caixa.theme = EstilMenus.tema()
	caixa.add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	centre.add_child(caixa)
	var columna := VBoxContainer.new()
	columna.custom_minimum_size = Vector2(300, 0)
	columna.add_theme_constant_override("separation", 10)
	caixa.add_child(columna)

	var titol := Label.new()
	titol.text = "Pausa"
	titol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titol.add_theme_font_size_override("font_size", 32)
	columna.add_child(titol)

	boto_continuar = _boto(columna, "Continuar", tancar)
	_boto(columna, "Opcions", _obrir_opcions)
	_boto(columna, "Desar partida", _desar)
	_boto(columna, "Desar i tornar al menú", _desar_i_menu)
	_boto(columna, "Desar i sortir del joc", _desar_i_sortir)

	avis = Label.new()
	avis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avis.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	avis.add_theme_font_size_override("font_size", 16)
	avis.modulate.a = 0.0
	columna.add_child(avis)

	opcions = PanellOpcions.new()
	opcions.visible = false
	opcions.tancat.connect(_tancar_opcions)
	centre.add_child(opcions)

func _boto(pare: Control, text: String, accio: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(accio)
	pare.add_child(b)
	return b

func en_partida() -> bool:
	var escena := get_tree().current_scene
	return escena != null and escena.scene_file_path in ESCENES_DE_JOC

func _unhandled_input(event: InputEvent):
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if not opcions.visible:   # (si hi ha les opcions obertes, les tanca el panell)
			tancar()
			get_viewport().set_input_as_handled()
	elif en_partida():
		obrir()
		get_viewport().set_input_as_handled()

func obrir():
	visible = true
	caixa.visible = true
	opcions.visible = false
	Engine.time_scale = 1.0   # per si estàvem en un "hitstop"
	get_tree().paused = true
	boto_continuar.grab_focus()

func tancar():
	visible = false
	get_tree().paused = false

func _obrir_opcions():
	caixa.visible = false
	opcions.visible = true

func _tancar_opcions():
	opcions.visible = false
	caixa.visible = true
	boto_continuar.grab_focus()

func _desar():
	GestorPartida.guardar_partida()
	avis.text = "Partida desada ✓"
	if tween_avis:
		tween_avis.kill()
	avis.modulate.a = 1.0
	tween_avis = create_tween()
	tween_avis.tween_interval(1.2)
	tween_avis.tween_property(avis, "modulate:a", 0.0, 0.5)

func _desar_i_menu():
	GestorPartida.guardar_partida()
	tancar()
	get_tree().change_scene_to_file(MENU_PRINCIPAL)

func _desar_i_sortir():
	GestorPartida.guardar_partida()
	get_tree().quit()
