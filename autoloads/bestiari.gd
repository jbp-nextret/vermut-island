extends CanvasLayer
## Bestiari (autoload): l'enciclopèdia de les criatures. B l'obre i el tanca (Esc també).
##   - Les que no has vist mai: silueta i "???"
##   - Les vistes: aspecte, nom, descripció, on viuen i com capturar-les
##   - Les domesticades: a més, l'habilitat que tenen i quantes n'has domesticat

const COLS := 3
const MIDA_FITXA := Vector2(118, 132)

var graella: GridContainer
var detall_imatge: TextureRect
var detall_nom: Label
var detall_estat: Label
var detall_text: RichTextLabel
var comptador: Label
var seleccionada := ""
var fitxes := {}   # id -> Button

func _ready():
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construir_ui()

func _unhandled_input(event: InputEvent):
	if visible:
		if event.is_action_pressed("bestiari") or event.is_action_pressed("ui_cancel"):
			tancar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bestiari") and MenuPausa.en_partida() and not MenuPausa.visible:
		obrir()
		get_viewport().set_input_as_handled()

func obrir(especie_id := ""):
	if visible or not MenuPausa.en_partida() or GameState.en_dialeg or MenuInventari.visible or MenuHabilitats.visible or Mapa.visible:
		return
	visible = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_omplir()
	if not especie_id.is_empty():
		seleccionada = especie_id
	if seleccionada.is_empty() or not Criatures.especies.has(seleccionada):
		seleccionada = _ordenades()[0].id if not _ordenades().is_empty() else ""
	_mostrar(seleccionada)

func tancar():
	visible = false
	get_tree().paused = false

## Per força i, a igual força, per nom (així l'ordre és sempre el mateix)
func _ordenades() -> Array:
	var llista: Array = Criatures.especies.values()
	llista.sort_custom(func(a, b): return a.forca < b.forca if a.forca != b.forca else a.nom < b.nom)
	return llista

# ─────────────── Interfície

func _construir_ui():
	var fons := ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.6)
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
	columna.add_theme_constant_override("separation", 12)
	caixa.add_child(columna)

	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "📖 Bestiari"
	titol.add_theme_font_size_override("font_size", 28)
	capcalera.add_child(titol)
	comptador = Label.new()
	comptador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comptador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comptador.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	capcalera.add_child(comptador)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (%s)" % SettingsManager.tecla_de("bestiari")
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	var cos := HBoxContainer.new()
	cos.add_theme_constant_override("separation", 18)
	columna.add_child(cos)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLS * (MIDA_FITXA.x + 8) + 12, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cos.add_child(scroll)
	graella = GridContainer.new()
	graella.columns = COLS
	graella.add_theme_constant_override("h_separation", 8)
	graella.add_theme_constant_override("v_separation", 8)
	scroll.add_child(graella)

	# La pàgina de l'enciclopèdia
	var pagina := PanelContainer.new()
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(0.93, 0.87, 0.74)
	estil.set_corner_radius_all(6)
	estil.set_content_margin_all(16)
	estil.border_color = Color(0.55, 0.4, 0.25)
	estil.set_border_width_all(3)
	pagina.add_theme_stylebox_override("panel", estil)
	pagina.custom_minimum_size = Vector2(400, 500)
	cos.add_child(pagina)
	var detall := VBoxContainer.new()
	detall.add_theme_constant_override("separation", 6)
	pagina.add_child(detall)
	detall_imatge = TextureRect.new()
	detall_imatge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detall_imatge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detall_imatge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detall_imatge.custom_minimum_size = Vector2(0, 104)
	detall.add_child(detall_imatge)
	detall_nom = Label.new()
	detall_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detall_nom.add_theme_font_size_override("font_size", 26)
	detall_nom.add_theme_color_override("font_color", Color(0.25, 0.15, 0.08))
	detall.add_child(detall_nom)
	detall_estat = Label.new()
	detall_estat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detall_estat.add_theme_font_size_override("font_size", 15)
	detall.add_child(detall_estat)
	detall_text = RichTextLabel.new()
	detall_text.bbcode_enabled = true
	detall_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detall_text.add_theme_font_size_override("normal_font_size", 14)
	detall_text.add_theme_font_size_override("bold_font_size", 14)
	detall_text.add_theme_font_size_override("italics_font_size", 14)
	detall_text.add_theme_color_override("default_color", Color(0.22, 0.15, 0.1))
	detall.add_child(detall_text)

func _omplir():
	for f in graella.get_children():
		f.queue_free()
	fitxes.clear()
	var vistes := 0
	var dom := 0
	for e in _ordenades():
		var vista := Criatures.vista(e.id)
		var domesticada := Criatures.domesticada(e.id)
		vistes += int(vista)
		dom += int(domesticada)
		var b := Button.new()
		b.custom_minimum_size = MIDA_FITXA
		b.toggle_mode = true
		b.tooltip_text = e.nom if vista else "???"
		b.pressed.connect(_mostrar.bind(e.id))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var img := TextureRect.new()
		img.texture = e.textura() if vista else e.silueta()
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(0, 72)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
		var nom := Label.new()
		nom.text = e.nom if vista else "???"
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nom.add_theme_font_size_override("font_size", 13)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nom)
		var marca := Label.new()
		marca.text = "❤ Domesticada" if domesticada else ("👁️ Vista" if vista else "")
		marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marca.add_theme_font_size_override("font_size", 11)
		marca.add_theme_color_override("font_color", Color(1.0, 0.6, 0.75) if domesticada else Color(0.7, 0.85, 1.0))
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(marca)
		graella.add_child(b)
		fitxes[e.id] = b
	var total := Criatures.especies.size()
	comptador.text = "Vistes %d/%d  ·  Domesticades %d/%d" % [vistes, total, dom, total]

func _mostrar(id: String):
	seleccionada = id
	for k in fitxes:
		fitxes[k].button_pressed = k == id
	var e := Criatures.especie(id)
	if e == null:
		return
	var vista := Criatures.vista(id)
	var domesticada := Criatures.domesticada(id)
	detall_imatge.texture = e.textura() if vista else e.silueta()
	detall_nom.text = e.nom if vista else "???"
	if domesticada:
		var n := int(Criatures.domesticades[id])
		detall_estat.text = "❤ Domesticada (%d %s)" % [n, "vegada" if n == 1 else "vegades"]
		detall_estat.add_theme_color_override("font_color", Color(0.75, 0.25, 0.4))
	elif vista:
		detall_estat.text = "👁️ Vista, encara no domesticada"
		detall_estat.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	else:
		detall_estat.text = "Encara no l'has vista"
		detall_estat.add_theme_color_override("font_color", Color(0.45, 0.4, 0.35))
	var t := ""
	if not vista:
		t = "[i]Una criatura que encara no has trobat. Explora les illetes: al mapa, les criatures que no has vist mai surten amb un [b]?[/b][/i]"
	else:
		t += "[i]%s[/i]\n\n" % e.descripcio
		t += "[b]Hàbitat:[/b] %s\n" % e.text_zona()
		t += "[b]Dieta:[/b] %s\n" % e.text_dieta()
		t += "[b]Caràcter:[/b] %s\n" % e.text_caracter()
		t += "[b]Força:[/b] %s%s\n" % ["★".repeat(e.forca), "☆".repeat(5 - e.forca)]
		t += "\n[b]Com domesticar-la:[/b] %s\n" % e.text_captura()
		if domesticada:
			t += "\n[b]Quan et segueix:[/b] %s\n" % e.text_habilitat()
		else:
			t += "\n[b]Quan et segueix:[/b] [i]domestica-la per descobrir-ho[/i]\n"
	detall_text.text = t
