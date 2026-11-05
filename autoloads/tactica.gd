extends CanvasLayer
## Pausa tàctica (autoload). H, amb enemics o criatures salvatges a prop, atura el joc
## i et deixa donar ordres a la criatura que et segueix, per torns:
##   1 Atac · 2 Atac especial (cada 3 torns) · 3 Protegir-te · 4 Llançar olives/vermut
## Clic sobre un objectiu per triar-lo (Tab per passar al següent). Cada ordre s'executa
## i al cap d'un moment el joc es torna a aturar. H o Esc per tornar al combat lliure.
##
## Avantatges respecte del combat automàtic:
##   - La criatura guanya el doble d'experiència
##   - Les salvatges amb poca vida es rendeixen (i es domestiquen més fàcilment)
##   - Les salvatges derrotades deixen botí, i els monstres de la nit, monedes

const RADI := 12.0
const DURADA_TORN := 1.6
const TORNS_ESPECIAL := 3

var activa := false      # hi ha una sessió tàctica (també mentre s'executa un torn)
var esperant := false    # aturat, esperant una ordre
var protegint := false   # aquest torn la criatura et protegeix (reps la meitat de mal)
var objectiu: Node3D = null
var torns_especial := 0  # torns que falten per poder tornar a fer l'atac especial
var torn := 0

var capa: Control
var titol: Label
var botons := {}
var info: Label

func _ready():
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construir_ui()

# ─────────────── Entrar i sortir

func _input(event: InputEvent):
	if event.is_action_pressed("pausa_tactica"):
		if activa:
			sortir()
		else:
			entrar()
		get_viewport().set_input_as_handled()
		return
	if not esperant:
		return
	if event.is_action_pressed("ui_cancel"):
		sortir()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: ordre("atac")
			KEY_2: ordre("especial")
			KEY_3: ordre("protegir")
			KEY_4: ordre("llancar")
			KEY_TAB: _seguent_objectiu()
			_: return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var o := _objectiu_a(event.position)
		if o:
			objectiu = o
			capa.queue_redraw()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func entrar():
	if not MenuPausa.en_partida() or get_tree().paused or not GameState.pot_atacar():
		return
	if not is_instance_valid(Criatures.companya):
		EventBus.avis.emit("Cal una criatura que et segueixi per a la pausa tàctica")
		return
	if _objectius().is_empty():
		EventBus.avis.emit("No hi ha cap enemic a prop")
		return
	activa = true
	torn = 0
	torns_especial = 0
	_esperar()

func sortir():
	activa = false
	esperant = false
	protegint = false
	visible = false
	get_tree().paused = false

func _esperar():
	var objectius := _objectius()
	if objectius.is_empty() or not is_instance_valid(Criatures.companya):
		EventBus.avis.emit("Combat acabat")
		sortir()
		return
	if not is_instance_valid(objectiu) or not objectiu in objectius:
		objectiu = objectius[0]
	esperant = true
	protegint = false
	visible = true
	get_tree().paused = true
	_actualitzar_botons()

# ─────────────── Ordres

func ordre(quina: String):
	if not esperant or not is_instance_valid(objectiu):
		return
	var c: Criatura = Criatures.companya
	match quina:
		"especial":
			if torns_especial > 0:
				EventBus.avis.emit("L'atac especial encara no està a punt (%d torns)" % torns_especial)
				return
			torns_especial = TORNS_ESPECIAL + 1
		"llancar":
			var objecte := _objecte_a_llancar()
			if objecte.is_empty():
				EventBus.avis.emit("No tens olives marinades ni vermut hipnòtic")
				return
			Inventari.treure(objecte)
			var jugador := get_tree().get_first_node_in_group("player") as Node3D
			Llancable.llancar(get_tree().current_scene, objecte, jugador.global_position + Vector3.UP * 1.1, objectiu.global_position)
		"protegir":
			protegint = true
	torn += 1
	torns_especial = maxi(0, torns_especial - 1)
	esperant = false
	visible = false
	get_tree().paused = false
	c.ordre_tactica(quina, objectiu)
	await get_tree().create_timer(DURADA_TORN).timeout
	if activa:
		_esperar()

## Olives per a les herbívores; vermut per a la resta (o el que tinguis)
func _objecte_a_llancar() -> String:
	var herbivora: bool = objectiu is Criatura and objectiu.especie.dieta == EspecieCriatura.Dieta.HERBIVORA
	var preferit := "olives_marinades" if herbivora else "vermut_hipnotic"
	if Inventari.tenir(preferit) > 0:
		return preferit
	if Inventari.tenir("vermut_hipnotic") > 0:
		return "vermut_hipnotic"
	return ""

# ─────────────── Objectius

func _objectius() -> Array:
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	if jugador == null:
		return []
	var llista := []
	for e in get_tree().get_nodes_in_group("enemics") + get_tree().get_nodes_in_group("criatures_salvatges"):
		if not is_instance_valid(e) or ("fugint" in e and e.fugint):
			continue
		var cap: Vector3 = e.global_position - jugador.global_position
		cap.y = 0
		if cap.length() <= RADI:
			llista.append(e)
	llista.sort_custom(func(a, b): return a.global_position.distance_to(jugador.global_position) < b.global_position.distance_to(jugador.global_position))
	return llista

func _seguent_objectiu():
	var llista := _objectius()
	if llista.is_empty():
		return
	var i := llista.find(objectiu)
	objectiu = llista[(i + 1) % llista.size()]
	capa.queue_redraw()

func _objectiu_a(pos: Vector2) -> Node3D:
	var camera := get_viewport().get_camera_3d()
	for e in _objectius():
		if camera.unproject_position(e.global_position + Vector3.UP * 0.5).distance_to(pos) < 40.0:
			return e
	return null

# ─────────────── Interfície

func _construir_ui():
	capa = Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.draw.connect(_dibuixar)
	add_child(capa)
	titol = Label.new()
	titol.text = "⏸ Pausa tàctica"
	titol.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titol.position = Vector2(-150, 70)
	titol.size = Vector2(300, 40)
	titol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titol.add_theme_font_size_override("font_size", 26)
	titol.add_theme_color_override("font_outline_color", Color.BLACK)
	titol.add_theme_constant_override("outline_size", 8)
	capa.add_child(titol)
	info = Label.new()
	info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	info.position = Vector2(-300, 108)
	info.size = Vector2(600, 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 6)
	capa.add_child(info)
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	fila.position = Vector2(-330, -150)
	fila.size = Vector2(660, 56)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	capa.add_child(fila)
	for o in [["atac", "1 ⚔️ Atac"], ["especial", "2 ✨ Especial"], ["protegir", "3 🛡️ Protegir"], ["llancar", "4 🫒 Llançar"], ["sortir", "H ▶ Combat lliure"]]:
		var b := Button.new()
		b.text = o[1]
		b.theme = EstilMenus.tema()
		b.custom_minimum_size = Vector2(120, 48)
		b.focus_mode = Control.FOCUS_NONE
		var clau: String = o[0]
		b.pressed.connect(func():
			if clau == "sortir":
				sortir()
			else:
				ordre(clau))
		fila.add_child(b)
		botons[clau] = b

func _actualitzar_botons():
	var c: Criatura = Criatures.companya
	var nom: String = Criatures.dades(c.uid).get("nom", c.especie.nom)
	botons.especial.disabled = torns_especial > 0
	botons.especial.text = "2 ✨ %s" % ("Especial" if torns_especial == 0 else "(%d)" % torns_especial)
	botons.llancar.disabled = _objecte_a_llancar().is_empty() if is_instance_valid(objectiu) else true
	info.text = "Torn %d · %s (Nv %d) · Experiència doble · Clic o Tab: objectiu" % [torn + 1, nom, c.nivell]
	capa.queue_redraw()

func _process(_delta):
	if esperant:
		capa.queue_redraw()

func _dibuixar():
	if not esperant:
		return
	var mida := capa.get_viewport_rect().size
	# Vinyeta fosca
	capa.draw_rect(Rect2(Vector2.ZERO, mida), Color(0.02, 0.03, 0.08, 0.35))
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := ThemeDB.fallback_font
	var t := Time.get_ticks_msec() / 1000.0
	for e in _objectius():
		var p := camera.unproject_position(e.global_position + Vector3.UP * 0.5)
		var triat: bool = e == objectiu
		var color := Color(1.0, 0.85, 0.3) if triat else Color(1, 1, 1, 0.6)
		var r := 26.0 + (sin(t * 5.0) * 3.0 if triat else 0.0)
		capa.draw_arc(p, r, 0, TAU, 32, color, 3.0 if triat else 1.5)
		var nom: String
		var vida := 1.0
		if e is Criatura:
			nom = "%s Nv %d" % [e.especie.nom, e.nivell]
			vida = float(e.vida) / e.vida_maxima
		else:
			nom = e.nom_enemic if "nom_enemic" in e else "Enemic"
			vida = float(e.vida_actual) / e.vida_maxima if "vida_actual" in e else 1.0
		var w := font.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		capa.draw_string_outline(font, p + Vector2(-w / 2.0, -r - 14), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		capa.draw_string(font, p + Vector2(-w / 2.0, -r - 14), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		capa.draw_rect(Rect2(p + Vector2(-22, -r - 8), Vector2(44, 4)), Color(0, 0, 0, 0.7))
		capa.draw_rect(Rect2(p + Vector2(-22, -r - 8), Vector2(44 * clampf(vida, 0.0, 1.0), 4)), Color(1.0, 0.3, 0.3).lerp(Color(0.4, 0.9, 0.4), vida))
	# La teva criatura, amb una fletxa cap a l'objectiu
	var c = Criatures.companya
	if is_instance_valid(c) and is_instance_valid(objectiu):
		var a := camera.unproject_position(c.global_position + Vector3.UP * 0.5)
		var b := camera.unproject_position(objectiu.global_position + Vector3.UP * 0.5)
		capa.draw_dashed_line(a, b, Color(1.0, 0.85, 0.3, 0.7), 2.0, 8.0)
		capa.draw_circle(a, 6.0, Color(0.4, 0.8, 1.0))
