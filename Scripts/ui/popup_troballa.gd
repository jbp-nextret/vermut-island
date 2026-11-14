extends CanvasLayer
class_name PopupTroballa
## Una targeta que baixa per dalt de la pantalla quan desenterres alguna cosa: la icona,
## què és, la raresa i una línia de descripció. Si en trobes diverses seguides, surten
## l'una després de l'altra. (No depèn de l'opció d'avisos: és la recompensa d'excavar.)

const SEGONS := 3.2

var cua: Array = []
var ocupat := false

static func mostrar(icona: String, titol: String, subtitol: String, descripcio: String, color: Color):
	var arrel := (Engine.get_main_loop() as SceneTree).root
	var p := arrel.get_node_or_null("PopupTroballa") as PopupTroballa
	if p == null:
		p = PopupTroballa.new()
		p.name = "PopupTroballa"
		arrel.add_child(p)
	p.cua.append([icona, titol, subtitol, descripcio, color])
	if not p.ocupat:
		p._seguent()

func _ready():
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

func _seguent():
	if cua.is_empty():
		ocupat = false
		return
	ocupat = true
	var d: Array = cua.pop_front()
	var color: Color = d[4]
	var targeta := PanelContainer.new()
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	estil.border_color = color
	estil.set_border_width_all(2)
	estil.set_corner_radius_all(10)
	estil.set_content_margin_all(14)
	estil.shadow_color = Color(0, 0, 0, 0.4)
	estil.shadow_size = 8
	targeta.add_theme_stylebox_override("panel", estil)
	targeta.custom_minimum_size = Vector2(380, 0)
	add_child(targeta)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	targeta.add_child(fila)
	var icona := Label.new()
	icona.text = d[0]
	icona.add_theme_font_size_override("font_size", 46)
	icona.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(icona)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	fila.add_child(col)
	var cap := Label.new()
	cap.text = "Has desenterrat"
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	col.add_child(cap)
	var titol := Label.new()
	titol.text = d[1]
	titol.add_theme_font_size_override("font_size", 21)
	col.add_child(titol)
	if not str(d[2]).is_empty():
		var sub := Label.new()
		sub.text = d[2]
		sub.add_theme_font_size_override("font_size", 14)
		sub.add_theme_color_override("font_color", color)
		col.add_child(sub)
	if not str(d[3]).is_empty():
		var desc := Label.new()
		desc.text = d[3]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(300, 0)
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		col.add_child(desc)
	# Centrada a dalt; baixa, s'espera i torna a pujar
	await get_tree().process_frame
	var ample := get_viewport().get_visible_rect().size.x
	targeta.position = Vector2((ample - targeta.size.x) / 2.0, -targeta.size.y - 10.0)
	var t := targeta.create_tween()
	t.tween_property(targeta, "position:y", 70.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(SEGONS)
	t.tween_property(targeta, "position:y", -targeta.size.y - 10.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		targeta.queue_free()
		_seguent())
