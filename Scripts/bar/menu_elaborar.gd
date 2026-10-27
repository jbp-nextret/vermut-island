extends CanvasLayer
class_name MenuElaborar
## Finestra de la barrica (fora del servei): elaborar coses amb el que portes.
## Les receptes són a RECEPTES; "vermut" vol dir vermut preparat (o raïm per trepitjar).
## Atura el joc mentre és oberta. Esc o F per tancar.

const RECEPTES := [
	{"id": "olives_marinades", "quantitat": 3, "ingredients": {"olives": 3, "vermut": 1}},
	{"id": "vermut_hipnotic", "quantitat": 1, "ingredients": {"vermut": 2, "fibra": 1}},
	# Provisional, fins que hi hagi el sistema de fabricació
	{"id": "tanca_fusta", "quantitat": 4, "ingredients": {"fusta": 2}},
	{"id": "porta_tanca", "quantitat": 1, "ingredients": {"fusta": 3, "fibra": 1}},
]

var llista: VBoxContainer
var barrica: Node3D

static func obrir(p_barrica: Node3D) -> MenuElaborar:
	var m := MenuElaborar.new()
	m.barrica = p_barrica
	p_barrica.get_tree().root.add_child(m)
	return m

static func tinc(ingredient: String) -> int:
	if ingredient == "vermut":
		return Barrica.vermuts_disponibles()
	return Inventari.tenir(ingredient)

static func es_pot_fer(recepta: Dictionary) -> bool:
	for ing in recepta.ingredients:
		if tinc(ing) < recepta.ingredients[ing]:
			return false
	return true

static func fer(recepta: Dictionary) -> bool:
	if not es_pot_fer(recepta):
		return false
	for ing in recepta.ingredients:
		if ing == "vermut":
			Barrica.gastar_vermuts(recepta.ingredients[ing])
		else:
			Inventari.treure(ing, recepta.ingredients[ing])
	Inventari.afegir(recepta.id, recepta.quantitat)
	return true

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
	caixa.add_child(columna)
	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "🍷 Barrica: elaborar"
	titol.add_theme_font_size_override("font_size", 26)
	titol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capcalera.add_child(titol)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (Esc)"
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)
	llista = VBoxContainer.new()
	llista.add_theme_constant_override("separation", 10)
	columna.add_child(llista)
	_omplir()

func _omplir():
	for f in llista.get_children():
		f.queue_free()
	for r in RECEPTES:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 14)
		llista.add_child(fila)
		var info := CatalegObjectes.info(r.id)
		var esquerra := VBoxContainer.new()
		esquerra.custom_minimum_size = Vector2(380, 0)
		fila.add_child(esquerra)
		var nom := Label.new()
		nom.text = "%s %s ×%d   (en tens %d)" % [info.icona, info.nom, r.quantitat, Inventari.tenir(r.id)]
		nom.add_theme_font_size_override("font_size", 19)
		esquerra.add_child(nom)
		var ingredients := RichTextLabel.new()
		ingredients.bbcode_enabled = true
		ingredients.fit_content = true
		ingredients.scroll_active = false
		ingredients.add_theme_font_size_override("normal_font_size", 15)
		var parts: Array[String] = []
		for ing in r.ingredients:
			var cal: int = r.ingredients[ing]
			var nom_ing := "🍷 Vermut" if ing == "vermut" else "%s %s" % [CatalegObjectes.info(ing).icona, CatalegObjectes.info(ing).nom]
			var color := "#9fe39f" if tinc(ing) >= cal else "#ff8a80"
			parts.append("[color=%s]%s %d/%d[/color]" % [color, nom_ing, mini(tinc(ing), cal), cal])
		ingredients.text = " · ".join(parts)
		esquerra.add_child(ingredients)
		var boto := Button.new()
		boto.text = "Fer"
		boto.custom_minimum_size = Vector2(90, 0)
		boto.disabled = not es_pot_fer(r)
		boto.pressed.connect(func():
			if fer(r):
				_omplir())
		fila.add_child(boto)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interactuar"):
		get_viewport().set_input_as_handled()
		tancar()

func tancar():
	get_tree().paused = false
	queue_free()
