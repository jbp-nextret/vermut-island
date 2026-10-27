extends CanvasLayer
## Roda per triar el cultiu (mantenint la P). Cada opció mostra la seva icona i una
## insígnia del tipus; al centre, el nom i el tipus, i a sota la informació i les llavors.

@export var radi_roda: float = 78.0
@export var mida_icona: float = 44.0

const LLAVOR := "llavor_raim"

var opcions: Array = []
var index_seleccionat: int = 0
var elements: Array = []        # [{fons, icona, insignia}]
var centre: Vector2 = Vector2.ZERO

var fons_roda: Panel
var label_nom: Label
var label_tipus: Label
var panell_info: PanelContainer
var label_info: Label

@onready var contenidor = $Control/ContenidorRoda

func _ready():
	visible = false

func obrir(llista_opcions: Array, index_inicial: int = 0):
	opcions = llista_opcions
	index_seleccionat = index_inicial
	visible = true
	# Una mica per sobre del centre, perquè la informació de sota hi càpiga
	centre = get_viewport().get_visible_rect().size / 2.0 + Vector2(0, -40)
	contenidor.position = centre
	if fons_roda == null:
		_crear_interficie()
	_generar_opcions()
	_actualitzar_seleccio()

func tancar():
	visible = false

func obtenir_seleccio() -> int:
	return index_seleccionat

# ─────────────── Construcció

func _crear_interficie():
	# Cercle fosc de fons
	fons_roda = Panel.new()
	var diametre := (radi_roda + mida_icona * 0.8) * 2.0
	fons_roda.size = Vector2(diametre, diametre)
	fons_roda.position = -fons_roda.size / 2.0
	fons_roda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fons_roda.add_theme_stylebox_override("panel", _estil(Color(0.05, 0.06, 0.1, 0.72), int(diametre / 2.0), 0, Color.TRANSPARENT))
	contenidor.add_child(fons_roda)

	# Nom i tipus, al centre
	label_nom = _label(13, Color.WHITE)
	label_nom.size = Vector2(120, 18)
	label_nom.position = Vector2(-60, -16)
	contenidor.add_child(label_nom)
	label_tipus = _label(10, Color(0.8, 0.85, 1.0))
	label_tipus.size = Vector2(120, 14)
	label_tipus.position = Vector2(-60, 3)
	contenidor.add_child(label_tipus)

	# Informació a sota de la roda
	panell_info = PanelContainer.new()
	panell_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panell_info.add_theme_stylebox_override("panel", _estil(Color(0.05, 0.06, 0.1, 0.8), 6, 0, Color.TRANSPARENT, 6))
	contenidor.add_child(panell_info)
	label_info = _label(9, Color(0.92, 0.92, 0.92))
	label_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_info.custom_minimum_size = Vector2(340, 0)
	panell_info.add_child(label_info)

func _generar_opcions():
	for e in elements:
		e.fons.queue_free()
	elements.clear()
	var pas := TAU / opcions.size()
	for i in opcions.size():
		var angle := pas * i - PI / 2.0
		var pos := Vector2(cos(angle), sin(angle)) * radi_roda

		var fons := Panel.new()
		fons.size = Vector2(mida_icona, mida_icona)
		fons.pivot_offset = fons.size / 2.0
		fons.position = pos - fons.size / 2.0
		fons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenidor.add_child(fons)

		var icona := TextureRect.new()
		icona.texture = opcions[i].textura
		icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icona.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icona.size = fons.size * 0.8
		icona.position = fons.size * 0.1
		icona.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fons.add_child(icona)

		var insignia := _label(12, Color.WHITE)
		insignia.text = opcions[i].insignia
		insignia.size = Vector2(18, 18)
		insignia.position = Vector2(mida_icona - 16, -4)
		fons.add_child(insignia)

		elements.append({"fons": fons, "icona": icona, "insignia": insignia})

# ─────────────── Selecció

func _process(_delta):
	if not visible or opcions.is_empty():
		return
	var direccio: Vector2 = get_viewport().get_mouse_position() - centre
	if direccio.length() > 20.0:   # zona morta al centre
		var angle := fposmod(direccio.angle() + PI / 2.0, TAU)
		var pas := TAU / opcions.size()
		var nou := int(round(angle / pas)) % opcions.size()
		if nou != index_seleccionat:
			index_seleccionat = nou
			_actualitzar_seleccio()

func _actualitzar_seleccio():
	var llavors := Inventari.tenir(LLAVOR)
	for i in elements.size():
		var e: Dictionary = elements[i]
		var o: Dictionary = opcions[i]
		var triat := i == index_seleccionat
		var color: Color = o.color
		e.fons.scale = Vector2.ONE * (1.2 if triat else 1.0)
		e.fons.add_theme_stylebox_override("panel", _estil(
			Color(color, 0.4) if triat else Color(1, 1, 1, 0.14),
			int(mida_icona / 2.0), 2 if triat else 0, Color(color, 0.95)))
		var apagat: bool = llavors <= 0 or not CatalegCultius.desbloquejat(i)
		e.icona.modulate = (color if not apagat else Color(0.4, 0.4, 0.4)) * (Color(1.2, 1.2, 1.2) if triat else Color(0.9, 0.9, 0.9))

	var o: Dictionary = opcions[index_seleccionat]
	label_nom.text = o.nom
	label_nom.add_theme_color_override("font_color", Color(o.color).lerp(Color.WHITE, 0.5))
	label_tipus.text = "%s %s" % [o.insignia, o.tipus_nom]
	var text_llavors := "🌱 Llavors: %d  (1 per cultiu)" % llavors if llavors > 0 else "🌱 No tens llavors: cull raïm per aconseguir-ne"
	if not CatalegCultius.desbloquejat(index_seleccionat):
		text_llavors = CatalegCultius.text_bloqueig(index_seleccionat)
	label_info.text = "%s\n%s\n%s" % [o.descripcio, o.estadistiques, text_llavors]
	panell_info.reset_size()
	panell_info.position = Vector2(-panell_info.size.x / 2.0, radi_roda + mida_icona * 0.8 + 6)

# ─────────────── Utilitats

func _label(mida: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _estil(color: Color, radi: int, vora: int, color_vora: Color, marge: int = 0) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.set_corner_radius_all(radi)
	e.set_border_width_all(vora)
	e.border_color = color_vora
	e.set_content_margin_all(marge)
	return e
