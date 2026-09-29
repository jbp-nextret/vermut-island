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
	label_ajuda.text = "Clic: plantar · Arrossega: en fila · Mantén P: triar · Clic dret: sortir"
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

	plantador.seleccio_canviada.connect(func(_i): _actualitzar())
	plantador.mode_canviat.connect(func(_a): _actualitzar())
	plantador.avis.connect(_mostrar_avis)
	_actualitzar()

func _process(_delta):
	visible = GameState.pot_atacar()   # només a fora (no dins de casa ni construint)
	label_ajuda.visible = plantador.actiu and not plantador.roda_oberta

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
