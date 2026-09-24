extends CanvasLayer

@export var radi_roda: float = 100.0
@export var mida_icona: float = 64.0

var opcions: Array = []  # Array de {textura: Texture2D, nom: String}
var index_seleccionat: int = 0
var icones: Array[TextureRect] = []
var centre: Vector2 = Vector2.ZERO
var label_nom: Label

@onready var contenidor = $Control/ContenidorRoda

func obrir(llista_opcions: Array, index_inicial: int = 0):
	opcions = llista_opcions
	index_seleccionat = index_inicial
	visible = true
	_generar_icones()
	centre = get_viewport().get_visible_rect().size / 2.0  # centre real de la pantalla
	contenidor.position = centre
	if label_nom == null:
		label_nom = Label.new()
		label_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_nom.size = Vector2(260, 120)
		label_nom.add_theme_font_size_override("font_size", 14)
		label_nom.add_theme_color_override("font_outline_color", Color.BLACK)
		label_nom.add_theme_constant_override("outline_size", 6)
		label_nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenidor.add_child(label_nom)
	label_nom.position = Vector2(-130, radi_roda + mida_icona * 0.6)
	label_nom.visible = true

func tancar():
	visible = false
	for icona in icones:
		icona.queue_free()
	icones.clear()

func _generar_icones():
	for icona in icones:
		icona.queue_free()
	icones.clear()

	var angle_pas = 360.0 / opcions.size()
	for i in range(opcions.size()):
		var angle_rad = deg_to_rad(angle_pas * i - 90.0)
		var pos = Vector2(cos(angle_rad), sin(angle_rad)) * radi_roda

		var icona = TextureRect.new()
		contenidor.add_child(icona)  # primer afegir a l'arbre

		icona.texture = opcions[i]["textura"]
		icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icona.custom_minimum_size = Vector2(mida_icona, mida_icona)
		icona.size = Vector2(mida_icona, mida_icona)
		icona.pivot_offset = Vector2(mida_icona / 2, mida_icona / 2)
		icona.position = pos - Vector2(mida_icona / 2, mida_icona / 2)

		icones.append(icona)

	_actualitzar_seleccio()

func _process(_delta):
	if not visible or opcions.is_empty():
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var direccio = mouse_pos - centre

	if direccio.length() > 20.0:  # zona morta al centre
		var angle = rad_to_deg(direccio.angle()) + 90.0
		if angle < 0:
			angle += 360.0
		var angle_pas = 360.0 / opcions.size()
		index_seleccionat = int(round(angle / angle_pas)) % opcions.size()

	_actualitzar_seleccio()

func _actualitzar_seleccio():
	for i in range(icones.size()):
		var color: Color = opcions[i].get("color", Color.WHITE)
		if i == index_seleccionat:
			icones[i].scale = Vector2(1.3, 1.3)
			icones[i].modulate = color * Color(1.2, 1.2, 1.2)
		else:
			icones[i].scale = Vector2(1.0, 1.0)
			icones[i].modulate = color * Color(0.6, 0.6, 0.6)
	if label_nom and not opcions.is_empty():
		var opcio: Dictionary = opcions[index_seleccionat]
		label_nom.text = "%s\n%s" % [opcio.get("nom", ""), opcio.get("descripcio", "")]

func obtenir_seleccio() -> int:
	return index_seleccionat
