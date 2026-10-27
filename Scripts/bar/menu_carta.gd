extends CanvasLayer
class_name MenuCarta
## Abans d'obrir la vermuteria: quant vols vendre de cada beguda que tens a les barriques.
## El que no posis a la carta es queda a la barrica (per fer receptes, per demà...).

var en_obrir: Callable          # rep la carta {producte: quantitat}
var carta := {}
var etiquetes := {}             # producte -> Label amb la quantitat
var boto_obrir: Button
var resum: Label

static func obrir(pare: Node, p_en_obrir: Callable) -> MenuCarta:
	var m := MenuCarta.new()
	m.en_obrir = p_en_obrir
	pare.get_tree().root.add_child(m)
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
	columna.add_theme_constant_override("separation", 12)
	columna.custom_minimum_size = Vector2(520, 0)
	caixa.add_child(columna)

	var titol := Label.new()
	titol.text = "📋 La carta d'avui"
	titol.add_theme_font_size_override("font_size", 26)
	columna.add_child(titol)
	var ajuda := Label.new()
	ajuda.text = "Tria quant vols vendre de cada beguda. El que no posis a la carta\nes queda a les barriques. Quan s'acabi, no entraran més clients."
	ajuda.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	columna.add_child(ajuda)

	for producte in Celler.SERVIBLES:
		var hi_ha := Celler.estoc(producte)
		if hi_ha <= 0:
			continue
		carta[producte] = hi_ha
		var info := CatalegObjectes.info(producte)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		columna.add_child(fila)
		var nom := Label.new()
		nom.text = "%s %s   %d 🪙" % [info.icona, info.nom, Celler.preu(producte)]
		nom.add_theme_font_size_override("font_size", 18)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nom)
		for o in [["−", -1], ["+", 1], ["Tot", 999]]:
			var b := Button.new()
			b.text = o[0]
			b.custom_minimum_size = Vector2(44, 0)
			var pas: int = o[1]
			b.pressed.connect(func(): _canviar(producte, pas))
			fila.add_child(b)
			if o[0] == "−":
				var l := Label.new()
				l.custom_minimum_size = Vector2(80, 0)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				l.add_theme_font_size_override("font_size", 18)
				fila.add_child(l)
				etiquetes[producte] = l

	resum = Label.new()
	resum.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	columna.add_child(resum)
	var botons := HBoxContainer.new()
	botons.alignment = BoxContainer.ALIGNMENT_END
	botons.add_theme_constant_override("separation", 8)
	columna.add_child(botons)
	var cancel := Button.new()
	cancel.text = "Cancel·lar (Esc)"
	cancel.pressed.connect(tancar)
	botons.add_child(cancel)
	boto_obrir = Button.new()
	boto_obrir.text = "🍷 Obrir la vermuteria"
	boto_obrir.custom_minimum_size = Vector2(0, 42)
	boto_obrir.pressed.connect(_obrir)
	botons.add_child(boto_obrir)
	_mostrar()

func _canviar(producte: String, pas: int):
	carta[producte] = clampi(int(carta[producte]) + pas, 0, Celler.estoc(producte))
	_mostrar()

func _mostrar():
	var total := 0
	var guany := 0
	for producte in carta:
		var n: int = carta[producte]
		etiquetes[producte].text = "%d / %d" % [n, Celler.estoc(producte)]
		total += n
		guany += n * Celler.preu(producte)
	resum.text = "%d begudes a la carta · fins a %d 🪙 (sense propines)" % [total, guany]
	boto_obrir.disabled = total == 0

func _obrir():
	var c := carta.duplicate()
	tancar()
	en_obrir.call(c)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	get_tree().paused = false
	queue_free()
