extends CanvasLayer
class_name ExcavacioQTE
## Minijoc d'excavació delicada (per als fòssils i tresors importants). Atura el joc.
##
## Una paret de terra a capes amaga la troballa. Treu la terra fins que la troballa
## quedi destapada del tot:
##   - Clic esquerre: pinzell. Treu una capa d'una casella. Gasta poca estabilitat.
##   - Clic dret: aixada. Treu dues capes al mig i una al voltant. Gasta molta estabilitat.
## Si l'estabilitat arriba a zero, la paret s'esfondra i la troballa s'esmicola.
## Acabar amb més de la meitat d'estabilitat és una excavació impecable.

signal acabat(exit: bool, impecable: bool)

const COLS := 11
const FILES := 7
const CASELLA := 52.0
const COST_PINZELL := 2.0
const COST_AIXADA := 7.0
const ESTABILITAT := 100.0

const COLORS_CAPA := [Color(0, 0, 0, 0), Color(0.62, 0.45, 0.3), Color(0.5, 0.35, 0.22), Color(0.38, 0.26, 0.16), Color(0.28, 0.19, 0.12)]

var boti: Dictionary
var info: Dictionary
var capes := []          # [fila][col] -> capes que queden (0 = destapada)
var troballa := {}       # Vector2i -> true (les caselles on hi ha la troballa)
var estabilitat := ESTABILITAT
var estabilitat_max := ESTABILITAT
var acabat_ja := false

var graella: Control
var barra: ProgressBar
var label_titol: Label
var label_estat: Label
var tremolor := 0.0
var pols := []           # partícules de pols: [{p, v, vida, color}]
var revelada := false

static func comencar(arbre: SceneTree, p_boti: Dictionary) -> ExcavacioQTE:
	var q := ExcavacioQTE.new()
	q.boti = p_boti
	arbre.root.add_child(q)
	return q

func _ready():
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	info = {"nom": "Monedes", "icona": "🪙"} if boti.id == "diners" else CatalegObjectes.info(boti.id)
	# Les llegendàries tenen més capes, però també una mica més de marge
	estabilitat_max = ESTABILITAT + boti.raresa * 25.0
	estabilitat = estabilitat_max
	_generar()
	_construir_ui()

## Capes de terra (més gruixudes com més rara) i la forma de la troballa
func _generar():
	var soroll := FastNoiseLite.new()
	soroll.seed = randi()
	soroll.frequency = 0.25
	var gruix: int = 2 + int(boti.raresa)
	for f in FILES:
		var fila := []
		for c in COLS:
			var n := (soroll.get_noise_2d(c, f) + 1.0) / 2.0
			fila.append(clampi(int(round(1.0 + n * (gruix - 1) + randf_range(-0.4, 0.4))), 1, 4))
		capes.append(fila)
	# La troballa: una taca contínua de 6 a 11 caselles, lluny de les vores
	var mida := 6 + int(boti.raresa) * 2 + randi() % 3
	var inici := Vector2i(randi_range(3, COLS - 4), randi_range(2, FILES - 3))
	troballa[inici] = true
	var intents := 0
	while troballa.size() < mida and intents < 200:
		intents += 1
		var base: Vector2i = troballa.keys()[randi() % troballa.size()]
		var v: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][randi() % 4]
		var nova := base + v
		if nova.x >= 1 and nova.y >= 1 and nova.x < COLS - 1 and nova.y < FILES - 1:
			troballa[nova] = true

func _construir_ui():
	var fons := ColorRect.new()
	fons.color = Color(0.03, 0.02, 0.02, 0.6)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	fons.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	centre.add_child(columna)
	label_titol = _label("Excavació delicada: alguna cosa %s!" % PartFossil.NOMS_RARESA[boti.raresa], 26, PartFossil.COLORS_RARESA[boti.raresa])
	columna.add_child(label_titol)
	var fila_barra := HBoxContainer.new()
	fila_barra.add_theme_constant_override("separation", 10)
	columna.add_child(fila_barra)
	fila_barra.add_child(_label("Estabilitat", 16, Color(0.95, 0.9, 0.8)))
	barra = ProgressBar.new()
	barra.max_value = estabilitat_max
	barra.value = estabilitat_max
	barra.show_percentage = false
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.custom_minimum_size = Vector2(0, 18)
	fila_barra.add_child(barra)
	_pintar_barra()
	graella = Control.new()
	graella.custom_minimum_size = Vector2(COLS * CASELLA, FILES * CASELLA)
	graella.mouse_filter = Control.MOUSE_FILTER_STOP
	graella.gui_input.connect(_clic)
	graella.draw.connect(_dibuixar)
	columna.add_child(graella)
	label_estat = _label("Clic: 🖌️ pinzell (suau)   ·   Clic dret: ⛏ aixada (treu més, però fa trontollar)", 15, Color(0.9, 0.88, 0.95))
	columna.add_child(label_estat)

func _label(text: String, mida: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l

func _pintar_barra():
	var ple := StyleBoxFlat.new()
	var f := estabilitat / estabilitat_max
	ple.bg_color = Color(0.9, 0.3, 0.25).lerp(Color(0.55, 0.85, 0.45), f)
	ple.set_corner_radius_all(5)
	var buit := StyleBoxFlat.new()
	buit.bg_color = Color(0, 0, 0, 0.5)
	buit.set_corner_radius_all(5)
	barra.add_theme_stylebox_override("fill", ple)
	barra.add_theme_stylebox_override("background", buit)

# ─────────────── Entrada

func _input(event: InputEvent):
	# Mentre dura, cap altra cosa (ni pausa ni atacs)
	if event is InputEventKey:
		get_viewport().set_input_as_handled()

func _clic(event: InputEvent):
	if acabat_ja or not (event is InputEventMouseButton and event.pressed):
		return
	var c := Vector2i(int(event.position.x / CASELLA), int(event.position.y / CASELLA))
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= FILES:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		pinzell(c)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		aixada(c)

func pinzell(c: Vector2i):
	if capes[c.y][c.x] <= 0:
		return
	_treure(c, 1)
	_gastar(COST_PINZELL, 0.15)
	_comprovar()

func aixada(c: Vector2i):
	_treure(c, 2)
	for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_treure(c + v, 1)
	_gastar(COST_AIXADA, 0.6)
	_comprovar()

func _treure(c: Vector2i, quantes: int):
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= FILES or capes[c.y][c.x] <= 0:
		return
	var abans: int = capes[c.y][c.x]
	capes[c.y][c.x] = maxi(0, abans - quantes)
	var centre := (Vector2(c) + Vector2(0.5, 0.5)) * CASELLA
	for i in 5 + quantes * 3:
		pols.append({"p": centre + Vector2(randf_range(-14, 14), randf_range(-14, 14)), "v": Vector2(randf_range(-90, 90), randf_range(-160, -40)), "vida": randf_range(0.3, 0.6), "color": COLORS_CAPA[abans]})
	if capes[c.y][c.x] == 0 and troballa.has(c):
		# Una casella de la troballa al descobert: una guspira
		for i in 6:
			pols.append({"p": centre, "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 150), "vida": 0.5, "color": PartFossil.COLORS_RARESA[boti.raresa]})

func _gastar(quant: float, sacseig: float):
	estabilitat = maxf(0.0, estabilitat - quant)
	tremolor = maxf(tremolor, sacseig)
	barra.value = estabilitat
	_pintar_barra()
	if estabilitat <= 25.0 and estabilitat > 0.0:
		label_estat.text = "Compte, la paret trontolla!"
		label_estat.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

func _comprovar():
	var tot := troballa.keys().all(func(c): return capes[c.y][c.x] == 0)
	if tot:
		_final(true)
	elif estabilitat <= 0.0:
		_final(false)

func _final(exit: bool):
	acabat_ja = true
	revelada = true
	var impecable := exit and estabilitat >= estabilitat_max * 0.5
	if exit:
		label_titol.text = "%s %s!" % [info.icona, info.nom]
		label_estat.text = "Excavació impecable! ✨" if impecable else "L'has desenterrat sencer!"
		label_estat.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		for i in 40:
			pols.append({"p": graella.size / 2.0, "v": Vector2.from_angle(randf() * TAU) * randf_range(100, 380), "vida": randf_range(0.5, 1.0), "color": PartFossil.COLORS_RARESA[boti.raresa]})
	else:
		label_titol.text = "La paret s'ha esfondrat..."
		label_estat.text = "La troballa s'ha esmicolat"
		tremolor = 1.5
		for f in FILES:
			for c in COLS:
				capes[f][c] = maxi(capes[f][c], 2)
	await get_tree().create_timer(1.6, true, false, true).timeout
	get_tree().paused = false
	acabat.emit(exit, impecable)
	queue_free()

# ─────────────── Dibuix

func _process(delta):
	tremolor = maxf(0.0, tremolor - delta * 2.5)
	for p in pols:
		p.p += p.v * delta
		p.v.y += 500.0 * delta
		p.vida -= delta
	pols = pols.filter(func(p): return p.vida > 0.0)
	graella.queue_redraw()

func _dibuixar():
	var sacseig := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * tremolor * 6.0
	var font := ThemeDB.fallback_font
	graella.draw_rect(Rect2(sacseig, graella.size), Color(0.18, 0.12, 0.08))
	var color_troballa: Color = PartFossil.COLORS_RARESA[boti.raresa]
	var color_os := Color(0.93, 0.88, 0.76) if boti.tipus == "fossil" else Color(1.0, 0.82, 0.35)
	for f in FILES:
		for c in COLS:
			var r := Rect2(Vector2(c, f) * CASELLA + sacseig, Vector2(CASELLA, CASELLA)).grow(-1.0)
			var capa: int = capes[f][c]
			var cel := Vector2i(c, f)
			if capa == 0:
				if troballa.has(cel):
					graella.draw_rect(r, color_os)
					graella.draw_rect(r.grow(-6.0), color_os.darkened(0.08))
					graella.draw_rect(r, color_troballa, false, 2.0)
				else:
					graella.draw_rect(r, Color(0.12, 0.08, 0.05))
			else:
				graella.draw_rect(r, COLORS_CAPA[capa])
				# Textura de terra: uns quants grumolls fixos per casella
				var rr := RandomNumberGenerator.new()
				rr.seed = c * 31 + f * 17 + capa
				for k in 4:
					var p := r.position + Vector2(rr.randf_range(6, CASELLA - 10), rr.randf_range(6, CASELLA - 10))
					graella.draw_rect(Rect2(p, Vector2(4, 4)), COLORS_CAPA[capa].darkened(0.2))
				# Quan s'acaba: la silueta de la troballa sota la terra
				if revelada and troballa.has(cel):
					graella.draw_rect(r, Color(color_os, 0.35))
	# Contorn de la troballa quan ja surt
	if revelada:
		var amplada := font.get_string_size(info.icona, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		var centre := Vector2.ZERO
		for c in troballa:
			centre += (Vector2(c) + Vector2(0.5, 0.5)) * CASELLA
		centre /= troballa.size()
		graella.draw_string_outline(font, centre + Vector2(-amplada / 2.0, 22.0), info.icona, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 10, Color(0, 0, 0, 0.7))
		graella.draw_string(font, centre + Vector2(-amplada / 2.0, 22.0), info.icona, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
	for p in pols:
		graella.draw_rect(Rect2(p.p - Vector2(2, 2), Vector2(4, 4)), Color(p.color, clampf(p.vida * 2.0, 0.0, 1.0)))
