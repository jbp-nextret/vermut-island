extends CanvasLayer
class_name HudJoc
## A dalt a l'esquerra, la vida en cors de pixel art (cada cor = 10 de vida, amb mitjos cors).
## A dalt a la dreta, el rellotge: l'hora i el dia de la setmana.

const VIDA_PER_COR := 10
const MIDA_COR := Vector2(18, 16)
const DIES := ["Dilluns", "Dimarts", "Dimecres", "Dijous", "Divendres", "Dissabte", "Diumenge"]

var mostrar_rellotge := true

var fila_cors: HBoxContainer
var cors: Array[TextureRect] = []
var rellotge: Label
var dia: Label

static var _textures := {}

func _ready():
	fila_cors = HBoxContainer.new()
	fila_cors.add_theme_constant_override("separation", 1)
	fila_cors.position = Vector2(10, 8)
	fila_cors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila_cors)
	for i in int(ceil(float(SalutJugador.vida_maxima) / VIDA_PER_COR)):
		var cor := TextureRect.new()
		cor.custom_minimum_size = MIDA_COR
		cor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cor.pivot_offset = MIDA_COR / 2.0
		cor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila_cors.add_child(cor)
		cors.append(cor)

	rellotge = _label(18, Color(1, 0.95, 0.8))
	rellotge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(rellotge)
	rellotge.anchor_left = 1.0
	rellotge.anchor_right = 1.0
	rellotge.offset_left = -160
	rellotge.offset_right = -10
	rellotge.offset_top = 4
	dia = _label(11, Color(0.8, 0.88, 1.0))
	dia.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(dia)
	dia.anchor_left = 1.0
	dia.anchor_right = 1.0
	dia.offset_left = -160
	dia.offset_right = -10
	dia.offset_top = 26
	rellotge.visible = mostrar_rellotge
	dia.visible = mostrar_rellotge

	SalutJugador.vida_canviat.connect(_on_vida_canviat)
	_pintar_cors(SalutJugador.vida_actual)

var vida_anterior := -1

func _on_vida_canviat(actual, _maxima):
	if vida_anterior >= 0 and actual < vida_anterior:
		# Els cors tremolen quan et fan mal
		var t := create_tween()
		for x in [-3.0, 3.0, -2.0, 0.0]:
			t.tween_property(fila_cors, "position:x", 10 + x, 0.04)
	_pintar_cors(actual)

func _pintar_cors(vida: int):
	vida_anterior = vida
	for i in cors.size():
		var resta := vida - i * VIDA_PER_COR
		var tipus := "ple" if resta >= VIDA_PER_COR else ("mig" if resta >= VIDA_PER_COR / 2 else "buit")
		cors[i].texture = textura_cor(tipus)

func _process(_delta):
	# Amb poca vida, l'últim cor batega
	var vida: int = SalutJugador.vida_actual
	var ultim := clampi(int(ceil(float(vida) / VIDA_PER_COR)) - 1, 0, cors.size() - 1)
	for i in cors.size():
		var s := 1.0
		if vida <= SalutJugador.vida_maxima * 0.25 and i == ultim:
			s = 1.0 + 0.15 * absf(sin(Time.get_ticks_msec() * 0.008))
		cors[i].scale = Vector2.ONE * s

	if mostrar_rellotge:
		var h: float = GestorTemps.hora_actual
		var icona := "🌙" if h < 6.0 or h >= 20.0 else ("🌅" if h < 9.0 else ("☀" if h < 18.0 else "🌇"))
		rellotge.text = "%s %02d:%02d" % [icona, int(h), int((h - int(h)) * 60)]
		var d: int = GestorTemps.dia_actual
		dia.text = "%s · Setmana %d" % [DIES[posmod(d - 1, 7)], (d - 1) / 7 + 1]

## Cor de 9x8 en pixel art: "ple", "mig" o "buit"
static func textura_cor(tipus: String) -> ImageTexture:
	if _textures.has(tipus):
		return _textures[tipus]
	const DIBUIX := [
		".oo...oo.",
		"orro.orro",
		"orwrorrro",
		"orrrrrrro",
		".orrrrro.",
		"..orrro..",
		"...oro...",
		"....o....",
	]
	var vora := Color(0.18, 0.05, 0.08)
	var vermell := Color(0.9, 0.15, 0.2)
	var brillantor := Color(1, 0.75, 0.75)
	var buit := Color(0.25, 0.2, 0.25)
	var img := Image.create(9, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 9:
			var ch: String = DIBUIX[y][x]
			var col := Color(0, 0, 0, 0)
			if ch == "o":
				col = vora
			elif ch == "r" or ch == "w":
				var plena := tipus == "ple" or (tipus == "mig" and x <= 4)
				col = (brillantor if ch == "w" else vermell) if plena else buit
			img.set_pixel(x, y, col)
	_textures[tipus] = ImageTexture.create_from_image(img)
	return _textures[tipus]

func _label(mida: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l
