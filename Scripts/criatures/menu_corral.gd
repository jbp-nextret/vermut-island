extends CanvasLayer
class_name MenuCorral
## El menú del corral (F a la porta). Atura el joc mentre és obert.
##   - A l'esquerra, les criatures que viuen al corral: què produeixen i quant els falta
##   - Al mig, la resta de les teves criatures
##   - Arrossega-les d'una banda a l'altra per posar-les al corral o treure-les
##   - A la dreta, la cistella (el que han produït) i la menjadora: si hi ha menjar, en
##     produeixen el doble, i amb galetes daurades a vegades surt una cosa millor

var llista_corral: VBoxContainer
var llista_altres: VBoxContainer
var text_cistella: RichTextLabel
var boto_recollir: Button
var capacitat: Label
var titol_corral: Label
var menjadora: VBoxContainer
var temps_refresc := 0.0

static func obrir(_corral: Node) -> MenuCorral:
	var m := MenuCorral.new()
	_corral.get_tree().root.add_child(m)
	return m

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
	columna.add_theme_constant_override("separation", 10)
	caixa.add_child(columna)
	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "🏡 Corral"
	titol.add_theme_font_size_override("font_size", 26)
	capcalera.add_child(titol)
	capacitat = Label.new()
	capacitat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacitat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacitat.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	capcalera.add_child(capacitat)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (Esc)"
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	var cos := HBoxContainer.new()
	cos.add_theme_constant_override("separation", 14)
	columna.add_child(cos)
	# Al corral (s'hi pot deixar anar una criatura)
	var zona_corral := _zona("corral", Color(0.55, 0.42, 0.25, 0.35))
	cos.add_child(zona_corral)
	titol_corral = zona_corral.get_meta("titol")
	llista_corral = zona_corral.get_meta("llista")
	# Les altres
	var zona_altres := _zona("", Color(0, 0, 0, 0.25))
	cos.add_child(zona_altres)
	(zona_altres.get_meta("titol") as Label).text = "🐾 Les teves criatures"
	llista_altres = zona_altres.get_meta("llista")

	var dreta := VBoxContainer.new()
	dreta.custom_minimum_size = Vector2(230, 0)
	dreta.add_theme_constant_override("separation", 6)
	cos.add_child(dreta)
	dreta.add_child(_titol("🧺 Cistella"))
	text_cistella = RichTextLabel.new()
	text_cistella.bbcode_enabled = true
	text_cistella.custom_minimum_size = Vector2(230, 150)
	text_cistella.add_theme_font_size_override("normal_font_size", 15)
	dreta.add_child(text_cistella)
	boto_recollir = Button.new()
	boto_recollir.pressed.connect(func():
		var n := Criatures.recollir()
		if n > 0:
			EventBus.avis.emit("Has recollit %d objectes del corral" % n)
		_omplir())
	dreta.add_child(boto_recollir)
	dreta.add_child(_titol("🥣 Menjadora"))
	menjadora = VBoxContainer.new()
	menjadora.add_theme_constant_override("separation", 4)
	dreta.add_child(menjadora)
	var ajuda := Label.new()
	ajuda.text = "Arrossega les criatures cap al corral o fora. Amb menjar a la menjadora en produeixen el doble; amb galetes daurades, a vegades una cosa millor."
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD
	ajuda.custom_minimum_size = Vector2(230, 0)
	ajuda.add_theme_font_size_override("font_size", 12)
	ajuda.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	dreta.add_child(ajuda)
	Criatures.col_leccio_canviada.connect(_omplir)
	_omplir()

func _titol(text: String) -> Label:
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	return t

## Una columna on es poden deixar anar criatures: la de dins posa "corral", la de fora ""
func _zona(assignacio: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.set_corner_radius_all(8)
	e.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", e)
	p.custom_minimum_size = Vector2(330, 430)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := _titol("")
	v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var llista := VBoxContainer.new()
	llista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	llista.add_theme_constant_override("separation", 6)
	scroll.add_child(llista)
	p.set_meta("titol", t)
	p.set_meta("llista", llista)
	# Es pot deixar anar a qualsevol lloc de la columna (també a sobre d'una altra criatura)
	var pot := _pot_deixar(assignacio)
	var deixa := func(_pos, dades): _moure(dades.uid, assignacio)
	for c in [p, v, scroll, llista]:
		c.set_drag_forwarding(Callable(), pot, deixa)
	llista.set_meta("assignacio", assignacio)
	return p

func _pot_deixar(assignacio: String) -> Callable:
	return func(_pos, dades) -> bool:
		if not (dades is Dictionary and dades.has("uid")):
			return false
		var ara := Criatures.assignacio(dades.uid)
		# Al corral, si no hi és; fora, només si ara és al corral
		return ara != "corral" if assignacio == "corral" else ara == "corral"

func _moure(uid: String, assignacio: String):
	if assignacio == "corral" and Criatures.amb_assignacio("corral").size() >= Criatures.capacitat_corrals:
		EventBus.avis.emit("El corral és ple: fes-lo més gran o construeix-ne un altre")
		return
	Criatures.assignar(uid, assignacio)
	_omplir()

## Una criatura (es pot arrossegar)
func _fila(uid: String, zona: String) -> PanelContainer:
	var d := Criatures.dades(uid)
	var e := Criatures.especie(d.especie)
	var a := Criatures.assignacio(uid)
	var p := PanelContainer.new()
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(0, 0, 0, 0.3)
	estil.set_corner_radius_all(6)
	estil.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", estil)
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var imatge := TextureRect.new()
	imatge.texture = e.textura()
	imatge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imatge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imatge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imatge.custom_minimum_size = Vector2(40, 40)
	imatge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(imatge)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	var nom := Label.new()
	nom.text = "%s  · Nv %d" % [d.nom, Criatures.nivell(uid)]
	nom.add_theme_font_size_override("font_size", 15)
	info.add_child(nom)
	var objecte := Criatures.objecte_produccio(uid)
	var detall := Label.new()
	detall.add_theme_font_size_override("font_size", 12)
	detall.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	info.add_child(detall)
	if objecte.is_empty():
		detall.text = Criatures.ASSIGNACIONS.get(a, a)
		if a == "" and e.produccio != "":
			detall.text += "  ·  al corral faria %s" % CatalegObjectes.info(e.produccio).icona
	else:
		# Què fa i quant li falta (com les barriques)
		var oi := CatalegObjectes.info(objecte)
		detall.text = "%s %s  ·  %s" % [oi.icona, oi.nom, _temps(Criatures.minuts_que_falten(uid))]
		if a != "corral":
			detall.text = Criatures.ASSIGNACIONS.get(a, a) + "  ·  " + detall.text
		var barra := ProgressBar.new()
		barra.custom_minimum_size = Vector2(0, 6)
		barra.show_percentage = false
		barra.max_value = 1.0
		barra.value = Criatures.progres_produccio(uid)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ple := StyleBoxFlat.new()
		ple.bg_color = Color(0.55, 0.85, 0.45)
		barra.add_theme_stylebox_override("fill", ple)
		info.add_child(barra)
	p.set_drag_forwarding(func(_pos):
		var vista := Label.new()
		vista.text = "%s %s" % ["🐾", d.nom]
		vista.add_theme_font_size_override("font_size", 18)
		p.set_drag_preview(vista)
		return {"uid": uid}, _pot_deixar(zona), func(_pos, dades): _moure(dades.uid, zona))
	return p

## Minuts de joc en text ("1 h 20 min")
static func _temps(minuts: float) -> String:
	var m := ceili(minuts)
	if m >= 60:
		return "%d h %02d min" % [m / 60, m % 60]
	return "%d min" % m

func _omplir():
	if not is_inside_tree():
		return
	for llista in [llista_corral, llista_altres]:
		for f in llista.get_children():
			f.queue_free()
	var al_corral := Criatures.amb_assignacio("corral")
	for d in Criatures.col_leccio:
		if Criatures.especie(d.especie) == null:
			continue
		if d.uid in al_corral:
			llista_corral.add_child(_fila(d.uid, "corral"))
		else:
			llista_altres.add_child(_fila(d.uid, ""))
	if al_corral.is_empty():
		llista_corral.add_child(_buit("Arrossega aquí les criatures que vulguis que hi visquin."))
	if Criatures.col_leccio.is_empty():
		llista_altres.add_child(_buit("Encara no has domesticat cap criatura."))
	titol_corral.text = "🏡 Al corral  %d/%d" % [al_corral.size(), Criatures.capacitat_corrals]
	capacitat.text = "Hi caben %d criatures (1 per cada 3 caselles)" % Criatures.capacitat_corrals
	# La cistella
	var t := ""
	for objecte in Criatures.magatzem:
		var info := CatalegObjectes.info(objecte)
		t += "%s %s ×%d\n" % [info.icona, info.nom, int(Criatures.magatzem[objecte])]
	text_cistella.text = t if not t.is_empty() else "[color=#aaaaaa]Buida[/color]"
	var n := Criatures.objectes_magatzem()
	boto_recollir.text = "Recollir-ho tot (%d)" % n
	boto_recollir.disabled = n == 0
	# La menjadora
	for f in menjadora.get_children():
		f.queue_free()
	var estat := Label.new()
	estat.text = "Racions: %d%s" % [Criatures.racions, ("  ·  ✨ %d de qualitat" % Criatures.racions_daurades) if Criatures.racions_daurades > 0 else ""]
	if Criatures.racions + Criatures.racions_daurades == 0:
		estat.text = "Buida: produeixen el normal"
		estat.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	menjadora.add_child(estat)
	for objecte in Criatures.MENJARS:
		var quants := Inventari.tenir(objecte)
		if quants <= 0:
			continue
		var b := Button.new()
		var info := CatalegObjectes.info(objecte)
		var m: Dictionary = Criatures.MENJARS[objecte]
		b.text = "Posar %s %s (%d) · %d %s" % [info.icona, info.nom, quants, m.racions, "ració" if m.racions == 1 else "racions"]
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			if Criatures.alimentar(objecte, 1) == 0:
				EventBus.avis.emit("La menjadora és plena")
			_omplir())
		menjadora.add_child(b)

func _buit(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(290, 0)
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	return l

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	if Criatures.col_leccio_canviada.is_connected(_omplir):
		Criatures.col_leccio_canviada.disconnect(_omplir)
	get_tree().paused = false
	queue_free()
