extends Control
class_name CasellaBarra
## Una casella de la barra ràpida (o una "font" per arrossegar-hi: una eina o un objecte).
##   - index >= 0: és la casella `index` de BarraRapida (s'hi pot deixar anar)
##   - index == -1: és una font amb `id` (només s'arrossega)
## Clic: senyal `clicada`. Clic dret (si `es_pot_buidar`): la buida.
## Arrossegar d'una casella a una altra les intercanvia.

signal clicada(index: int)
signal ratoli_a_sobre(sobre: bool, nom: String)

const MIDA := 46.0

var index := -1
var id := ""
var seleccionada := false
var progres := 1.0
var es_pot_buidar := false
var sobre := false

var icona: Label
var quantitat: Label

func _init(p_index := -1, p_id := ""):
	index = p_index
	id = p_id
	custom_minimum_size = Vector2(MIDA, MIDA)
	pivot_offset = Vector2(MIDA, MIDA) / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready():
	icona = Label.new()
	icona.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icona.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icona.size = Vector2(MIDA, MIDA)
	icona.add_theme_font_size_override("font_size", 22)
	icona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icona)
	quantitat = Label.new()
	quantitat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantitat.position = Vector2(0, MIDA - 18)
	quantitat.size = Vector2(MIDA - 3, 16)
	quantitat.add_theme_font_size_override("font_size", 11)
	quantitat.add_theme_color_override("font_outline_color", Color.BLACK)
	quantitat.add_theme_constant_override("outline_size", 4)
	quantitat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quantitat)
	mouse_entered.connect(func():
		sobre = true
		ratoli_a_sobre.emit(true, _nom())
		queue_redraw())
	mouse_exited.connect(func():
		sobre = false
		ratoli_a_sobre.emit(false, _nom())
		queue_redraw())
	actualitzar()

func contingut() -> String:
	return BarraRapida.caselles[index] if index >= 0 else id

func _nom() -> String:
	var c := contingut()
	return "" if c.is_empty() else BarraRapida.info(c).nom

func actualitzar():
	var c := contingut()
	icona.text = "" if c.is_empty() else BarraRapida.info(c).icona
	quantitat.text = str(Inventari.tenir(c)) if c in BarraRapida.OBJECTES_US else ""
	icona.modulate = Color.WHITE if c.is_empty() or BarraRapida.disponible(c) else Color(1, 1, 1, 0.35)
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicada.emit(index)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and es_pot_buidar and index >= 0:
			BarraRapida.buidar(index)
			accept_event()

# ─────────────── Arrossegar i deixar anar

func _get_drag_data(_posicio):
	var c := contingut()
	if c.is_empty():
		return null
	var vista := Label.new()
	vista.text = BarraRapida.info(c).icona
	vista.add_theme_font_size_override("font_size", 28)
	set_drag_preview(vista)
	return {"barra_rapida": c, "des_de": index}

func _can_drop_data(_posicio, dades) -> bool:
	return index >= 0 and dades is Dictionary and dades.has("barra_rapida")

func _drop_data(_posicio, dades):
	if dades.des_de >= 0:
		BarraRapida.intercanviar(dades.des_de, index)
	else:
		BarraRapida.assignar(index, dades.barra_rapida)

# ─────────────── Dibuix

func _draw():
	var r := Rect2(Vector2.ZERO, size)
	var fons := StyleBoxFlat.new()
	fons.bg_color = Color(0.05, 0.05, 0.09, 0.78 if sobre else 0.62)
	fons.set_corner_radius_all(7)
	fons.set_border_width_all(3 if seleccionada else 1)
	var c := contingut()
	var color: Color = BarraRapida.info(c).color if not c.is_empty() else Color(1, 1, 1)
	fons.border_color = Color(1.0, 0.85, 0.35) if seleccionada else Color(color, 0.35 if not sobre else 0.7)
	draw_style_box(fons, r)
	if progres < 1.0:
		draw_rect(Rect2(4, size.y - 6, (size.x - 8) * progres, 3), color)
	if index >= 0:
		var font := get_theme_default_font()
		draw_string_outline(font, Vector2(4, 13), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(font, Vector2(4, 13), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))

func bategar():
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 1.15, 0.07)
	t.tween_property(self, "scale", Vector2.ONE, 0.14)

func sacsejar():
	var t := create_tween()
	for angle in [-0.2, 0.2, -0.1, 0.0]:
		t.tween_property(self, "rotation", angle, 0.04)
