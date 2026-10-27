extends Control

@export var menu: VBoxContainer
@export var main_settings: VBoxContainer
@export var video_settings: VBoxContainer
@export var audio_settings: VBoxContainer
@export var controls_settings: VBoxContainer
@export var language_settings: VBoxContainer
@export var back_button: Button
 
@export var settings_button : Button
@export var video_button: Button
@export var audio_button: Button
@export var controls_button: Button
@export var language_button: Button
 
var nav_stack: Array[Control] = []
var current_panel
var opcions: PanellOpcions
var titol: Label
 
func _ready():
	current_panel = menu
	_show_panel(menu)
	_update_back_button()
 
	if not back_button.pressed.is_connected(_on_back_pressed):   # l'escena ja la connecta
		back_button.pressed.connect(_on_back_pressed)
	# Opcions: el mateix panell que el menú de pausa (els panells antics queden amagats)
	for connexio in settings_button.pressed.get_connections():
		if connexio.callable.get_object() == menu:   # una connexió antiga a un mètode que no existeix
			settings_button.pressed.disconnect(connexio.callable)
	settings_button.pressed.connect(_obrir_opcions)
	_millorar_aspecte()
	video_button.pressed.connect(_navigate_to.bind(video_settings))
	audio_button.pressed.connect(_navigate_to.bind(audio_settings))
	controls_button.pressed.connect(_navigate_to.bind(controls_settings))
	language_button.pressed.connect(_navigate_to.bind(language_settings))
 
func _show_panel(panel: Control):
	panel.visible = true
 
func _update_back_button():
	back_button.visible = nav_stack.size() > 0
 
func _navigate_to(panel: Control):
	if current_panel:
		nav_stack.append(current_panel)
		current_panel.visible = false
 
	current_panel = panel
	_show_panel(current_panel)
	_update_back_button()
 
func _on_back_pressed():
	if nav_stack.is_empty():
		return
 
	current_panel.visible = false
	current_panel = nav_stack.pop_back()
	_show_panel(current_panel)
	_update_back_button()
	SettingsManager.save_settings()
 
 
func _on_quit_pressed():
	get_tree().quit()
 
 
func _on_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
	#pass # Replace with function body.

# ─────────────── Aspecte i opcions

func _millorar_aspecte():
	# Fons en degradat (de vermut a nit)
	var degradat := Gradient.new()
	degradat.set_color(0, Color(0.32, 0.08, 0.12))
	degradat.set_color(1, Color(0.05, 0.05, 0.14))
	var textura := GradientTexture2D.new()
	textura.gradient = degradat
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	var fons := TextureRect.new()
	fons.texture = textura
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	fons.stretch_mode = TextureRect.STRETCH_SCALE
	fons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fons)
	move_child(fons, 0)

	# Títol: el que ja hi ha a l'escena, amb un estil més vistós i una mica de moviment
	titol = get_node_or_null("Label") as Label
	if titol:
		titol.add_theme_font_size_override("font_size", 64)
		titol.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
		titol.add_theme_color_override("font_outline_color", Color(0.2, 0.03, 0.06))
		titol.add_theme_constant_override("outline_size", 14)
		titol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titol.offset_left = -300
		titol.offset_right = 300
		titol.offset_top = 90
		titol.offset_bottom = 180
		var t := create_tween().set_loops()
		t.tween_property(titol, "position:y", titol.position.y - 6.0, 1.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(titol, "position:y", titol.position.y, 1.6).set_trans(Tween.TRANS_SINE)

	# Botons amb l'estil comú, una mica més grans
	menu.theme = EstilMenus.tema()
	menu.offset_left = -130
	menu.offset_right = 130
	menu.offset_top = -40
	menu.offset_bottom = 160
	for boto in menu.find_children("*", "Button", true, false):
		boto.custom_minimum_size = Vector2(260, 48)
	var inicia := menu.find_child("Start", true, false) as Button
	if inicia:
		# Si ja hi ha una partida desada, és "Continuar"
		inicia.text = "Continuar" if FileAccess.file_exists("user://temps.save") else "Jugar"
		inicia.grab_focus()

	opcions = PanellOpcions.new()
	opcions.visible = false
	opcions.tancat.connect(_tancar_opcions)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.add_child(opcions)

func _obrir_opcions():
	menu.visible = false
	if titol:
		titol.visible = false
	opcions.visible = true

func _tancar_opcions():
	opcions.visible = false
	menu.visible = true
	if titol:
		titol.visible = true
	settings_button.grab_focus()
