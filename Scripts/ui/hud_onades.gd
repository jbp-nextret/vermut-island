extends CanvasLayer
class_name HudOnades
## Estat de l'onada a dalt al centre, i cartells grans quan comença o acaba.

var label_estat: Label
var cartell: Label
var tween_cartell: Tween

func _ready():
	label_estat = _crear_label(20)
	label_estat.anchor_right = 1.0
	label_estat.offset_top = 10
	add_child(label_estat)

	cartell = _crear_label(34)
	cartell.set_anchors_preset(Control.PRESET_FULL_RECT)
	cartell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cartell.modulate.a = 0.0
	add_child(cartell)

	GestorOnades.onada_comencada.connect(_on_onada_comencada)
	GestorOnades.nit_lliure.connect(_on_nit_lliure)
	GestorOnades.onada_acabada.connect(_on_onada_acabada)

func _crear_label(mida: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l

func _process(_delta):
	label_estat.text = GestorOnades.estat_text()

func _on_onada_comencada(info: Dictionary):
	var dificultat: String = ["fàcil", "tranquil·la", "moguda", "dura", "molt dura"][info.numero - 1]
	_mostrar_cartell("Onada del %s\n%d enemics · una nit %s" % [info.dia, info.total, dificultat], Color(1, 0.6, 0.5))

func _on_nit_lliure(info: Dictionary):
	_mostrar_cartell("Nit de %s\nAvui no ataca ningú: aprofita per preparar-te!" % info.dia, Color(0.7, 0.9, 1))

func _on_onada_acabada(resum: Dictionary):
	var titol := "Onada superada!" if resum.superada else "Ha sortit el sol"
	var text := "%s\n%d/%d enemics derrotats" % [titol, resum.morts, resum.total]
	if resum.cultius_perduts > 0:
		text += " · %d cultius perduts" % resum.cultius_perduts
	if resum.diners > 0:
		text += "\n+%d 🪙" % resum.diners
	_mostrar_cartell(text, Color(1, 0.9, 0.5) if resum.superada else Color(0.9, 0.9, 0.9))

func _mostrar_cartell(text: String, color: Color):
	cartell.text = text
	cartell.add_theme_color_override("font_color", color)
	if tween_cartell:
		tween_cartell.kill()
	tween_cartell = create_tween()
	tween_cartell.tween_property(cartell, "modulate:a", 1.0, 0.4)
	tween_cartell.tween_interval(3.0)
	tween_cartell.tween_property(cartell, "modulate:a", 0.0, 0.8)
