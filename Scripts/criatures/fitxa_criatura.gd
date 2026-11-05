extends PanelContainer
class_name FitxaCriatura
## Una fila amb una criatura domesticada: imatge, nom (editable), nivell i experiència,
## detalls, què fa (seguir-te, corral, tasques...) i el comportament si et segueix.
## La fan servir la Motxilla (pestanya Criatures) i el menú del corral.

var uid := ""

static func crear(p_uid: String) -> FitxaCriatura:
	var f := FitxaCriatura.new()
	f.uid = p_uid
	return f

func _ready():
	var d := Criatures.dades(uid)
	var e := Criatures.especie(d.especie)
	var assignacio := Criatures.assignacio(uid)
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(1.0, 0.85, 0.5, 0.12) if assignacio == "seguint" else Color(0, 0, 0, 0.25)
	estil.set_corner_radius_all(6)
	estil.set_content_margin_all(8)
	add_theme_stylebox_override("panel", estil)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	var imatge := TextureRect.new()
	imatge.texture = e.textura()
	imatge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imatge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imatge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imatge.custom_minimum_size = Vector2(56, 56)
	h.add_child(imatge)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var fila_nom := HBoxContainer.new()
	info.add_child(fila_nom)
	var nom := LineEdit.new()
	nom.text = d.nom
	nom.max_length = 18
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.tooltip_text = "Escriu un nom i prem Enter"
	nom.text_submitted.connect(func(t): Criatures.reanomenar(uid, t))
	nom.focus_exited.connect(func(): Criatures.reanomenar(uid, nom.text))
	fila_nom.add_child(nom)
	var n := Criatures.nivell(uid)
	var nivell := Label.new()
	nivell.text = "  Nv %d" % n
	nivell.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	fila_nom.add_child(nivell)
	# Experiència fins al nivell següent
	var barra := ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, 6)
	barra.show_percentage = false
	barra.max_value = Criatures.xp_per_nivell(n)
	barra.value = Criatures.xp(uid) if n < Criatures.NIVELL_MAXIM else barra.max_value
	var ple := StyleBoxFlat.new()
	ple.bg_color = Color(1.0, 0.8, 0.35)
	barra.add_theme_stylebox_override("fill", ple)
	barra.tooltip_text = "Experiència: %d / %d" % [barra.value, barra.max_value]
	info.add_child(barra)
	var detalls := Label.new()
	detalls.text = "%s · %s · Força %s\n%s\nAtac: %s" % [e.nom, e.text_dieta(), "★".repeat(e.forca), e.text_habilitat(), e.text_atac()]
	detalls.add_theme_font_size_override("font_size", 12)
	detalls.add_theme_color_override("font_color", Color(0.85, 0.87, 0.95))
	info.add_child(detalls)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	info.add_child(fila)
	# Què fa
	var feina := OptionButton.new()
	var claus := Criatures.ASSIGNACIONS.keys()
	for k in claus:
		var text: String = Criatures.ASSIGNACIONS[k]
		if k == "corral":
			text += " (%s)" % CatalegObjectes.info(e.produccio).icona if not e.produccio.is_empty() else ""
		feina.add_item(text)
	feina.selected = claus.find(assignacio)
	feina.item_selected.connect(func(i):
		if not Criatures.assignar(uid, claus[i]):
			feina.selected = claus.find(Criatures.assignacio(uid)))
	fila.add_child(feina)
	# Comportament (només compta quan et segueix)
	if assignacio == "seguint":
		var comportament := OptionButton.new()
		var cc := Criatures.COMPORTAMENTS.keys()
		for k in cc:
			comportament.add_item(Criatures.COMPORTAMENTS[k])
		comportament.selected = cc.find(Criatures.comportament(uid))
		comportament.tooltip_text = "Pacífic: no ataca mai · Neutral: et defensa dels que se t'acosten · Agressiu: ataca tots els enemics del voltant"
		comportament.item_selected.connect(func(i): Criatures.canviar_comportament(uid, cc[i]))
		fila.add_child(comportament)
