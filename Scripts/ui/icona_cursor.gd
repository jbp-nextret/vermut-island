extends CanvasLayer
class_name IconaCursor
## L'eina que portes a la mà, petita al costat del punter del ratolí (a l'exterior).
## Es pot amagar a Opcions › Textos a la pantalla.

const DESPLACAMENT := Vector2(16, 14)

var icona: Label

func _ready():
	layer = 40
	icona = Label.new()
	icona.add_theme_font_size_override("font_size", 24)
	icona.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	icona.add_theme_constant_override("outline_size", 6)
	icona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icona)

func _process(_delta):
	var eina := BarraRapida.eina_activa()
	var veure: bool = not eina.is_empty() and not get_tree().paused \
			and SettingsManager.valor("eina_al_cursor") \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and get_viewport().gui_get_hovered_control() == null
	icona.visible = veure
	if veure:
		icona.text = BarraRapida.info(eina).icona
		icona.position = get_viewport().get_mouse_position() + DESPLACAMENT
