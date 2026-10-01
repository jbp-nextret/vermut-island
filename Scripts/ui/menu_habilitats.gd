extends CanvasLayer
## Arbres d'habilitats (autoload): K l'obre i el tanca (també Esc). Atura el joc.
## Tres pestanyes: Màgia d'atac, Màgia útil i Mundà. Cada habilitat és un botó: clica'l
## per gastar-hi un punt. Les línies mostren de quina habilitat depèn cadascuna.

const MIDA_NODE := Vector2(170, 64)
const SEPARACIO := Vector2(210, 105)

var caixa: PanelContainer
var label_punts: Label
var pestanyes: TabContainer
var descripcio: RichTextLabel
var botons := {}      # id -> Button
var lienzos := []     # Controls on es dibuixen les línies
var seleccionada := ""

func _ready():
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var fons := ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.6)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	caixa = PanelContainer.new()
	caixa.theme = EstilMenus.tema()
	caixa.add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	centre.add_child(caixa)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	caixa.add_child(columna)

	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "🌟 Habilitats"
	titol.add_theme_font_size_override("font_size", 28)
	titol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capcalera.add_child(titol)
	label_punts = Label.new()
	label_punts.add_theme_font_size_override("font_size", 18)
	label_punts.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	capcalera.add_child(label_punts)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar"
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	pestanyes = TabContainer.new()
	pestanyes.custom_minimum_size = Vector2(SEPARACIO.x * 3 + 20, SEPARACIO.y * 3 + 30)
	columna.add_child(pestanyes)
	for arbre in ArbreHabilitats.ARBRES:
		_crear_arbre(arbre)

	descripcio = RichTextLabel.new()
	descripcio.bbcode_enabled = true
	descripcio.custom_minimum_size = Vector2(0, 108)
	descripcio.add_theme_font_size_override("normal_font_size", 16)
	descripcio.add_theme_font_size_override("bold_font_size", 18)
	var fons_desc := StyleBoxFlat.new()
	fons_desc.bg_color = Color(0, 0, 0, 0.25)
	fons_desc.set_corner_radius_all(6)
	fons_desc.set_content_margin_all(10)
	descripcio.add_theme_stylebox_override("normal", fons_desc)
	columna.add_child(descripcio)

	Progressio.habilitats_canviades.connect(_refrescar)

func _crear_arbre(arbre: Dictionary):
	var lienzo := ArbreDibuix.new()
	lienzo.name = "%s %s" % [arbre.icona, arbre.nom]
	lienzo.arbre = arbre
	lienzo.menu = self
	pestanyes.add_child(lienzo)
	lienzos.append(lienzo)
	for h in arbre.habilitats:
		var b := Button.new()
		b.custom_minimum_size = MIDA_NODE
		b.size = MIDA_NODE
		b.position = posicio_node(h)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_clicar.bind(h.id))
		b.mouse_entered.connect(_mostrar.bind(h.id))
		b.focus_entered.connect(_mostrar.bind(h.id))
		lienzo.add_child(b)
		botons[h.id] = b

static func posicio_node(h: Dictionary) -> Vector2:
	return Vector2(20 + h.col * SEPARACIO.x, 14 + h.fila * SEPARACIO.y)

# ─────────────── Obrir / tancar

func _unhandled_input(event: InputEvent):
	if visible:
		if event.is_action_pressed("habilitats") or event.is_action_pressed("ui_cancel"):
			tancar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("habilitats") and MenuPausa.en_partida() and not MenuPausa.visible and not MenuInventari.visible:
		obrir()
		get_viewport().set_input_as_handled()

func obrir():
	if visible or not MenuPausa.en_partida():
		return
	visible = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_refrescar()
	# Primera habilitat de la pestanya actual
	_mostrar(ArbreHabilitats.ARBRES[pestanyes.current_tab].habilitats[0].id)

func tancar():
	visible = false
	get_tree().paused = false

# ─────────────── Botons i descripció

func _refrescar():
	label_punts.text = "Nivell %d · %d %s per gastar   " % [Progressio.nivell, Progressio.punts, "punt" if Progressio.punts == 1 else "punts"]
	for arbre in ArbreHabilitats.ARBRES:
		for h in arbre.habilitats:
			var b: Button = botons[h.id]
			var rang := Progressio.rang(h.id)
			var bloqueig := Progressio.motiu_bloqueig(h.id)
			b.text = "%s %s\n%s" % [h.icona, h.nom, ("%d / %d" % [rang, h.max]) if h.max > 0 else "Aviat"]
			var estil := StyleBoxFlat.new()
			estil.set_corner_radius_all(8)
			estil.set_content_margin_all(6)
			var color: Color = arbre.color
			if rang > 0:
				estil.bg_color = color.darkened(0.45)
				estil.set_border_width_all(2)
				estil.border_color = color
			elif bloqueig.is_empty():
				estil.bg_color = Color(0.2, 0.17, 0.22)
				estil.set_border_width_all(2)
				estil.border_color = Color(1.0, 0.85, 0.45)   # es pot comprar ara
			else:
				estil.bg_color = Color(0.12, 0.11, 0.13)
			for nom in ["normal", "hover", "pressed", "focus"]:
				var e: StyleBoxFlat = estil.duplicate()
				if nom == "hover" or nom == "focus":
					e.bg_color = e.bg_color.lightened(0.12)
				b.add_theme_stylebox_override(nom, e)
			b.modulate = Color.WHITE if rang > 0 or bloqueig.is_empty() or Progressio.punts == 0 else Color(1, 1, 1, 0.55)
	for l in lienzos:
		l.queue_redraw()
	if not seleccionada.is_empty():
		_mostrar(seleccionada)

func _mostrar(id: String):
	seleccionada = id
	var h := ArbreHabilitats.habilitat(id)
	var rang := Progressio.rang(id)
	var t := "[b]%s %s[/b]" % [h.icona, h.nom]
	if h.max > 0:
		t += "   (rang %d de %d)\n" % [rang, h.max]
		t += "Ara: %s\n" % (ArbreHabilitats.text_efecte(h, rang) if rang > 0 else "—")
		if rang < h.max:
			t += "Al rang %d: [color=#ffd97a]%s[/color]\n" % [rang + 1, ArbreHabilitats.text_efecte(h, rang + 1)]
	else:
		t += "\n" + h.text + "\n"
	var bloqueig := Progressio.motiu_bloqueig(id)
	t += "[color=#88ee88]Clica per millorar-la (1 punt)[/color]" if bloqueig.is_empty() else "[color=#aaaaaa]%s[/color]" % bloqueig
	descripcio.text = t

func _clicar(id: String):
	if not Progressio.millorar(id):
		var b: Button = botons[id]
		var tw := create_tween()
		for x in [-5.0, 5.0, -3.0, 0.0]:
			tw.tween_property(b, "position:x", posicio_node(ArbreHabilitats.habilitat(id)).x + x, 0.04)
	else:
		var b: Button = botons[id]
		b.pivot_offset = b.size / 2.0
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * 1.12, 0.07)
		tw.tween_property(b, "scale", Vector2.ONE, 0.15)
	_mostrar(id)

## Les línies entre habilitats (de la que fa falta cap a la que en depèn)
class ArbreDibuix extends Control:
	var arbre: Dictionary
	var menu
	func _draw():
		for h in arbre.habilitats:
			if not h.has("requisit"):
				continue
			var r := ArbreHabilitats.habilitat(h.requisit[0])
			var des_de: Vector2 = menu.posicio_node(r) + MIDA_NODE / 2.0
			var fins_a: Vector2 = menu.posicio_node(h) + MIDA_NODE / 2.0
			var complert: bool = Progressio.rang(r.id) >= h.requisit[1]
			draw_line(des_de, fins_a, Color(arbre.color, 0.9) if complert else Color(1, 1, 1, 0.18), 4.0 if complert else 2.0)
