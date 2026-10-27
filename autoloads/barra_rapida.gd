extends CanvasLayer
## Barra ràpida (autoload): 9 caselles configurables amb eines i objectes, com Minecraft.
##   - 1–9 o clic a la casella: tria l'eina (tornar-la a triar = mans buides)
##   - Rodeta del ratolí: casella següent / anterior (el zoom passa a Ctrl+rodeta)
##   - Mantenir Tab: roda radial amb totes les eines; apuntes i deixes anar
##   - A la Motxilla s'hi arrosseguen eines i objectes per configurar-la
## Les tecles d'abans (Q, E, P, G, T, L) continuen funcionant com a dreceres.
## Les eines són objectes de la motxilla (espasa, grimori de foc, llavors, regadora,
## aixada) i ocupen un espai; només es poden posar a la barra si les tens.
##
## Quina eina està activa no es guarda aquí: es dedueix de l'estat (mode combat,
## plantador, regador...). Així sempre quadra, s'hi entri com s'hi entri.

signal canviada   # la configuració de les caselles

const FITXER := "user://barra_rapida.save"
const CASELLES := 9

## Objectes de la motxilla que són eines: què fan quan els tries a la barra.
## (Les eines ocupen un espai de la motxilla, com qualsevol altre objecte.)
const EINES := {
	"eina_espasa": {"accio": "espasa", "color": Color(0.55, 0.85, 1.0)},
	"eina_grimori_foc": {"accio": "foc", "color": Color(1.0, 0.55, 0.15)},
	"llavor_raim": {"accio": "plantar", "color": Color(0.55, 0.95, 0.5)},
	"eina_regadora": {"accio": "regar", "color": Color(0.45, 0.75, 1.0)},
	"eina_aixada": {"accio": "llaurar", "color": Color(0.85, 0.65, 0.35)},
}
## Objectes que es llancen (es gasten)
const OBJECTES_US := ["olives_marinades", "vermut_hipnotic"]

const PER_DEFECTE := ["eina_espasa", "eina_grimori_foc", "llavor_raim", "eina_regadora", "eina_aixada", "olives_marinades", "vermut_hipnotic", "", ""]
## Configuracions desades abans que les eines fossin objectes
const NOMS_ANTICS := {"espasa": "eina_espasa", "foc": "eina_grimori_foc", "plantar": "llavor_raim", "regar": "eina_regadora", "llaurar": "eina_aixada"}

var caselles: Array = PER_DEFECTE.duplicate()
var ultima := 0           # per a la rodeta quan no hi ha cap eina activa
var mode_foc := false

var roda: Control
var roda_opcions: Array = []   # ids ("" = mans buides)
var roda_triada := -1

func _ready():
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar()
	roda = Control.new()
	roda.set_anchors_preset(Control.PRESET_FULL_RECT)
	roda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roda.visible = false
	roda.draw.connect(_dibuixar_roda)
	add_child(roda)

# ─────────────── Què es pot posar i com es diu

func es_pot_posar(id: String) -> bool:
	return EINES.has(id) or id in OBJECTES_US

func info(id: String) -> Dictionary:
	var i := CatalegObjectes.info(id)
	var color: Color = EINES[id].color if EINES.has(id) else (Color(0.75, 0.6, 1.0) if id == "vermut_hipnotic" else Color(0.6, 0.8, 0.3))
	return {"nom": i.nom, "icona": i.icona, "color": color}

## Què fa: "espasa", "foc", "plantar", "regar", "llaurar" o l'objecte que es llança
func accio(id: String) -> String:
	return EINES[id].accio if EINES.has(id) else id

## Si se n'ha de mostrar la quantitat (les eines no; les llavors i el que es llança, sí)
func mostra_quantitat(id: String) -> bool:
	return id in OBJECTES_US or id == "llavor_raim"

## Es pot fer servir ara mateix? L'has de tenir a la motxilla (i la bola de foc, saber-la llançar)
func disponible(id: String) -> bool:
	if not es_pot_posar(id) or Inventari.tenir(id) <= 0:
		return false
	if accio(id) == "foc":
		return Progressio.te("bola_foc")
	return true

# ─────────────── Configurar

func assignar(index: int, id: String):
	if index < 0 or index >= CASELLES:
		return
	# Si ja era en una altra casella, s'intercanvien
	var abans := caselles.find(id)
	if abans >= 0 and not id.is_empty():
		caselles[abans] = caselles[index]
	caselles[index] = id
	canviada.emit()
	guardar()

func intercanviar(a: int, b: int):
	var x = caselles[a]
	caselles[a] = caselles[b]
	caselles[b] = x
	canviada.emit()
	guardar()

func buidar(index: int):
	assignar(index, "")

# ─────────────── Eina activa

func _mon() -> Node:
	var m := get_tree().current_scene
	return m if m and "plantador" in m and m.plantador != null else null

func _jugador() -> Node:
	return get_tree().get_first_node_in_group("player")

## L'objecte de la barra que correspon a l'eina activa ("" si cap)
func eina_activa() -> String:
	var a := accio_activa()
	if a.is_empty():
		return ""
	for id in EINES:
		if EINES[id].accio == a:
			return id
	return a   # els objectes que es llancen ja són el seu id

func accio_activa() -> String:
	var mon := _mon()
	if mon == null:
		return ""
	if mon.plantador.actiu:
		return "plantar"
	if mon.regador.actiu:
		return "regar"
	if mon.llaurador.actiu:
		return "llaurar"
	if "llancador" in mon and mon.llancador and mon.llancador.actiu:
		return mon.llancador.objecte()
	if mode_foc:
		return "foc"
	var j := _jugador()
	if j and j.estat == 1:   # Estat.COMBAT
		return "espasa"
	return ""

## La casella seleccionada (-1 si l'eina activa no hi és o vas amb les mans buides)
func seleccionada() -> int:
	var e := eina_activa()
	return caselles.find(e) if not e.is_empty() else -1

func seleccionar(index: int):
	if index < 0 or index >= CASELLES:
		return
	ultima = index
	var id: String = caselles[index]
	if id.is_empty() or id == eina_activa():
		desactivar()
	else:
		activar(id)

func activar(id: String):
	var mon := _mon()
	if mon == null or not GameState.pot_atacar():
		return
	if Inventari.tenir(id) <= 0 and not id in OBJECTES_US:
		EventBus.avis.emit("No tens %s" % CatalegObjectes.info(id).nom.to_lower())
		return
	desactivar()
	var j := _jugador()
	match accio(id):
		"espasa":
			if j.estat != 1:
				j.toggle_mode_combat()
		"foc":
			if not Progressio.te("bola_foc"):
				j.magia_bloquejada.emit()
				return
			mode_foc = true
		"plantar":
			mon.plantador.entrar()
		"regar":
			mon.regador.entrar()
		"llaurar":
			mon.llaurador.entrar()
		_:
			if id in OBJECTES_US:
				mon.llancador.entrar_amb(id)

func desactivar():
	mode_foc = false
	var mon := _mon()
	if mon == null:
		return
	if mon.plantador.actiu:
		mon.plantador.sortir()
	for eina in [mon.regador, mon.llaurador, mon.llancador]:
		if eina and eina.actiu:
			eina.sortir()
	var j := _jugador()
	if j and j.estat == 1:
		j.toggle_mode_combat()

# ─────────────── Entrada

func _pot_fer_servir() -> bool:
	return MenuPausa.en_partida() and not get_tree().paused and GameState.pot_atacar() and _mon() != null

func _unhandled_input(event: InputEvent):
	if not _pot_fer_servir():
		if roda.visible:
			_tancar_roda(false)
		return
	for i in CASELLES:
		if event.is_action_pressed("barra_%d" % (i + 1)):
			seleccionar(i)
			get_viewport().set_input_as_handled()
			return
	# Rodeta: casella següent / anterior (amb Ctrl, la càmera fa zoom)
	if event is InputEventMouseButton and event.pressed and not event.ctrl_pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var actual := seleccionada()
		if actual < 0:
			actual = ultima
		var pas := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		seleccionar(posmod(actual + pas, CASELLES))
		get_viewport().set_input_as_handled()
		return
	# Mode bola de foc: el clic la llança cap al ratolí
	if mode_foc and event.is_action_pressed("accio_primaria"):
		_jugador().disparar_bola_foc()
		get_viewport().set_input_as_handled()
		return
	if mode_foc and (event.is_action_pressed("accio_secundaria") or event.is_action_pressed("ui_cancel")):
		mode_foc = false
		get_viewport().set_input_as_handled()
		return

## La roda va a _input (abans que la interfície): si no, quan un botó té el focus,
## el Tab el fa servir Godot per passar al botó següent i la roda no s'obre mai
func _input(event: InputEvent):
	if event.is_action_pressed("roda_eines") and not roda.visible and _pot_fer_servir():
		_obrir_roda()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("roda_eines") and roda.visible:
		_tancar_roda(true)
		get_viewport().set_input_as_handled()

func _process(_delta):
	if mode_foc and not GameState.pot_atacar():
		mode_foc = false
	if roda.visible:
		_actualitzar_roda()

# ─────────────── Roda radial (Tab)

func _obrir_roda():
	roda_opcions = [""]
	for id in EINES.keys() + OBJECTES_US:
		if disponible(id):
			roda_opcions.append(id)
	roda_triada = -1
	roda.visible = true
	Engine.time_scale = 0.25   # el temps gairebé s'atura mentre tries

func _tancar_roda(aplicar: bool):
	roda.visible = false
	Engine.time_scale = 1.0
	if aplicar and roda_triada >= 0:
		var id: String = roda_opcions[roda_triada]
		if id.is_empty():
			desactivar()
		elif id != eina_activa():
			activar(id)

func _actualitzar_roda():
	var centre := roda.get_viewport_rect().size / 2.0
	var cap := roda.get_local_mouse_position() - centre
	if cap.length() < 40.0:
		roda_triada = -1
	else:
		var n := roda_opcions.size()
		# La primera opció (mans buides) a dalt; en el sentit de les agulles
		var angle := fposmod(cap.angle() + PI / 2.0 + PI / n, TAU)
		roda_triada = int(angle / TAU * n) % n
	roda.queue_redraw()

func _dibuixar_roda():
	var centre := roda.get_viewport_rect().size / 2.0
	var n := roda_opcions.size()
	var radi := 150.0
	var font := ThemeDB.fallback_font
	roda.draw_circle(centre, radi + 46.0, Color(0, 0, 0, 0.45))
	roda.draw_circle(centre, 42.0, Color(0, 0, 0, 0.55))
	var actiu := eina_activa()
	for i in n:
		var id: String = roda_opcions[i]
		var angle := -PI / 2.0 + TAU * i / n
		var p := centre + Vector2.from_angle(angle) * radi
		var triada := i == roda_triada
		var d := info(id) if not id.is_empty() else {"nom": "Mans buides", "icona": "✋", "color": Color(0.9, 0.9, 0.9)}
		roda.draw_circle(p, 38.0 if triada else 32.0, Color(0.1, 0.09, 0.14, 0.92))
		roda.draw_arc(p, 38.0 if triada else 32.0, 0, TAU, 32, d.color if triada or id == actiu else Color(1, 1, 1, 0.25), 4.0 if triada else 2.0)
		var mida := 34 if triada else 28
		var w := font.get_string_size(d.icona, HORIZONTAL_ALIGNMENT_LEFT, -1, mida).x
		roda.draw_string(font, p + Vector2(-w / 2.0, mida * 0.35), d.icona, HORIZONTAL_ALIGNMENT_LEFT, -1, mida)
		if mostra_quantitat(id):
			var q := str(Inventari.tenir(id))
			roda.draw_string_outline(font, p + Vector2(14, 26), q, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
			roda.draw_string(font, p + Vector2(14, 26), q, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	# Nom de la triada, al mig
	if roda_triada >= 0:
		var id: String = roda_opcions[roda_triada]
		var nom: String = "Mans buides" if id.is_empty() else info(id).nom
		var w := font.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		roda.draw_string_outline(font, centre + Vector2(-w / 2.0, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		roda.draw_string(font, centre + Vector2(-w / 2.0, 6), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)

# ─────────────── Desat

func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"caselles": caselles}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.get("caselles") is Array and d.caselles.size() == CASELLES:
		caselles = d.caselles.map(func(x):
			var id: String = NOMS_ANTICS.get(str(x), str(x))
			return id if es_pot_posar(id) else "")
