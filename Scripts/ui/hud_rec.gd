extends CanvasLayer
class_name HudRec
## Icona del rec (💧 i la seva tecla) a sobre de les de combat. En mode regar
## s'il·lumina, mostra la recàrrega i les instruccions; els avisos surten al costat.

var regador: Regador
var icona: HudCombat.IconaCombat
var label_ajuda: Label
var label_avis: Label
var tween_avis: Tween
var estava_a_punt := true

func _ready():
	var tecla := ""
	for ev in InputMap.action_get_events("regar"):
		if ev is InputEventKey:
			tecla = ev.as_text_physical_keycode()
	icona = HudCombat.IconaCombat.new("💧", tecla, Color(0.45, 0.75, 1.0))
	add_child(icona)
	icona.anchor_top = 1.0
	icona.anchor_bottom = 1.0
	icona.offset_left = 12
	icona.offset_top = -108
	icona.offset_bottom = -60

	label_ajuda = _label(Color(0.85, 0.95, 1.0))
	label_ajuda.text = "Clic: regar · Clic dret: sortir"
	add_child(label_ajuda)
	label_ajuda.anchor_top = 1.0
	label_ajuda.anchor_bottom = 1.0
	label_ajuda.offset_left = 56
	label_ajuda.offset_top = -96
	label_ajuda.offset_bottom = -82

	label_avis = _label(Color(1, 0.55, 0.5))
	add_child(label_avis)
	label_avis.anchor_top = 1.0
	label_avis.anchor_bottom = 1.0
	label_avis.offset_left = 56
	label_avis.offset_top = -82
	label_avis.offset_bottom = -68
	label_avis.modulate.a = 0.0

	regador.avis.connect(_mostrar_avis)

func _process(_delta):
	visible = GameState.pot_atacar()
	icona.activa = regador.actiu
	icona.progres = regador.progres()
	var a_punt := icona.progres >= 1.0
	if a_punt and not estava_a_punt and regador.actiu:
		icona.bategar()
	estava_a_punt = a_punt
	label_ajuda.visible = regador.actiu
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
