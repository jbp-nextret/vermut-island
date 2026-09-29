extends Control
class_name IconaAccio
## Botó rodó de la barra d'accions: un símbol, la tecla a sota i un anell que s'omple
## mentre es recarrega. Es pot clicar amb el ratolí (senyal `clicat`).

signal clicat
signal ratoli_a_sobre(sobre: bool)

const RADI := 18.0

var simbol: String
var tecla: String
var color: Color
var nom: String
var progres := 1.0
var activa := true
var label: Label
var sobre := false

func _init(p_simbol: String, p_tecla: String, p_color: Color, p_nom: String = ""):
	simbol = p_simbol
	tecla = p_tecla
	color = p_color
	nom = p_nom
	custom_minimum_size = Vector2(RADI * 2 + 4, RADI * 2 + 12)
	pivot_offset = Vector2(RADI + 2, RADI + 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready():
	label = Label.new()
	label.text = simbol
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(RADI * 2 + 4, RADI * 2 + 4)
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	mouse_entered.connect(_canviar_sobre.bind(true))
	mouse_exited.connect(_canviar_sobre.bind(false))

func _canviar_sobre(valor: bool):
	sobre = valor
	ratoli_a_sobre.emit(valor)
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicat.emit()
		bategar()
		accept_event()

func _draw():
	var centre := Vector2(RADI + 2, RADI + 2)
	draw_circle(centre, RADI, Color(0, 0, 0, 0.7 if sobre else 0.55))
	var c := color if activa else color.darkened(0.55)
	if progres < 1.0:
		draw_arc(centre, RADI - 2, -PI / 2, -PI / 2 + TAU * progres, 32, c, 3.0)
	else:
		draw_arc(centre, RADI - 2, 0, TAU, 32, c, 3.0 if not sobre else 4.0)
	label.modulate = Color.WHITE if activa or sobre else Color(1, 1, 1, 0.5)
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, RADI * 2 + 12), tecla, HORIZONTAL_ALIGNMENT_CENTER, RADI * 2 + 4, 10, Color(1, 1, 1, 0.85))

func bategar():
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 1.2, 0.07)
	t.tween_property(self, "scale", Vector2.ONE, 0.14)

## S'ha premut abans d'hora
func sacsejar():
	var t := create_tween()
	for angle in [-0.25, 0.25, -0.12, 0.0]:
		t.tween_property(self, "rotation", angle, 0.04)
