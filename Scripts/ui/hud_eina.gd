extends CanvasLayer
class_name HudEina
## Icona d'una eina màgica (rec, llaurar...) a sobre de les de combat. En el seu mode
## s'il·lumina, mostra la recàrrega i les instruccions; els avisos surten al costat.
## L'eina ha de tenir: `actiu`, `progres()` i el senyal `avis(text)`.

var eina: Node
var icona: HudCombat.IconaCombat
var label_ajuda: Label
var label_avis: Label
var tween_avis: Tween
var estava_a_punt := true
var _accio: String
var _simbol: String
var _color: Color
var _ajuda: String
var _fila: int

## `fila`: 0 just a sobre de les icones de combat, 1 a sobre d'aquesta, etc.
func configurar(p_eina: Node, accio: String, simbol: String, color: Color, ajuda: String, fila: int) -> void:
	eina = p_eina
	_accio = accio
	_simbol = simbol
	_color = color
	_ajuda = ajuda
	_fila = fila

func _ready():
	var tecla := ""
	for ev in InputMap.action_get_events(_accio):
		if ev is InputEventKey:
			tecla = ev.as_text_physical_keycode()
	var dalt := -108 - _fila * 48
	icona = HudCombat.IconaCombat.new(_simbol, tecla, _color)
	add_child(icona)
	icona.anchor_top = 1.0
	icona.anchor_bottom = 1.0
	icona.offset_left = 12
	icona.offset_top = dalt
	icona.offset_bottom = dalt + 48

	label_ajuda = _label(Color(_color).lerp(Color.WHITE, 0.6))
	label_ajuda.text = _ajuda
	add_child(label_ajuda)
	label_ajuda.anchor_top = 1.0
	label_ajuda.anchor_bottom = 1.0
	label_ajuda.offset_left = 56
	label_ajuda.offset_top = dalt + 12
	label_ajuda.offset_bottom = dalt + 26

	label_avis = _label(Color(1, 0.55, 0.5))
	add_child(label_avis)
	label_avis.anchor_top = 1.0
	label_avis.anchor_bottom = 1.0
	label_avis.offset_left = 56
	label_avis.offset_top = dalt + 26
	label_avis.offset_bottom = dalt + 40
	label_avis.modulate.a = 0.0

	eina.avis.connect(_mostrar_avis)

func _process(_delta):
	visible = GameState.pot_atacar()
	icona.activa = eina.actiu
	icona.progres = eina.progres()
	var a_punt := icona.progres >= 1.0
	if a_punt and not estava_a_punt and eina.actiu:
		icona.bategar()
	estava_a_punt = a_punt
	label_ajuda.visible = eina.actiu
	icona.queue_redraw()

func _mostrar_avis(text: String):
	label_avis.text = text
	if tween_avis:
		tween_avis.kill()
	label_avis.modulate.a = 1.0
	tween_avis = create_tween()
	tween_avis.tween_interval(1.0)
	tween_avis.tween_property(label_avis, "modulate:a", 0.0, 0.4)

func _label(color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
