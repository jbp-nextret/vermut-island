extends CanvasLayer
class_name MenuDormir
## Dormir al llit: tries fins a quina hora i el temps avança de cop (amb una fosa a negre).
## No es pot dormir amb enemics a l'illa ni saltar-se una nit d'onada que encara no has
## defensat. Si dorms fins al matí, et despertes amb tota la vida i el mana.

const OPCIONS := [
	["🌅 Fins al matí", 8.0],
	["☀️ Fins al migdia", 13.0],
	["🌇 Fins a la tarda", 17.0],
	["🌙 Fins al vespre", 20.0],
	["🛌 Tota la nit (fins demà a les 6:00)", 6.0],
]

var llit: Node3D
var fos: ColorRect
var text_fos: Label

static func obrir(p_llit: Node3D) -> MenuDormir:
	var m := MenuDormir.new()
	m.llit = p_llit
	p_llit.get_tree().root.add_child(m)
	return m

## Per què no es pot dormir fins a `hora` ("" si es pot)
static func motiu_no_dormir(hora: float) -> String:
	if GestorOnades.activa:
		return "Hi ha enemics a l'illa!"
	var ara := GestorTemps.hora_actual
	if is_equal_approx(hora, ara):
		return "Ja és aquesta hora"
	# Passa una nit si ja és de nit o si l'hora triada és l'endemà
	var passa_nit := GestorTemps.es_nit() or hora < ara
	if passa_nit:
		var dia := GestorOnades.dia_de_la_nit() if GestorTemps.es_nit() else int(GestorTemps.dia_actual)
		if GestorOnades.hi_ha_onada(dia) and GestorOnades.dia_onada != dia:
			return "Aquesta nit hi ha onada: defensa l'hort abans de dormir"
	return ""

## Quantes hores dormiràs
static func hores_fins(hora: float) -> float:
	var h := hora - GestorTemps.hora_actual
	return h if h > 0.0 else h + 24.0

func _ready():
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var fons := ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.55)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var caixa := PanelContainer.new()
	caixa.theme = EstilMenus.tema()
	caixa.add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	centre.add_child(caixa)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	columna.custom_minimum_size = Vector2(440, 0)
	caixa.add_child(columna)
	var titol := Label.new()
	titol.text = "🛏️ Dormir"
	titol.add_theme_font_size_override("font_size", 26)
	columna.add_child(titol)
	var ara := Label.new()
	ara.text = "Ara són les %s del %s" % [_hora(GestorTemps.hora_actual), GestorOnades.nom_del_dia(GestorTemps.dia_actual).to_lower()]
	ara.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	columna.add_child(ara)
	for o in OPCIONS:
		var hora: float = o[1]
		var b := Button.new()
		var motiu := motiu_no_dormir(hora)
		var endema := hora <= GestorTemps.hora_actual
		b.text = "%s   %s%s" % [o[0], _hora(hora) if hora != 6.0 else "", "  (demà)" if endema and hora != 6.0 else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.disabled = not motiu.is_empty()
		b.tooltip_text = motiu if not motiu.is_empty() else "Dormiràs %d h" % roundi(hores_fins(hora))
		b.pressed.connect(_dormir.bind(hora))
		columna.add_child(b)
	# El motiu (si n'hi ha) de les opcions que no es poden triar
	var motiu_nit := motiu_no_dormir(6.0)
	if not motiu_nit.is_empty():
		var avis := Label.new()
		avis.text = "⚠️ " + motiu_nit
		avis.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		columna.add_child(avis)
	var tancar_b := Button.new()
	tancar_b.text = "Ara no (Esc)"
	tancar_b.pressed.connect(tancar)
	columna.add_child(tancar_b)

static func _hora(h: float) -> String:
	return "%d:%02d" % [floori(h), floori(fposmod(h, 1.0) * 60.0)]

func _dormir(hora: float):
	if not motiu_no_dormir(hora).is_empty():
		return
	for f in get_children():
		f.queue_free()
	fos = ColorRect.new()
	fos.color = Color(0, 0, 0, 0)
	fos.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fos)
	text_fos = Label.new()
	text_fos.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_fos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_fos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_fos.add_theme_font_size_override("font_size", 36)
	text_fos.modulate.a = 0.0
	fos.add_child(text_fos)
	var hores := hores_fins(hora)
	var t := create_tween()
	t.tween_property(fos, "color:a", 1.0, 0.6)
	t.tween_callback(func():
		var nit := GestorTemps.es_nit() or hora < GestorTemps.hora_actual
		GestorTemps.avancar_fins(hora)
		if nit or hores >= 6.0:
			SalutJugador.restaurar_salut()
			var j = get_tree().get_first_node_in_group("jugador")
			if j and j.has_method("mana_max"):
				j.mana = j.mana_max()
		GestorPartida.guardar_mundo()
		text_fos.text = "💤  Has dormit %d h\n\n%s · %s" % [roundi(hores), GestorOnades.nom_del_dia(GestorTemps.dia_actual), _hora(GestorTemps.hora_actual)])
	t.tween_property(text_fos, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.2)
	t.tween_property(text_fos, "modulate:a", 0.0, 0.3)
	t.tween_property(fos, "color:a", 0.0, 0.6)
	t.tween_callback(tancar)

func _input(event: InputEvent):
	if fos == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	get_tree().paused = false
	queue_free()
