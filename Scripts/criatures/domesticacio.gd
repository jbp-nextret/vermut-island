extends CanvasLayer
class_name Domesticacio
## El minijoc per domesticar una criatura (atura el joc mentre dura).
##
## Una agulla gira al voltant d'un anell. Prem Espai, F o clic quan passi per la zona
## daurada (al centre, la part més brillant, és un "Perfecte!" que compta més).
## Cada encert omple la confiança, mou la zona, accelera l'agulla i a vegades li
## canvia el sentit. Tres errades (o deixar passar la zona massa estona) i s'escapa.
## Més força = més encerts i zona més petita; debilitada o menjant = zona més gran.

const VIDES := 3
const RADI := 120.0
const GRUIX := 16.0
const MARGE_TEMPS := 400.0   # graus que pot girar l'agulla sense prémer abans de comptar com a errada

var criatura: Criatura
var especie: EspecieCriatura

var angle := -90.0           # agulla (graus, 0 = dreta, -90 = dalt)
var velocitat := 150.0       # graus/s
var sentit := 1.0
var zona := 90.0             # centre de la zona
var meitat_zona := 30.0
var girat := 0.0             # graus des de la darrera zona
var confianca := 0.0         # 0..1
var encerts_necessaris := 4
var vides := VIDES
var combo := 0
var acabat := false
var pausa_inici := 0.5

# Efectes
var pols := 0.0              # l'anell batega en encertar
var tremolor := 0.0          # i tremola en errar
var flash_color := Color.TRANSPARENT
var guspires: Array = []     # [{p, v, vida, color}]
var textos: Array = []       # [{text, vida, color, mida}]

var anell: Control
var imatge: TextureRect
var barra: ProgressBar
var label_vides: Label
var label_titol: Label
var label_ajuda: Label

static func comencar(c: Criatura) -> Domesticacio:
	var d := Domesticacio.new()
	d.criatura = c
	d.especie = c.especie
	c.get_tree().root.add_child(d)
	return d

func _ready():
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	encerts_necessaris = 3 + especie.forca
	var facilitat := 1.0
	if criatura.debilitada():
		facilitat += 0.3
	if criatura.estat == Criatura.Estat.MENJANT or criatura.esquer != null:
		facilitat += 0.15
	meitat_zona = (34.0 - especie.forca * 3.0) * facilitat
	velocitat = 140.0 + especie.forca * 12.0
	zona = angle + 150.0 + randf() * 60.0
	_construir_ui()

func _construir_ui():
	var fons := ColorRect.new()
	fons.color = Color(0.03, 0.02, 0.06, 0.55)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	fons.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var columna := VBoxContainer.new()
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.add_theme_constant_override("separation", 8)
	centre.add_child(columna)

	label_titol = _label("Domesticant: %s" % especie.nom, 28, Color(1.0, 0.88, 0.6))
	columna.add_child(label_titol)
	anell = Control.new()
	anell.custom_minimum_size = Vector2(RADI * 2.0 + 80.0, RADI * 2.0 + 80.0)
	anell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anell.draw.connect(_dibuixar)
	columna.add_child(anell)
	imatge = TextureRect.new()
	imatge.texture = especie.textura()
	imatge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imatge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imatge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imatge.size = Vector2(120, 120)
	imatge.pivot_offset = imatge.size / 2.0
	imatge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anell.add_child(imatge)

	barra = ProgressBar.new()
	barra.custom_minimum_size = Vector2(RADI * 2.0, 18)
	barra.max_value = 1.0
	barra.step = 0.001
	barra.show_percentage = false
	var ple := StyleBoxFlat.new()
	ple.bg_color = Color(1.0, 0.55, 0.7)
	ple.set_corner_radius_all(6)
	var buit := StyleBoxFlat.new()
	buit.bg_color = Color(0, 0, 0, 0.5)
	buit.set_corner_radius_all(6)
	barra.add_theme_stylebox_override("fill", ple)
	barra.add_theme_stylebox_override("background", buit)
	columna.add_child(barra)
	label_vides = _label("", 22, Color.WHITE)
	columna.add_child(label_vides)
	label_ajuda = _label("Espai · F · Clic quan l'agulla passi per la zona daurada", 15, Color(0.85, 0.85, 0.95))
	columna.add_child(label_ajuda)
	_actualitzar_vides()

func _label(text: String, mida: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l

func _actualitzar_vides():
	label_vides.text = "Paciència: " + "💜".repeat(vides) + "🖤".repeat(VIDES - vides)

# ─────────────── Entrada

func _input(event: InputEvent):
	if acabat:
		get_viewport().set_input_as_handled()
		return
	var prem := event.is_action_pressed("interactuar") or event.is_action_pressed("jump") or event.is_action_pressed("accio_primaria")
	if prem and not event.is_echo():
		_premer()
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()   # ni pausa ni atacs mentre domestiques

func _premer():
	if pausa_inici > 0.0:
		return
	var diferencia := absf(angle_difference(deg_to_rad(angle), deg_to_rad(zona)))
	diferencia = rad_to_deg(diferencia)
	if diferencia <= meitat_zona * 0.35:
		_encert(true)
	elif diferencia <= meitat_zona:
		_encert(false)
	else:
		_errada("Massa d'hora!" if angle_difference(deg_to_rad(angle), deg_to_rad(zona)) * sentit > 0.0 else "Massa tard!")

func _encert(perfecte: bool):
	combo += 1
	var guany := (1.6 if perfecte else 1.0) / float(encerts_necessaris)
	if combo >= 3 and perfecte:
		guany *= 1.25
	confianca = minf(1.0, confianca + guany)
	pols = 1.0
	flash_color = Color(1.0, 0.9, 0.4, 0.6) if perfecte else Color(1.0, 1.0, 1.0, 0.35)
	var text := "Perfecte!" if perfecte else "Bé!"
	if combo >= 3:
		text += "  x%d" % combo
	_text(text, Color(1.0, 0.85, 0.25) if perfecte else Color(0.8, 1.0, 0.8), 34 if perfecte else 26)
	_guspires(_punt_anell(zona), Color(1.0, 0.8, 0.3) if perfecte else Color(1, 1, 1), 22 if perfecte else 10)
	_bot_criatura(1.25 if perfecte else 1.12)
	if confianca >= 1.0:
		_guanyar()
		return
	# Següent: la zona salta lluny, l'agulla va més ràpida i potser canvia de sentit
	velocitat = minf(velocitat * 1.09, 420.0)
	meitat_zona = maxf(meitat_zona * 0.95, 11.0)
	if confianca > 0.35 and randf() < 0.45:
		sentit = -sentit
	zona = angle + sentit * randf_range(110.0, 250.0)
	girat = 0.0

func _errada(text: String):
	combo = 0
	vides -= 1
	tremolor = 1.0
	flash_color = Color(1.0, 0.25, 0.25, 0.45)
	_text(text, Color(1.0, 0.45, 0.4), 26)
	_actualitzar_vides()
	var t := imatge.create_tween()
	t.tween_property(imatge, "rotation", 0.25, 0.05)
	t.tween_property(imatge, "rotation", -0.25, 0.08)
	t.tween_property(imatge, "rotation", 0.0, 0.06)
	if vides <= 0:
		_perdre()
		return
	zona = angle + sentit * randf_range(120.0, 240.0)
	girat = 0.0

func _guanyar():
	acabat = true
	label_titol.text = "%s confia en tu! ❤" % especie.nom
	label_ajuda.text = ""
	for i in 3:
		_guspires(anell.size / 2.0 + Vector2(randf_range(-60, 60), randf_range(-60, 60)), Color(1.0, 0.55, 0.75), 18)
	_bot_criatura(1.4)
	_tancar(true, 1.3)

func _perdre():
	acabat = true
	label_titol.text = "%s s'ha escapat..." % especie.nom
	label_ajuda.text = ""
	var t := imatge.create_tween()
	t.tween_property(imatge, "position:x", imatge.position.x + 300.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(imatge, "modulate:a", 0.0, 0.6)
	_tancar(false, 1.1)

func _tancar(exit: bool, despres: float):
	await get_tree().create_timer(despres, true, false, true).timeout
	get_tree().paused = false
	if is_instance_valid(criatura):
		criatura.resultat_domesticacio(exit)
	if exit:
		var dades: Dictionary = Criatures.col_leccio.back() if not Criatures.col_leccio.is_empty() else {}
		var segueix: bool = Criatures.activa == dades.get("uid", "")
		EventBus.avis.emit("%s s'uneix a tu!" % especie.nom if segueix else "%s és a la teva col·lecció (Motxilla → Criatures)" % especie.nom)
	queue_free()

# ─────────────── Cada frame

func _process(delta):
	if pausa_inici > 0.0:
		pausa_inici -= delta
	elif not acabat:
		var pas: float = velocitat * delta
		angle += pas * sentit
		girat += pas
		# Ha deixat passar la zona massa estona
		if girat > MARGE_TEMPS:
			_errada("Massa lent!")
	pols = maxf(0.0, pols - delta * 4.0)
	tremolor = maxf(0.0, tremolor - delta * 3.0)
	flash_color.a = maxf(0.0, flash_color.a - delta * 1.5)
	barra.value = lerpf(barra.value, confianca, minf(1.0, delta * 10.0))
	for g in guspires:
		g.p += g.v * delta
		g.v.y += 300.0 * delta
		g.vida -= delta
	guspires = guspires.filter(func(g): return g.vida > 0.0)
	for t in textos:
		t.vida -= delta
	textos = textos.filter(func(t): return t.vida > 0.0)
	imatge.position = anell.size / 2.0 - imatge.size / 2.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * tremolor * 6.0
	anell.queue_redraw()

func _punt_anell(graus: float, radi := RADI) -> Vector2:
	return anell.size / 2.0 + Vector2.from_angle(deg_to_rad(graus)) * radi

func _dibuixar():
	var c := anell.size / 2.0 + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * tremolor * 8.0
	var r := RADI * (1.0 + pols * 0.06)
	# Halo i pista
	if flash_color.a > 0.0:
		anell.draw_circle(c, r + GRUIX * 2.0, flash_color)
	anell.draw_circle(c, r + GRUIX, Color(0.06, 0.05, 0.1, 0.9))
	anell.draw_arc(c, r, 0, TAU, 96, Color(0.3, 0.27, 0.4), GRUIX)
	# Zona bona i, al mig, la perfecta
	var z := deg_to_rad(zona)
	var mz := deg_to_rad(meitat_zona)
	anell.draw_arc(c, r, z - mz, z + mz, 32, Color(1.0, 0.75, 0.25, 0.85), GRUIX)
	anell.draw_arc(c, r, z - mz * 0.35, z + mz * 0.35, 16, Color(1.0, 0.97, 0.7), GRUIX + 4.0)
	# Progrés de la confiança, per dins
	anell.draw_arc(c, r - GRUIX - 6.0, -PI / 2.0, -PI / 2.0 + TAU * barra.value, 64, Color(1.0, 0.55, 0.7, 0.8), 5.0)
	# Agulla
	var a := deg_to_rad(angle)
	var punta := c + Vector2.from_angle(a) * (r + GRUIX)
	var base := c + Vector2.from_angle(a) * (r - GRUIX * 1.6)
	anell.draw_line(base, punta, Color(0, 0, 0, 0.6), 9.0)
	anell.draw_line(base, punta, Color.WHITE, 5.0)
	anell.draw_circle(punta, 6.0, Color.WHITE)
	# Guspires i textos
	for g in guspires:
		anell.draw_circle(g.p, 3.0 * clampf(g.vida * 2.0, 0.3, 1.0), Color(g.color, clampf(g.vida * 2.0, 0.0, 1.0)))
	var font := ThemeDB.fallback_font
	for t in textos:
		var alfa := clampf(t.vida * 2.0, 0.0, 1.0)
		var pujada: float = (1.0 - t.vida) * 40.0
		var mida: int = t.mida
		var amplada := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, mida).x
		var p := Vector2(c.x - amplada / 2.0, c.y - r - 30.0 - pujada)
		anell.draw_string_outline(font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, mida, 6, Color(0, 0, 0, alfa * 0.8))
		anell.draw_string(font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, mida, Color(t.color, alfa))

func _guspires(p: Vector2, color: Color, quantes: int):
	for i in quantes:
		guspires.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(80, 260) + Vector2.UP * 80.0, "vida": randf_range(0.4, 0.8), "color": color})

func _text(text: String, color: Color, mida: int):
	textos.clear()
	textos.append({"text": text, "vida": 1.0, "color": color, "mida": mida})

func _bot_criatura(escala: float):
	var t := imatge.create_tween()
	t.tween_property(imatge, "scale", Vector2(escala, 2.0 - escala), 0.06)
	t.tween_property(imatge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
