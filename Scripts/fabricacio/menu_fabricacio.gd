extends CanvasLayer
class_name MenuFabricacio
## Finestra de fabricació: la de la taula màgica ("taula") o la de la barrica ("barrica").
## A l'esquerra, les receptes per categories; a la dreta, la triada: ingredients (en
## verd si en tens prou), quantes vegades i el botó per fabricar. Les receptes que
## necessiten un plànol que encara no has trobat surten amagades.
## Atura el joc mentre és oberta. Esc per tancar.

var lloc := "taula"
var origen: Node3D        # la taula o la barrica (per a l'efecte en fabricar)
var categoria := ""
var triada: Recepta = null
var vegades := 1

var pestanyes: HBoxContainer
var llista: VBoxContainer
var det_icona: Label
var det_nom: Label
var det_text: RichTextLabel
var det_vegades: Label
var boto_fer: Button
var botons := {}          # id recepta -> Button

static func obrir(p_origen: Node3D, p_lloc: String) -> MenuFabricacio:
	var m := MenuFabricacio.new()
	m.origen = p_origen
	m.lloc = p_lloc
	p_origen.get_tree().root.add_child(m)
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
	titol.text = "✨ Taula de fabricació màgica" if lloc == "taula" else "🍷 Barrica: elaborar"
	titol.add_theme_font_size_override("font_size", 26)
	titol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capcalera.add_child(titol)
	if lloc == "taula":
		var p := Label.new()
		var pendents := Fabricacio.planols_pendents()
		p.text = "📜 Plànols per trobar: %d" % pendents if pendents > 0 else "📜 Tens tots els plànols!"
		p.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
		capcalera.add_child(p)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (Esc)"
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	pestanyes = HBoxContainer.new()
	pestanyes.add_theme_constant_override("separation", 6)
	columna.add_child(pestanyes)

	var cos := HBoxContainer.new()
	cos.add_theme_constant_override("separation", 16)
	columna.add_child(cos)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cos.add_child(scroll)
	llista = VBoxContainer.new()
	llista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	llista.add_theme_constant_override("separation", 6)
	scroll.add_child(llista)

	var detall := PanelContainer.new()
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(0, 0, 0, 0.3)
	estil.set_corner_radius_all(8)
	estil.set_content_margin_all(14)
	detall.add_theme_stylebox_override("panel", estil)
	detall.custom_minimum_size = Vector2(380, 460)
	cos.add_child(detall)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detall.add_child(dv)
	det_icona = Label.new()
	det_icona.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_icona.add_theme_font_size_override("font_size", 48)
	det_icona.pivot_offset = Vector2(180, 40)
	dv.add_child(det_icona)
	det_nom = Label.new()
	det_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_nom.add_theme_font_size_override("font_size", 22)
	dv.add_child(det_nom)
	det_text = RichTextLabel.new()
	det_text.bbcode_enabled = true
	det_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det_text.custom_minimum_size = Vector2(0, 230)
	det_text.add_theme_font_size_override("normal_font_size", 15)
	det_text.add_theme_font_size_override("bold_font_size", 15)
	dv.add_child(det_text)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	dv.add_child(fila)
	for o in [["−", -1], ["+", 1], ["Màx", 0]]:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(46, 0)
		var pas: int = o[1]
		b.pressed.connect(func(): _canviar_vegades(pas))
		fila.add_child(b)
		if o[0] == "−":
			det_vegades = Label.new()
			det_vegades.custom_minimum_size = Vector2(50, 0)
			det_vegades.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fila.add_child(det_vegades)
	boto_fer = Button.new()
	boto_fer.custom_minimum_size = Vector2(0, 44)
	boto_fer.add_theme_font_size_override("font_size", 18)
	boto_fer.pressed.connect(_fabricar)
	dv.add_child(boto_fer)

	var cats := []
	for r in Fabricacio.receptes(lloc):
		if not r.categoria in cats:
			cats.append(r.categoria)
	for c in cats:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.pressed.connect(_canviar_categoria.bind(c))
		pestanyes.add_child(b)
	pestanyes.visible = cats.size() > 1
	_canviar_categoria(cats[0] if not cats.is_empty() else "")

func _canviar_categoria(c: String):
	categoria = c
	for b in pestanyes.get_children():
		b.button_pressed = b.text == c
	_omplir()
	var primera = null
	for r in Fabricacio.receptes(lloc):
		if r.categoria == c:
			primera = r
			break
	if primera:
		_triar(primera)

func _omplir():
	for f in llista.get_children():
		f.queue_free()
	botons.clear()
	for r in Fabricacio.receptes(lloc):
		if r.categoria != categoria:
			continue
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(310, 44)
		b.add_theme_font_size_override("font_size", 16)
		if Fabricacio.coneguda(r):
			var info := CatalegObjectes.info(r.resultat)
			var n := Fabricacio.vegades_possibles(r)
			b.text = "%s  %s ×%d%s" % [info.icona, info.nom, r.quantitat, "" if n > 0 else "   (falta material)"]
			if n == 0:
				b.modulate = Color(1, 1, 1, 0.6)
		else:
			b.text = "📜  ???   (plànol per trobar)"
			b.modulate = Color(0.8, 0.75, 0.65)
		b.pressed.connect(_triar.bind(r))
		llista.add_child(b)
		botons[r.id] = b

func _triar(r: Recepta):
	triada = r
	vegades = 1
	for id in botons:
		botons[id].button_pressed = id == r.id
	_mostrar()

func _mostrar():
	var r: Recepta = triada
	if r == null:
		return
	if not Fabricacio.coneguda(r):
		det_icona.text = "📜"
		det_nom.text = "Plànol per descobrir"
		det_text.text = "[i]Encara no saps fer aquesta recepta. Els plànols es troben excavant: busca les marques de terra que brillen i desenterra-les amb l'aixada.[/i]"
		det_vegades.text = ""
		boto_fer.text = "No saps fer-ho"
		boto_fer.disabled = true
		return
	var info := CatalegObjectes.info(r.resultat)
	det_icona.text = info.icona
	det_nom.text = "%s ×%d" % [info.nom, r.quantitat]
	var t := "[i]%s[/i]\n\n[b]Ingredients[/b]\n" % info.descripcio
	for ing in r.ingredients:
		var cal: int = r.ingredients[ing] * vegades
		var tinc := Fabricacio.tinc(ing)
		var i := {"nom": "Vermut", "icona": "🍷"} if ing == "vermut" else CatalegObjectes.info(ing)
		var color := "#9fe39f" if tinc >= cal else "#ff8a80"
		t += "  %s %s  [color=%s]%d / %d[/color]\n" % [i.icona, i.nom, color, tinc, cal]
	t += "\nEn tens: %d" % Inventari.tenir(r.resultat)
	det_text.text = t
	var possibles := Fabricacio.vegades_possibles(r)
	vegades = clampi(vegades, 1, maxi(1, possibles))
	det_vegades.text = "×%d" % vegades
	boto_fer.text = "✨ Fabricar %d" % (r.quantitat * vegades)
	boto_fer.disabled = possibles < vegades or possibles == 0

func _canviar_vegades(pas: int):
	if triada == null:
		return
	var possibles := Fabricacio.vegades_possibles(triada)
	vegades = maxi(1, possibles) if pas == 0 else clampi(vegades + pas, 1, maxi(1, possibles))
	_mostrar()

func _fabricar():
	if triada == null or not Fabricacio.fer(triada, vegades):
		return
	# Un petit efecte: la icona fa un bot i la taula brilla
	var t := det_icona.create_tween()
	t.tween_property(det_icona, "scale", Vector2.ONE * 1.35, 0.08)
	t.tween_property(det_icona, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(origen) and origen.has_method("efecte_fabricar"):
		origen.efecte_fabricar(CatalegObjectes.info(triada.resultat).icona)
	var id := triada.id
	_omplir()
	if botons.has(id):
		botons[id].button_pressed = true
	_mostrar()

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	get_tree().paused = false
	queue_free()
