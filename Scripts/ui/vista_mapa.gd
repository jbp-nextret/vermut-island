extends Control
class_name VistaMapa
## Dibuixa el mapa (terreny + boira + marcadors) amb zoom i desplaçament.
## Coordenades: x del món → dreta, z del món → avall (el nord, -Z, a dalt).

const ZOOM_MIN := 2.5
const ZOOM_MAX := 14.0

var mapa: Node          # l'autoload Mapa (d'on treu les textures i els marcadors)
var zoom := 5.0         # píxels de pantalla per metre
var centre := Vector2.ZERO   # punt del món al mig de la vista
var arrossegant := false
var temps := 0.0
var destacat := ""      # id de la missió seleccionada (fa pampallugues)

func _ready():
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta):
	if is_visible_in_tree():
		temps += delta
		queue_redraw()

func centrar(punt: Vector2, destacar := false):
	centre = punt
	if destacar:
		zoom = maxf(zoom, 6.0)
	destacat = ""
	if destacar:
		for mk in mapa.marcadors:
			if mk.tipus == "objectiu" and mk.pos == punt:
				destacat = mk.id
	queue_redraw()

func a_pantalla(p: Vector2) -> Vector2:
	return size / 2.0 + (p - centre) * zoom

func al_mon(p: Vector2) -> Vector2:
	return centre + (p - size / 2.0) / zoom

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			# Zoom cap on apunta el ratolí
			var abans := al_mon(event.position)
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), ZOOM_MIN, ZOOM_MAX)
			centre += abans - al_mon(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			arrossegant = event.pressed
			accept_event()
	elif event is InputEventMouseMotion and arrossegant:
		centre -= event.relative / zoom
		_limitar()
		accept_event()

func _limitar():
	var meitat: float = mapa.MIDA / 2.0
	centre = centre.clamp(Vector2(-meitat, -meitat), Vector2(meitat, meitat))

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), mapa.C_BOIRA)
	if mapa.textura_terreny == null:
		return
	var mida := Vector2(mapa.MIDA, mapa.MIDA)
	var rect := Rect2(a_pantalla(-Vector2(mapa.ORIGEN)), mida * zoom)
	draw_texture_rect(mapa.textura_terreny, rect, false)
	draw_texture_rect(mapa.textura_boira, rect, false)
	_quadricula()

	var font := ThemeDB.fallback_font
	for mk in mapa.marcadors:
		var p := a_pantalla(mk.pos)
		match mk.tipus:
			"casa":
				if mapa.explorat_a(mk.pos):
					_casa(p)
			"barca":
				if mapa.explorat_a(mk.pos):
					_barca(p)
			"npc":
				if mapa.explorat_a(mk.pos):
					draw_circle(p, 4.0, Color(0.95, 0.9, 0.8))
					draw_arc(p, 4.0, 0, TAU, 16, Color(0.1, 0.1, 0.1), 1.5)
					if zoom >= 5.5:
						_text(font, p + Vector2(0, -9), mk.text, 13, Color(1, 1, 1, 0.9))
					if mk.marca in ["!", "?"]:
						_text(font, p + Vector2(10, 2), mk.marca, 20, Color(1.0, 0.85, 0.2))
	# Criatures de cada illa (també a la boira: el "?" convida a anar-hi)
	for mk in mapa.marcadors:
		if mk.tipus == "criatures":
			_criatures(a_pantalla(mk.pos), mk.especies)
	# Objectius de missió: sempre (encara que no s'hagi explorat), per sobre de tot
	for mk in mapa.marcadors:
		if mk.tipus == "objectiu":
			_objectiu(a_pantalla(mk.pos), mk.id == destacat)
	_jugador(a_pantalla(mapa.pos_jugador))
	# Fora de la vista: una fletxa a la vora cap a l'objectiu
	for mk in mapa.marcadors:
		if mk.tipus == "objectiu":
			_fletxa_vora(a_pantalla(mk.pos))

func _quadricula():
	# Una línia cada 16 m, molt suau, per tenir referència de distàncies
	var color := Color(1, 1, 1, 0.05)
	var meitat: int = mapa.MIDA / 2
	for i in range(-meitat, meitat + 1, 16):
		draw_line(a_pantalla(Vector2(i, -meitat)), a_pantalla(Vector2(i, meitat)), color)
		draw_line(a_pantalla(Vector2(-meitat, i)), a_pantalla(Vector2(meitat, i)), color)

func _text(font: Font, p: Vector2, text: String, mida: int, color: Color):
	var amplada := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, mida).x
	draw_string_outline(font, p - Vector2(amplada / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, mida, 4, Color(0, 0, 0, 0.8))
	draw_string(font, p - Vector2(amplada / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, mida, color)

func _jugador(p: Vector2):
	# Con de visió de la càmera i el punt
	var d: Vector2 = mapa.dir_camera
	var con := PackedVector2Array([p, p + d.rotated(-0.45) * 34.0, p + d.rotated(0.45) * 34.0])
	draw_colored_polygon(con, Color(1, 1, 1, 0.18))
	var pols := 1.0 + 0.15 * sin(temps * 5.0)
	draw_circle(p, 7.0 * pols, Color(0, 0, 0, 0.6))
	draw_circle(p, 5.0 * pols, Color(0.35, 0.8, 1.0))
	draw_circle(p, 2.0, Color.WHITE)

func _objectiu(p: Vector2, destacat_ara: bool):
	var pols := 0.5 + 0.5 * sin(temps * 4.0)
	draw_arc(p, 10.0 + pols * 6.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, 0.7 - pols * 0.5), 2.0)
	if destacat_ara:
		draw_arc(p, 20.0 + pols * 4.0, 0, TAU, 32, Color(1.0, 0.95, 0.6, 0.8), 2.0)
	var r := 7.0
	var rombe := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	draw_colored_polygon(rombe, Color(1.0, 0.82, 0.15))
	rombe.append(rombe[0])
	draw_polyline(rombe, Color(0.25, 0.15, 0.0), 1.5)

func _criatures(p: Vector2, ids: Array):
	const MIDA := 22.0
	var font := ThemeDB.fallback_font
	var inici := p - Vector2((ids.size() * (MIDA + 3.0) - 3.0) / 2.0, MIDA / 2.0)
	for i in ids.size():
		var e: EspecieCriatura = Criatures.especie(ids[i])
		var r := Rect2(inici + Vector2(i * (MIDA + 3.0), 0), Vector2(MIDA, MIDA))
		var c := r.get_center()
		var vista := Criatures.vista(e.id)
		draw_circle(c, MIDA * 0.62, Color(0, 0, 0, 0.55))
		draw_circle(c, MIDA * 0.55, Color(0.95, 0.88, 0.72) if vista else Color(0.25, 0.22, 0.32))
		if vista:
			draw_texture_rect(e.textura(), r.grow(-2.0), false)
			if Criatures.domesticada(e.id):
				draw_arc(c, MIDA * 0.55, 0, TAU, 20, Color(1.0, 0.55, 0.7), 2.0)
		else:
			var amplada := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, c + Vector2(-amplada / 2.0, 6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3))

func _casa(p: Vector2):
	var c := Color(0.85, 0.45, 0.3)
	draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 9)), Color(0.95, 0.88, 0.75))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(0, -10), p + Vector2(8, -2)]), c)
	draw_rect(Rect2(p + Vector2(-2, 2), Vector2(4, 5)), Color(0.4, 0.25, 0.15))

func _barca(p: Vector2):
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -2), p + Vector2(8, -2), p + Vector2(5, 4), p + Vector2(-5, 4)]), Color(0.6, 0.4, 0.22))
	draw_line(p + Vector2(0, -2), p + Vector2(0, -11), Color(0.3, 0.2, 0.1), 1.5)
	draw_colored_polygon(PackedVector2Array([p + Vector2(1, -11), p + Vector2(7, -4), p + Vector2(1, -4)]), Color(0.95, 0.95, 0.9))

func _fletxa_vora(p: Vector2):
	var marge := 18.0
	var dins := Rect2(Vector2(marge, marge), size - Vector2(marge, marge) * 2.0)
	if dins.has_point(p):
		return
	var mig := size / 2.0
	var d := (p - mig).normalized()
	# On talla la vora
	var t := INF
	if absf(d.x) > 0.001:
		t = minf(t, (dins.size.x / 2.0) / absf(d.x))
	if absf(d.y) > 0.001:
		t = minf(t, (dins.size.y / 2.0) / absf(d.y))
	var q := mig + d * t
	var punta := PackedVector2Array([q + d * 10.0, q + d.rotated(2.4) * 9.0, q + d.rotated(-2.4) * 9.0])
	draw_colored_polygon(punta, Color(1.0, 0.82, 0.15))
	punta.append(punta[0])
	draw_polyline(punta, Color(0.25, 0.15, 0.0), 1.5)
