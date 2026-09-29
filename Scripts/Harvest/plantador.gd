extends Node3D
class_name Plantador
## Tot el mode plantar:
##  - P tocada: entra/surt del mode plantar. P mantinguda: roda per triar cultiu.
##  - El cursor segueix la graella de l'hort. El raig NO xoca amb el jugador ni amb
##    els enemics, i si el ratolí és sobre un cultiu, se selecciona la seva cel·la.
##  - Vista prèvia del cultiu (verda o vermella) i, segons el tipus:
##      · torres a distància: cercle d'abast
##      · la resta: s'acoloreixen les cel·les de l'àrea i els cultius afectats
##  - Clic: planta. Arrossegant: planta a cada cel·la per on passes. Clic dret / Esc: surt.

signal seleccio_canviada(index: int)
signal mode_canviat(actiu: bool)
signal avis(text: String)

const LLAVOR := "llavor_raim"
const LLINDAR_RODA := 0.25
const COLOR_VALID := Color(0.3, 1.0, 0.4)
const COLOR_INVALID := Color(1.0, 0.3, 0.3)

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
var pintant := false
var ultima_cella_pintada = null

var prement_p := false
var temps_p := 0.0
var roda_oberta := false

var fantasma: Sprite3D
var anell: AnellAbast
var cel_les_area: Array[MeshInstance3D] = []
var ressaltats: Array = []
var etiqueta_info: Label3D
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
	etiqueta_info.font_size = 36
	etiqueta_info.outline_size = 10
	etiqueta_info.pixel_size = 0.004
	etiqueta_info.top_level = true
	etiqueta_info.visible = false
	add_child(etiqueta_info)

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
		sortir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		pintant = true
		ultima_cella_pintada = null
		_intentar_plantar(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("accio_primaria"):
		pintant = false
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
	pintant = false
	cursor.visible = false
	fantasma.visible = false
	anell.visible = false
	etiqueta_info.visible = false
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
	_actualitzar_visuals()
	if pintant and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pintant = false
	if pintant and not cella.is_empty() and cella.cella != ultima_cella_pintada:
		_intentar_plantar(false)

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
	if not nom in blocs_plantables or not mon.dins_zona_hort(info.posicio):
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

func _intentar_plantar(des_de_clic: bool):
	if cella.is_empty():
		return
	ultima_cella_pintada = cella.cella
	if not cella.valida:
		if des_de_clic:
			avis.emit(cella.motiu)
		return
	if mon.plantar_cultiu(escena(), cella.posicio):
		seleccio_canviada.emit(index)

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
	fantasma.visible = cultiu_sota_ratoli == null
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

	# Informació del cultiu que hi ha sota el ratolí
	etiqueta_info.visible = cultiu_sota_ratoli != null
	if etiqueta_info.visible:
		etiqueta_info.text = cultiu_sota_ratoli.text_info()
		etiqueta_info.global_position = cultiu_sota_ratoli.global_position + Vector3.UP * 1.0

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
