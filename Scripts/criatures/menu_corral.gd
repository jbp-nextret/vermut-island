extends CanvasLayer
class_name MenuCorral
## El menú del corral (F a la porta): què fa cada criatura i la cistella amb el que han
## produït. Atura el joc mentre és obert.

var llista: VBoxContainer
var text_cistella: RichTextLabel
var boto_recollir: Button
var capacitat: Label

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
	cos.add_theme_constant_override("separation", 16)
	columna.add_child(cos)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cos.add_child(scroll)
	llista = VBoxContainer.new()
	llista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	llista.add_theme_constant_override("separation", 8)
	scroll.add_child(llista)

	var dreta := VBoxContainer.new()
	dreta.custom_minimum_size = Vector2(250, 0)
	dreta.add_theme_constant_override("separation", 8)
	cos.add_child(dreta)
	var t := Label.new()
	t.text = "🧺 Cistella"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	dreta.add_child(t)
	text_cistella = RichTextLabel.new()
	text_cistella.bbcode_enabled = true
	text_cistella.custom_minimum_size = Vector2(250, 300)
	text_cistella.add_theme_font_size_override("normal_font_size", 16)
	dreta.add_child(text_cistella)
	boto_recollir = Button.new()
	boto_recollir.pressed.connect(func():
		var n := Criatures.recollir()
		if n > 0:
			EventBus.avis.emit("Has recollit %d objectes del corral" % n)
		_omplir())
	dreta.add_child(boto_recollir)
	var ajuda := Label.new()
	ajuda.text = "Al corral produeixen el que és propi de cada espècie. A les tasques, treballen pels voltants. Tot va a la cistella, i elles guanyen experiència."
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD
	ajuda.custom_minimum_size = Vector2(250, 0)
	ajuda.add_theme_font_size_override("font_size", 12)
	ajuda.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	dreta.add_child(ajuda)
	Criatures.col_leccio_canviada.connect(_omplir)
	_omplir()

func _omplir():
	if not is_inside_tree():
		return
	for f in llista.get_children():
		f.queue_free()
	if Criatures.col_leccio.is_empty():
		var l := Label.new()
		l.text = "Encara no has domesticat cap criatura."
		llista.add_child(l)
	for d in Criatures.col_leccio:
		llista.add_child(FitxaCriatura.crear(d.uid))
	capacitat.text = "Als corrals: %d / %d" % [Criatures.amb_assignacio("corral").size(), Criatures.capacitat_corrals]
	var t := ""
	for objecte in Criatures.magatzem:
		var info := CatalegObjectes.info(objecte)
		t += "%s %s ×%d\n" % [info.icona, info.nom, int(Criatures.magatzem[objecte])]
	text_cistella.text = t if not t.is_empty() else "[color=#aaaaaa]Buida[/color]"
	var n := Criatures.objectes_magatzem()
	boto_recollir.text = "Recollir-ho tot (%d)" % n
	boto_recollir.disabled = n == 0

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	if Criatures.col_leccio_canviada.is_connected(_omplir):
		Criatures.col_leccio_canviada.disconnect(_omplir)
	get_tree().paused = false
	queue_free()
