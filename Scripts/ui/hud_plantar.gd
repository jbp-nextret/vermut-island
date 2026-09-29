extends CanvasLayer
class_name HudPlantar
## A baix a la dreta: el cultiu triat, les llavors que tens i la tecla P.
## En mode plantar s'il·lumina i mostra com plantar; els avisos surten a sobre.

var plantador: Plantador

var panell: PanelContainer
var icona: TextureRect
var label_nom: Label
var label_llavors: Label
var label_ajuda: Label
var label_avis: Label
var tween_avis: Tween
var tira: HBoxContainer
var tira_icones: Array[TextureRect] = []
var tira_nom: Label
var caixa_tira: VBoxContainer
var tween_tira: Tween

func _ready():
	panell = PanelContainer.new()
	panell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panell)
	panell.anchor_left = 1.0
	panell.anchor_right = 1.0
	panell.anchor_top = 1.0
	panell.anchor_bottom = 1.0
	panell.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panell.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panell.offset_right = -8
	panell.offset_bottom = -8

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	panell.add_child(fila)

	icona = TextureRect.new()
	icona.custom_minimum_size = Vector2(30, 30)
	icona.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icona.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icona.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fila.add_child(icona)

	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	fila.add_child(textos)
	label_nom = _label(11, Color.WHITE)
	textos.add_child(label_nom)
	label_llavors = _label(10, Color(0.8, 1.0, 0.75))
	textos.add_child(label_llavors)

	label_ajuda = _label(9, Color(0.9, 0.9, 0.9))
	label_ajuda.text = "Clic: plantar · Arrossega: àrea · Q/E: canviar · Clic dret: sortir"
	label_ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label_ajuda)
	label_ajuda.anchor_left = 0.0
	label_ajuda.anchor_right = 1.0
	label_ajuda.anchor_top = 1.0
	label_ajuda.anchor_bottom = 1.0
	label_ajuda.offset_right = -10
	label_ajuda.offset_top = -64
	label_ajuda.offset_bottom = -50

	label_avis = _label(11, Color(1, 0.55, 0.5))
	label_avis.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label_avis)
	label_avis.anchor_right = 1.0
	label_avis.anchor_top = 1.0
	label_avis.anchor_bottom = 1.0
	label_avis.offset_right = -10
	label_avis.offset_top = -80
	label_avis.offset_bottom = -64
	label_avis.modulate.a = 0.0

	_crear_tira()
	plantador.canviat_amb_tecla.connect(_mostrar_tira)
	plantador.seleccio_canviada.connect(func(_i): _actualitzar())
	plantador.mode_canviat.connect(func(_a): _actualitzar())
	plantador.avis.connect(_mostrar_avis)
	_actualitzar()

func _process(_delta):
	visible = GameState.pot_atacar()   # només a fora (no dins de casa ni construint)
	# L'ajuda s'amaga mentre es veu la tira del canvi de cultiu
	label_ajuda.visible = plantador.actiu and not plantador.roda_oberta and caixa_tira.modulate.a < 0.05

func _actualitzar():
	var o: Dictionary = plantador.opcio()
	icona.texture = o.textura
	icona.modulate = o.color
	label_nom.text = "%s %s" % [o.insignia, o.nom]
	var llavors := plantador.llavors()
	label_llavors.text = "🌱 %d   [P]" % llavors
	label_llavors.add_theme_color_override("font_color", Color(0.8, 1.0, 0.75) if llavors > 0 else Color(1, 0.5, 0.45))
	var actiu := plantador.actiu
	panell.add_theme_stylebox_override("panel", _estil(actiu, o.color))
	label_ajuda.visible = actiu

## Tira a baix al centre en canviar amb Q/E: [anterior] [ACTUAL] [següent] i el nom
func _crear_tira():
	caixa_tira = VBoxContainer.new()
	caixa_tira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_tira.alignment = BoxContainer.ALIGNMENT_END
	add_child(caixa_tira)
	caixa_tira.anchor_left = 0.5
	caixa_tira.anchor_right = 0.5
	caixa_tira.anchor_top = 1.0
	caixa_tira.anchor_bottom = 1.0
	caixa_tira.offset_left = -120
	caixa_tira.offset_right = 120
	caixa_tira.offset_top = -124
	caixa_tira.offset_bottom = -70
	caixa_tira.modulate.a = 0.0

	tira = HBoxContainer.new()
	tira.alignment = BoxContainer.ALIGNMENT_CENTER
	tira.add_theme_constant_override("separation", 6)
	caixa_tira.add_child(tira)
	for i in 3:
		var fons := PanelContainer.new()
		fons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tira.add_child(fons)
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(34, 34) if i == 1 else Vector2(22, 22)
		fons.add_child(t)
		tira_icones.append(t)

	tira_nom = _label(13, Color.WHITE)
	tira_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa_tira.add_child(tira_nom)

func _mostrar_tira(index: int, direccio: int):
	var n := plantador.opcions.size()
	for i in 3:
		var o: Dictionary = plantador.opcions[posmod(index + i - 1, n)]
		tira_icones[i].texture = o.textura
		tira_icones[i].modulate = o.color if i == 1 else Color(o.color, 0.55)
		tira_icones[i].get_parent().add_theme_stylebox_override("panel", _estil(i == 1, o.color))
	var actual: Dictionary = plantador.opcions[index]
	tira_nom.text = "%s %s" % [actual.insignia, actual.nom]
	tira_nom.add_theme_color_override("font_color", Color(actual.color).lerp(Color.WHITE, 0.5))

	# Entra lliscant des del costat cap on has canviat i s'esvaeix al cap d'una estona
	if tween_tira:
		tween_tira.kill()
	caixa_tira.modulate.a = 1.0
	tira.position.x = 14.0 * direccio
	tween_tira = create_tween()
	tween_tira.tween_property(tira, "position:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_tira.tween_interval(0.9)
	tween_tira.tween_property(caixa_tira, "modulate:a", 0.0, 0.35)

	# I el panell de baix a la dreta fa un bot
	panell.pivot_offset = panell.size / 2.0
	var bot := create_tween()
	bot.tween_property(panell, "scale", Vector2.ONE * 1.12, 0.06)
	bot.tween_property(panell, "scale", Vector2.ONE, 0.12)

func _mostrar_avis(text: String):
	label_avis.text = text
	if tween_avis:
		tween_avis.kill()
	label_avis.modulate.a = 1.0
	tween_avis = create_tween()
	tween_avis.tween_interval(1.2)
	tween_avis.tween_property(label_avis, "modulate:a", 0.0, 0.4)

func _estil(actiu: bool, color: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0.05, 0.06, 0.1, 0.7)
	e.set_corner_radius_all(6)
	e.set_content_margin_all(5)
	e.set_border_width_all(2 if actiu else 0)
	e.border_color = Color(color, 0.9)
	return e

func _label(mida: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
