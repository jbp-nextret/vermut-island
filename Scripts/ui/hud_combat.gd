extends CanvasLayer
class_name HudCombat
## Icones de combat a baix a l'esquerra:
##  - espasa: il·luminada quan el mode combat està actiu
##  - màgia: un anell que s'omple mentre es recarrega i "batega" quan està a punt

var jugador: Node
var icona_espasa: IconaCombat
var icona_magia: IconaCombat
var estava_a_punt := true

func _ready():
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	add_child(caixa)
	caixa.anchor_top = 1.0
	caixa.anchor_bottom = 1.0
	caixa.offset_left = 12
	caixa.offset_top = -58
	caixa.offset_bottom = -12
	caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN

	icona_espasa = IconaCombat.new("🗡", _tecla("mode_combat"), Color(0.8, 0.9, 1.0))
	icona_magia = IconaCombat.new("🔥", _tecla("atac_magia"), Color(1.0, 0.55, 0.15))
	caixa.add_child(icona_espasa)
	caixa.add_child(icona_magia)

	if jugador and jugador.has_signal("magia_no_disponible"):
		jugador.magia_no_disponible.connect(func(): icona_magia.sacsejar())

func _process(_delta):
	if not is_instance_valid(jugador):
		return
	visible = GameState.pot_atacar()
	icona_espasa.activa = jugador.estat == 1   # Estat.COMBAT
	icona_espasa.progres = 1.0
	var progres: float = jugador.progres_magia()
	icona_magia.progres = progres
	icona_magia.activa = progres >= 1.0
	if progres >= 1.0 and not estava_a_punt:
		icona_magia.bategar()   # s'acaba de recarregar
	estava_a_punt = progres >= 1.0
	icona_espasa.queue_redraw()
	icona_magia.queue_redraw()

func _tecla(accio: String) -> String:
	for ev in InputMap.action_get_events(accio):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
	return ""


class IconaCombat extends Control:
	const RADI := 18.0
	var simbol: String
	var tecla: String
	var color: Color
	var progres := 1.0
	var activa := true
	var label: Label

	func _init(p_simbol: String, p_tecla: String, p_color: Color):
		simbol = p_simbol
		tecla = p_tecla
		color = p_color
		custom_minimum_size = Vector2(RADI * 2 + 4, RADI * 2 + 12)
		pivot_offset = Vector2(RADI + 2, RADI + 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready():
		label = Label.new()
		label.text = simbol
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(RADI * 2 + 4, RADI * 2 + 4)
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)

	func _draw():
		var centre := Vector2(RADI + 2, RADI + 2)
		draw_circle(centre, RADI, Color(0, 0, 0, 0.55))
		var c := color if activa else color.darkened(0.55)
		if progres < 1.0:
			# Recarregant: l'anell s'omple en sentit horari des de dalt
			draw_arc(centre, RADI - 2, -PI / 2, -PI / 2 + TAU * progres, 32, c, 3.0)
		else:
			draw_arc(centre, RADI - 2, 0, TAU, 32, c, 3.0)
		label.modulate = Color.WHITE if activa else Color(1, 1, 1, 0.45)
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, RADI * 2 + 12), tecla, HORIZONTAL_ALIGNMENT_CENTER, RADI * 2 + 4, 10, Color(1, 1, 1, 0.8))

	func bategar():
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE * 1.25, 0.08)
		t.tween_property(self, "scale", Vector2.ONE, 0.15)

	## Has premut la màgia abans d'hora
	func sacsejar():
		# (rotació i no posició: el contenidor recol·loca les icones)
		var t := create_tween()
		for angle in [-0.25, 0.25, -0.12, 0.0]:
			t.tween_property(self, "rotation", angle, 0.04)
