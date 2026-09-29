extends Node3D
class_name Plantador
## Tot el mode plantar:
##  - P tocada: entra/surt del mode plantar. P mantinguda: roda per triar cultiu.
##  - El cursor segueix la graella de l'hort. El raig NO xoca amb el jugador ni amb
##    els enemics, i si el ratolí és sobre un cultiu, se selecciona la seva cel·la.
##  - Vista prèvia del cultiu (verda o vermella) i, segons el tipus:
##      · torres a distància: cercle d'abast
##      · la resta: s'acoloreixen les cel·les de l'àrea i els cultius afectats
##  - Clic: planta en aquesta cel·la. Arrossegant: selecciona una àrea i en deixar anar
##    s'hi planta (clic dret o Esc durant l'arrossegament: cancel·la). Clic dret / Esc: surt.
##  - Q / E: cultiu anterior / següent (amb un avís a la pantalla i sobre el cursor).

signal seleccio_canviada(index: int)
signal mode_canviat(actiu: bool)
signal avis(text: String)
signal canviat_amb_tecla(index: int, direccio: int)

const LLAVOR := "llavor_raim"
const LLINDAR_RODA := 0.25
const COLOR_VALID := Color(0.3, 1.0, 0.4)
const COLOR_INVALID := Color(1.0, 0.3, 0.3)
## Alçada de cada línia de text a la pantalla (en píxels del joc), sigui quin sigui el zoom
const LINIA_INFO_PX := 13.0
const LINIA_CANVI_PX := 16.0
const SEPARACIO_PX := 8.0   # distància entre el cultiu i la seva etiqueta
const MIDA_MAXIMA_AREA := 12  # cel·les per costat

var mon: Node3D
var gridmap: GridMap
var roda
var cursor: MeshInstance3D
var blocs_plantables: Array

var opcions: Array = []
var index := 0
var actiu := false
var cella: Dictionary = {}          # {cella, posicio, superficie, valida, motiu}
var cultiu_sota_ratoli: Node3D = null
# Selecció per àrea
var arrossegant := false
var inici_area: Dictionary = {}
var seleccio_area: Array = []
var quads_seleccio: Array[MeshInstance3D] = []
var fantasmes_seleccio: Array[Sprite3D] = []
var etiqueta_area: Label3D
var material_seleccio_ok := StandardMaterial3D.new()
var material_seleccio_ko := StandardMaterial3D.new()

var prement_p := false
var temps_p := 0.0
var roda_oberta := false

var fantasma: Sprite3D
var anell: AnellAbast
var cel_les_area: Array[MeshInstance3D] = []
var ressaltats: Array = []
var etiqueta_info: Label3D
var etiqueta_canvi: Label3D
var tween_canvi: Tween
var unitats_per_pixel := 0.02
var material_cella := StandardMaterial3D.new()

func configurar(p_mon: Node3D, p_gridmap: GridMap, p_roda, p_cursor: MeshInstance3D, p_blocs: Array) -> void:
	mon = p_mon
	gridmap = p_gridmap
	roda = p_roda
	cursor = p_cursor
	blocs_plantables = p_blocs

func _ready():
	opcions = CatalegCultius.opcions_roda()

	fantasma = Sprite3D.new()
	fantasma.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	fantasma.shaded = false
	fantasma.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fantasma.visible = false
	fantasma.top_level = true
	add_child(fantasma)

	anell = AnellAbast.new()
	anell.top_level = true
	anell.visible = false
	add_child(anell)

	etiqueta_info = Label3D.new()
	etiqueta_info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta_info.no_depth_test = true
	etiqueta_info.font_size = 64
	etiqueta_info.outline_size = 16
	etiqueta_info.pixel_size = 0.0065
	etiqueta_info.line_spacing = -4.0
	etiqueta_info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta_info.top_level = true
	etiqueta_info.visible = false
	add_child(etiqueta_info)

	etiqueta_canvi = Label3D.new()
	etiqueta_canvi.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta_canvi.no_depth_test = true
	etiqueta_canvi.font_size = 72
	etiqueta_canvi.outline_size = 18
	etiqueta_canvi.pixel_size = 0.0065
	etiqueta_canvi.top_level = true
	etiqueta_canvi.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta_canvi.visible = false
	add_child(etiqueta_canvi)

	etiqueta_area = Label3D.new()
	etiqueta_area.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta_area.no_depth_test = true
	etiqueta_area.font_size = 64
	etiqueta_area.outline_size = 16
	etiqueta_area.top_level = true
	etiqueta_area.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	etiqueta_area.visible = false
	add_child(etiqueta_area)

	for m in [material_seleccio_ok, material_seleccio_ko]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_seleccio_ok.albedo_color = Color(COLOR_VALID, 0.35)
	material_seleccio_ko.albedo_color = Color(COLOR_INVALID, 0.35)

	material_cella.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_cella.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_cella.cull_mode = BaseMaterial3D.CULL_DISABLED

	Inventari.items_canviats.connect(func(): seleccio_canviada.emit(index))

# ─────────────── Dades

func opcio() -> Dictionary:
	return opcions[index]

func escena() -> PackedScene:
	return CatalegCultius.TOTS[index]

func llavors() -> int:
	return Inventari.tenir(LLAVOR)

# ─────────────── Entrada

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.pot_atacar():   # dins de casa o construint, res
		return
	if event.is_action_pressed("plantar"):
		prement_p = true
		temps_p = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("plantar"):
		prement_p = false
		if roda_oberta:
			_tancar_roda(true)
		else:
			alternar()
		get_viewport().set_input_as_handled()
		return
	if not actiu:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("accio_secundaria"):
		if arrossegant:
			_cancel_lar_area()   # només cancel·la la selecció
		else:
			sortir()
		get_viewport().set_input_as_handled()
	# Q / E (les mateixes accions que el combat, que en mode plantar no s'usen)
	elif event.is_action_pressed("mode_combat"):
		canviar_amb_tecla(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("atac_magia"):
		canviar_amb_tecla(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		if not cella.is_empty():
			arrossegant = true
			inici_area = cella.duplicate()
			seleccio_area = [cella]
		get_viewport().set_input_as_handled()
	elif event.is_action_released("accio_primaria"):
		if arrossegant:
			_plantar_area()
		get_viewport().set_input_as_handled()

func alternar():
	if actiu:
		sortir()
	else:
		entrar()

func entrar():
	actiu = true
	EventBus.activar_mode_plantar()
	mode_canviat.emit(true)

func sortir():
	actiu = false
	_cancel_lar_area()
	cursor.visible = false
	fantasma.visible = false
	anell.visible = false
	etiqueta_info.visible = false
	# (la vora del text té el seu propi color: si només s'esvaeix el modulate, queda en negre)
	if tween_canvi:
		tween_canvi.kill()
	etiqueta_canvi.visible = false
	_amagar_area()
	_treure_ressaltats()
	for c in get_tree().get_nodes_in_group("cultius"):
		if c.has_method("mostrar_radi"):
			c.mostrar_radi(false)
	EventBus.desactivar_mode_plantar()
	mode_canviat.emit(false)

func seleccionar(nou_index: int):
	index = clampi(nou_index, 0, opcions.size() - 1)
	seleccio_canviada.emit(index)

## Passa al cultiu anterior (-1) o següent (+1), fent la volta
func canviar_amb_tecla(direccio: int):
	seleccionar(posmod(index + direccio, opcions.size()))
	canviat_amb_tecla.emit(index, direccio)
	# La vista prèvia fa un bot i el nom apareix un moment sobre el cursor
	var o := opcio()
	fantasma.scale = Vector3.ONE * 1.35
	etiqueta_canvi.text = "%s %s" % [o.insignia, o.nom]
	etiqueta_canvi.modulate = Color(Color(o.color).lerp(Color.WHITE, 0.4), 1.0)
	etiqueta_canvi.outline_modulate = Color(0, 0, 0, 1)
	etiqueta_canvi.visible = true
	if tween_canvi:
		tween_canvi.kill()
	tween_canvi = create_tween().set_parallel(true)
	tween_canvi.tween_property(fantasma, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_canvi.tween_property(etiqueta_canvi, "modulate:a", 0.0, 0.35).set_delay(0.7)
	tween_canvi.tween_property(etiqueta_canvi, "outline_modulate:a", 0.0, 0.35).set_delay(0.7)
	tween_canvi.chain().tween_callback(func(): etiqueta_canvi.visible = false)

func _obrir_roda():
	roda_oberta = true
	roda.obrir(opcions, index)

func _tancar_roda(confirmar: bool):
	roda_oberta = false
	if confirmar:
		seleccionar(roda.obtenir_seleccio())
		if not actiu:
			entrar()
	roda.tancar()

# ─────────────── Cada frame

func _process(delta):
	if prement_p and not roda_oberta:
		temps_p += delta
		if temps_p >= LLINDAR_RODA:
			_obrir_roda()
	if not actiu:
		return
	if not GameState.pot_atacar():
		sortir()
		return

	cella = _cella_sota_ratoli()
	_escalar_etiquetes()
	_actualitzar_visuals()
	if arrossegant:
		if not cella.is_empty():
			seleccio_area = _cel_les_area(inici_area.cella, cella.cella)
		_mostrar_seleccio()

## Les etiquetes 3D es veurien més grans o més petites segons el zoom de la càmera:
## les ajustem perquè a la pantalla facin sempre la mateixa mida
func _escalar_etiquetes():
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	unitats_per_pixel = camera.size / get_viewport().get_visible_rect().size.y
	etiqueta_info.pixel_size = LINIA_INFO_PX * unitats_per_pixel / etiqueta_info.font_size
	etiqueta_canvi.pixel_size = LINIA_CANVI_PX * unitats_per_pixel / etiqueta_canvi.font_size
	etiqueta_area.pixel_size = LINIA_CANVI_PX * unitats_per_pixel / etiqueta_area.font_size

## Quina cel·la de l'hort hi ha sota el ratolí (o {} si cap)
func _cella_sota_ratoli() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var ratoli := get_viewport().get_mouse_position()
	cultiu_sota_ratoli = _cultiu_a_pantalla(camera, ratoli)
	if cultiu_sota_ratoli:
		var sota := gridmap.local_to_map(gridmap.to_local(cultiu_sota_ratoli.global_position + Vector3.DOWN * 0.8))
		return _info_cella(sota)

	# Recorre el raig pel damunt del terreny, cel·la a cel·la (no xoca amb cossos)
	var origen := camera.project_ray_origin(ratoli)
	var dir := camera.project_ray_normal(ratoli)
	var t_inici := 0.0
	var t_final := 120.0
	if absf(dir.y) > 0.01:
		t_inici = maxf(0.0, (6.0 - origen.y) / dir.y)
		t_final = maxf(t_inici, (-4.0 - origen.y) / dir.y)
	var t := t_inici
	while t <= t_final:
		var c := gridmap.local_to_map(gridmap.to_local(origen + dir * t))
		if gridmap.get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
			return _info_cella(c)
		t += 0.04
	return {}

## El cultiu el sprite del qual és sota el ratolí (el raig el travessaria)
func _cultiu_a_pantalla(camera: Camera3D, ratoli: Vector2) -> Node3D:
	var millor: Node3D = null
	var millor_d := INF
	for c in get_tree().get_nodes_in_group("cultius"):
		if camera.is_position_behind(c.global_position):
			continue
		var centre := camera.unproject_position(c.global_position)
		var radi := centre.distance_to(camera.unproject_position(c.global_position + camera.global_basis.x * 0.35))
		var d := centre.distance_to(ratoli)
		if d < radi and d < millor_d:
			millor = c
			millor_d = d
	return millor

func _info_cella(c: Vector3i) -> Dictionary:
	# La superfície: puja mentre hi hagi blocs a sobre
	for i in 4:
		if gridmap.get_cell_item(c + Vector3i.UP) == GridMap.INVALID_CELL_ITEM:
			break
		c += Vector3i.UP
	var item := gridmap.get_cell_item(c)
	var nom := gridmap.mesh_library.get_item_name(item) if item != GridMap.INVALID_CELL_ITEM else ""
	var alt_superficie := 0.5 if nom.contains("half") else 1.0
	var local := gridmap.map_to_local(c)
	local.y = c.y + alt_superficie
	var superficie := gridmap.to_global(local)
	var info := {
		"cella": c,
		"superficie": superficie,
		"posicio": superficie + Vector3.UP * 0.5,   # el centre del sprite del cultiu
		"valida": true,
		"motiu": "",
	}
	if not mon.es_plantable(c, nom, info.posicio):
		info.valida = false
		info.motiu = "Aquí no s'hi pot plantar"
	elif mon.cultiu_a_prop(info.posicio):
		info.valida = false
		info.motiu = "Ja hi ha un cultiu"
	elif llavors() <= 0:
		info.valida = false
		info.motiu = "No tens llavors"
	return info

# ─────────────── Plantar

func _intentar_plantar(_des_de_clic: bool = true):
	if cella.is_empty():
		return
	if not cella.valida:
		avis.emit(cella.motiu)
		return
	if mon.plantar_cultiu(escena(), cella.posicio):
		seleccio_canviada.emit(index)

## Totes les cel·les del rectangle entre `a` i `b` (seguint l'alçada del terreny)
func _cel_les_area(a: Vector3i, b: Vector3i) -> Array:
	var x0 := mini(a.x, b.x)
	var x1 := mini(maxi(a.x, b.x), x0 + MIDA_MAXIMA_AREA - 1)
	var z0 := mini(a.z, b.z)
	var z1 := mini(maxi(a.z, b.z), z0 + MIDA_MAXIMA_AREA - 1)
	var resultat := []
	var disponibles := llavors()
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var info := _info_columna(x, z, a.y)
			if info.is_empty():
				continue
			# Si no hi ha llavors per a totes, les últimes queden en vermell
			if info.valida:
				if disponibles > 0:
					disponibles -= 1
				else:
					info.valida = false
					info.motiu = "No tens prou llavors"
			resultat.append(info)
	return resultat

## La cel·la de terra d'una columna, buscant a prop de l'alçada de referència
func _info_columna(x: int, z: int, y_ref: int) -> Dictionary:
	for y in range(y_ref + 2, y_ref - 4, -1):
		if gridmap.get_cell_item(Vector3i(x, y, z)) != GridMap.INVALID_CELL_ITEM:
			return _info_cella(Vector3i(x, y, z))
	return {}

func _plantar_area():
	var plantats := 0
	var motiu := ""
	for info in seleccio_area:
		if info.valida:
			if mon.plantar_cultiu(escena(), info.posicio):
				plantats += 1
		elif motiu.is_empty():
			motiu = info.motiu
	if plantats == 0 and not motiu.is_empty():
		avis.emit(motiu)
	seleccio_canviada.emit(index)
	_cancel_lar_area()

func _cancel_lar_area():
	arrossegant = false
	inici_area = {}
	seleccio_area.clear()
	for q in quads_seleccio:
		q.visible = false
	for f in fantasmes_seleccio:
		f.visible = false
	if etiqueta_area:
		etiqueta_area.visible = false

## Quadres verds/vermells i vista prèvia a cada cel·la de l'àrea
func _mostrar_seleccio():
	var o := opcio()
	var valides := 0
	for i in seleccio_area.size():
		var info: Dictionary = seleccio_area[i]
		if i >= quads_seleccio.size():
			var q := MeshInstance3D.new()
			var pla := PlaneMesh.new()
			pla.size = Vector2(0.92, 0.92)
			q.mesh = pla
			q.top_level = true
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(q)
			quads_seleccio.append(q)
			var f := Sprite3D.new()
			f.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			f.shaded = false
			f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			f.top_level = true
			add_child(f)
			fantasmes_seleccio.append(f)
		var q := quads_seleccio[i]
		q.visible = true
		q.material_override = material_seleccio_ok if info.valida else material_seleccio_ko
		q.global_position = info.superficie + Vector3.UP * 0.03
		var f := fantasmes_seleccio[i]
		f.visible = info.valida
		if info.valida:
			valides += 1
			f.texture = o.textura
			f.pixel_size = 1.0 / float(o.textura.get_height()) if o.textura else 0.01
			f.modulate = Color(o.color, 0.5)
			f.global_position = info.posicio
	for i in range(seleccio_area.size(), quads_seleccio.size()):
		quads_seleccio[i].visible = false
		fantasmes_seleccio[i].visible = false

	# Quants se'n plantaran, sobre el cursor
	etiqueta_area.visible = not cella.is_empty()
	if etiqueta_area.visible:
		etiqueta_area.text = "%s ×%d   🌱 %d" % [o.insignia, valides, llavors()]
		etiqueta_area.modulate = Color(0.85, 1.0, 0.8) if valides > 0 else Color(1, 0.6, 0.55)
		etiqueta_area.global_position = cella.posicio + Vector3.UP * (0.35 + SEPARACIO_PX * unitats_per_pixel)

# ─────────────── Visuals

func _actualitzar_visuals():
	_treure_ressaltats()
	_amagar_area()
	if cella.is_empty():
		cursor.visible = false
		fantasma.visible = false
		anell.visible = false
		etiqueta_info.visible = false
		_mostrar_anells_plantats(null)
		return

	var o := opcio()
	var color_estat := COLOR_VALID if cella.valida else COLOR_INVALID

	# Marc de la cel·la
	cursor.visible = true
	cursor.global_position = cella.superficie + Vector3.UP * 0.02
	var mat = cursor.get_surface_override_material(0)
	if mat == null and cursor.mesh:
		mat = cursor.mesh.surface_get_material(0)
	if mat:
		mat.albedo_color = Color(color_estat, 0.35)

	# Vista prèvia del cultiu (no si ja n'hi ha un, que es veu ell)
	fantasma.visible = cultiu_sota_ratoli == null and not arrossegant
	if fantasma.visible:
		fantasma.texture = o.textura
		fantasma.pixel_size = 1.0 / float(o.textura.get_height()) if o.textura else 0.01
		fantasma.modulate = Color(o.color * color_estat.lerp(Color.WHITE, 0.6), 0.6)
		fantasma.global_position = cella.posicio

	# Abast o àrea del que plantaràs
	var radi: float = o.radi
	anell.visible = o.es_distancia and radi > 0.0
	if anell.visible:
		if anell.get_meta("radi", -1.0) != radi:
			anell.configurar(radi, o.color)
			anell.set_meta("radi", radi)
		anell.global_position = cella.superficie + Vector3.UP * 0.03
	elif radi > 0.0:
		_mostrar_area(cella.superficie, radi, o.color)

	# Cultius afectats
	if o.tipus == CatalegCultius.FLOR:
		# La flor potencia/protegeix els cultius del voltant
		for c in _cultius_a(cella.posicio, radi):
			_ressaltar(c)
	else:
		# Les flors que ja potencien aquesta cel·la
		for c in get_tree().get_nodes_in_group("cultius"):
			if c.tipus_cultiu == CatalegCultius.FLOR and _pla(c.global_position - cella.posicio).length() <= c.radi_influencia:
				_ressaltar(c)
	_mostrar_anells_plantats(cella.posicio)

	etiqueta_canvi.global_position = cella.posicio + Vector3.UP * (0.35 + SEPARACIO_PX * unitats_per_pixel)

	# Informació del cultiu que hi ha sota el ratolí
	etiqueta_info.visible = cultiu_sota_ratoli != null
	if etiqueta_info.visible:
		etiqueta_info.text = cultiu_sota_ratoli.text_info()
		etiqueta_info.global_position = cultiu_sota_ratoli.global_position + Vector3.UP * (0.35 + SEPARACIO_PX * unitats_per_pixel)

## Només els cercles de les torres a distància que ja cobreixen aquest punt
func _mostrar_anells_plantats(punt):
	for c in get_tree().get_nodes_in_group("cultius"):
		if not c.has_method("mostrar_radi"):
			continue
		var cobreix: bool = punt != null and c.tipus_cultiu == CatalegCultius.DEFENSA_RANGED \
			and _pla(c.global_position - punt).length() <= c.defensa_range
		c.mostrar_radi(cobreix)

## Cel·les dins del radi, pintades a terra
func _mostrar_area(centre: Vector3, radi: float, color: Color):
	material_cella.albedo_color = Color(color, 0.32)
	var n := int(ceil(radi))
	var i := 0
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			if Vector2(dx, dz).length() > radi or (dx == 0 and dz == 0):
				continue
			if i >= cel_les_area.size():
				var quad := MeshInstance3D.new()
				var pla := PlaneMesh.new()
				pla.size = Vector2(0.9, 0.9)
				quad.mesh = pla
				quad.material_override = material_cella
				quad.top_level = true
				quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(quad)
				cel_les_area.append(quad)
			var quad := cel_les_area[i]
			quad.visible = true
			quad.global_position = centre + Vector3(dx, 0.025, dz)
			i += 1

func _amagar_area():
	for quad in cel_les_area:
		quad.visible = false

func _cultius_a(punt: Vector3, radi: float) -> Array:
	return get_tree().get_nodes_in_group("cultius").filter(func(c): return _pla(c.global_position - punt).length() <= radi)

func _ressaltar(c: Node3D):
	if c.has_method("ressaltar"):
		c.ressaltar(true)
		ressaltats.append(c)

func _treure_ressaltats():
	for c in ressaltats:
		if is_instance_valid(c):
			c.ressaltar(false)
	ressaltats.clear()

static func _pla(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
