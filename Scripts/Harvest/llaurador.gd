extends Node3D
class_name Llaurador
## Encanteri de llaurar: invoca una aixada espectral que converteix l'herba en terra cultivable.
##  - T: entra/surt del mode llaurar.
##  - Clic: llaura la cel·la. Arrossegant: selecciona una àrea i en deixar anar la llaura.
##  - Clic dret / Esc: cancel·la l'àrea o surt del mode.
## La terra nova agafa la peça de vora o cantonada que toca (autotiling) i es desa.

signal mode_canviat(actiu: bool)
signal avis(text: String)

const ABAST := 7.0              # l'habilitat "Aixada llarga" l'amplia
const COST_MANA_PER_CELLA := 2.0
const RECARREGA := 0.5
const MIDA_AREA_BASE := 4       # cel·les per costat (l'habilitat "Aixada llarga" en suma)

func mida_maxima_area() -> int:
	return MIDA_AREA_BASE + roundi(Progressio.valor("abast_llaurar"))

func abast() -> float:
	return ABAST + Progressio.valor("abast_llaurar")
const COLOR_MAGIA := Color(0.95, 0.75, 0.4)
const COLOR_VALID := Color(0.85, 0.6, 0.3)
const COLOR_INVALID := Color(1.0, 0.3, 0.3)

var mon: Node3D
var plantador: Plantador
var jugador: Node3D
var actiu := false
var cella: Dictionary = {}
var temps_des_de_llaurar := 99.0

var arrossegant := false
var inici_area: Dictionary = {}
var seleccio: Array = []            # [{cella, superficie, valida, motiu}]
var quads: Array[MeshInstance3D] = []
var material_ok := StandardMaterial3D.new()
var material_ko := StandardMaterial3D.new()

static var _textura_aixada: ImageTexture
static var _material_aixada: StandardMaterial3D
static var _material_terrossos: ParticleProcessMaterial
static var _malla_terros: QuadMesh

func configurar(p_mon: Node3D, p_plantador: Plantador, p_jugador: Node3D) -> void:
	mon = p_mon
	plantador = p_plantador
	jugador = p_jugador

func _ready():
	for m in [material_ok, material_ko]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_ok.albedo_color = Color(COLOR_VALID, 0.45)
	material_ko.albedo_color = Color(COLOR_INVALID, 0.35)

func progres() -> float:
	return clampf(temps_des_de_llaurar / RECARREGA, 0.0, 1.0)

# ─────────────── Entrada

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.pot_atacar():
		return
	if event.is_action_pressed("llaurar"):
		if actiu:
			sortir()
		else:
			entrar()
		get_viewport().set_input_as_handled()
		return
	if not actiu:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("accio_secundaria"):
		if arrossegant:
			_cancel_lar()
		else:
			sortir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		if not cella.is_empty():
			arrossegant = true
			inici_area = cella.duplicate()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("accio_primaria"):
		if arrossegant:
			_llaurar_seleccio()
		get_viewport().set_input_as_handled()

func entrar():
	actiu = true
	mode_canviat.emit(true)

func sortir_si_actiu():
	if actiu:
		sortir()

func sortir():
	actiu = false
	_cancel_lar()
	plantador.cursor.visible = false
	mode_canviat.emit(false)

# ─────────────── Cada frame

func _process(delta):
	temps_des_de_llaurar += delta
	if not actiu:
		return
	if not GameState.pot_atacar():
		sortir()
		return
	cella = plantador._cella_sota_ratoli()
	if cella.is_empty():
		plantador.cursor.visible = false
		_amagar_quads()
		return
	if arrossegant:
		seleccio = _area(inici_area.cella, cella.cella)
	else:
		seleccio = [_info(cella.cella)]
	_mostrar(seleccio)

## Pot llaurar-se? Només herba, a l'abast i sense res a sobre
func _info(c: Vector3i) -> Dictionary:
	var gridmap := plantador.gridmap
	# Superfície de la columna
	for i in 4:
		if gridmap.get_cell_item(c + Vector3i.UP) == GridMap.INVALID_CELL_ITEM:
			break
		c += Vector3i.UP
	var item := gridmap.get_cell_item(c)
	var nom := gridmap.mesh_library.get_item_name(item) if item != GridMap.INVALID_CELL_ITEM else ""
	var local := gridmap.map_to_local(c)
	local.y = c.y + (0.5 if nom.contains("half") else 1.0)
	var superficie := gridmap.to_global(local)
	var info := {"cella": c, "superficie": superficie, "valida": true, "motiu": ""}
	if mon.llaurades.has(c) or nom in mon.blocs_plantables:
		info.valida = false
		info.motiu = "Aquesta terra ja és cultivable"
	elif not mon.es_herba(nom):
		info.valida = false
		info.motiu = "Només es pot llaurar l'herba"
	elif Vector2(superficie.x - jugador.global_position.x, superficie.z - jugador.global_position.z).length() > abast():
		info.valida = false
		info.motiu = "Massa lluny"
	elif _hi_ha_obstacle(superficie):
		info.valida = false
		info.motiu = "Hi ha alguna cosa a sobre"
	return info

## Cases, tanques... qualsevol cos físic a sobre de la cel·la (el jugador no compta)
func _hi_ha_obstacle(superficie: Vector3) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.8, 0.6, 0.8)
	consulta.shape = caixa
	consulta.transform = Transform3D(Basis(), superficie + Vector3.UP * 0.4)
	consulta.exclude = [jugador.get_rid()]
	var resultat := get_world_3d().direct_space_state.intersect_shape(consulta, 4)
	for r in resultat:
		if not r.collider is GridMap and not r.collider.is_in_group("enemics"):
			return true
	return false

func _area(a: Vector3i, b: Vector3i) -> Array:
	var x0 := mini(a.x, b.x)
	var x1 := mini(maxi(a.x, b.x), x0 + mida_maxima_area() - 1)
	var z0 := mini(a.z, b.z)
	var z1 := mini(maxi(a.z, b.z), z0 + mida_maxima_area() - 1)
	var resultat := []
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			for y in range(a.y + 2, a.y - 4, -1):
				if plantador.gridmap.get_cell_item(Vector3i(x, y, z)) != GridMap.INVALID_CELL_ITEM:
					resultat.append(_info(Vector3i(x, y, z)))
					break
	return resultat

func _mostrar(infos: Array):
	plantador.cursor.visible = false
	for i in infos.size():
		if i >= quads.size():
			var q := MeshInstance3D.new()
			var pla := PlaneMesh.new()
			pla.size = Vector2(0.92, 0.92)
			q.mesh = pla
			q.top_level = true
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(q)
			quads.append(q)
		quads[i].visible = true
		quads[i].material_override = material_ok if infos[i].valida else material_ko
		quads[i].global_position = infos[i].superficie + Vector3.UP * 0.03
	for i in range(infos.size(), quads.size()):
		quads[i].visible = false

func _amagar_quads():
	for q in quads:
		q.visible = false

func _cancel_lar():
	arrossegant = false
	inici_area = {}
	seleccio.clear()
	_amagar_quads()

# ─────────────── Encanteri

func _llaurar_seleccio():
	arrossegant = false
	var valides := seleccio.filter(func(i): return i.valida)
	if valides.is_empty():
		if not seleccio.is_empty():
			avis.emit(seleccio[0].motiu)
		_cancel_lar()
		return
	if temps_des_de_llaurar < RECARREGA:
		_cancel_lar()
		return
	# Cada cel·la costa una mica de mana
	if jugador.has_method("gastar_mana") and not jugador.gastar_mana(COST_MANA_PER_CELLA * valides.size()):
		avis.emit("No tens prou mana")
		_cancel_lar()
		return
	temps_des_de_llaurar = 0.0

	# L'aixada cau al centre de l'àrea
	var centre := Vector3.ZERO
	for i in valides:
		centre += i.superficie
	centre /= valides.size()
	var direccio := centre - jugador.global_position
	direccio.y = 0
	if direccio.length() > 0.1 and jugador.has_method("_mirar_cap_a"):
		jugador._mirar_cap_a(direccio.normalized())
		jugador.play_anim("attack_" + jugador.ultima_direccio, jugador.mirall_horitzontal)

	var durada := _aixada(centre)
	# En tocar a terra, les cel·les es converteixen una darrere l'altra, des del centre
	valides.sort_custom(func(a, b): return a.superficie.distance_to(centre) < b.superficie.distance_to(centre))
	for n in valides.size():
		var info: Dictionary = valides[n]
		get_tree().create_timer(durada + n * 0.03).timeout.connect(func(): _convertir(info))
	get_tree().create_timer(durada + valides.size() * 0.03 + 0.1).timeout.connect(func(): GestorPartida.guardar_mundo())
	_cancel_lar()

func _convertir(info: Dictionary):
	mon.llaurar_cella(info.cella)
	Progressio.guanyar_xp("llaurar")
	_terrossos(info.superficie)

## Aixada espectral: s'alça, cau de cop i s'esvaeix. Retorna quant triga a tocar a terra.
func _aixada(punt: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	var pivot := Node3D.new()
	mon.add_child(pivot)
	pivot.global_position = punt + Vector3.UP * 0.1
	var sprite := Sprite3D.new()
	sprite.texture = textura_aixada()
	sprite.pixel_size = 0.05
	sprite.material_override = _material()
	sprite.modulate = Color(COLOR_MAGIA, 0.95)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(0, 0.8, 0)   # el mànec s'aguanta per baix; el cap queda amunt
	pivot.add_child(sprite)

	# Mira sempre a càmera i gira al voltant de l'eix de la càmera (com un sprite 2D)
	var base := camera.global_basis if camera else Basis()
	var girar := func(angle: float): pivot.global_basis = base * Basis(Vector3(0, 0, 1), angle)
	girar.call(deg_to_rad(70))
	sprite.modulate.a = 0.0
	var t := pivot.create_tween()
	t.tween_property(sprite, "modulate:a", 0.95, 0.08)
	t.parallel().tween_method(girar, deg_to_rad(70), deg_to_rad(95), 0.12).set_ease(Tween.EASE_OUT)   # s'alça
	t.tween_method(girar, deg_to_rad(95), deg_to_rad(-15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)   # cop
	t.tween_interval(0.12)
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	t.tween_callback(pivot.queue_free)
	return 0.24

func _terrossos(punt: Vector3):
	if _material_terrossos == null:
		_material_terrossos = ParticleProcessMaterial.new()
		_material_terrossos.direction = Vector3.UP
		_material_terrossos.spread = 60.0
		_material_terrossos.initial_velocity_min = 1.5
		_material_terrossos.initial_velocity_max = 3.0
		_material_terrossos.gravity = Vector3(0, -12, 0)
		_material_terrossos.scale_min = 0.6
		_material_terrossos.scale_max = 1.3
		_material_terrossos.color = Color(0.45, 0.3, 0.16)
		_malla_terros = QuadMesh.new()
		_malla_terros.size = Vector2(0.09, 0.09)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.vertex_color_use_as_albedo = true
		_malla_terros.material = mat
	var p := GPUParticles3D.new()
	p.process_material = _material_terrossos
	p.draw_pass_1 = _malla_terros
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	mon.add_child(p)
	p.global_position = punt + Vector3.UP * 0.05
	p.emitting = true
	p.finished.connect(p.queue_free)

## Aixada de 32x32 en pixel art: mànec vertical i fulla perpendicular a dalt
static func textura_aixada() -> ImageTexture:
	if _textura_aixada:
		return _textura_aixada
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var fusta := Color(0.75, 0.55, 0.3)
	var metall := Color(0.9, 0.92, 0.95)
	for y in range(7, 31):
		for x in range(15, 17):
			img.set_pixel(x, y, fusta)
	for y in range(4, 8):
		for x in range(10, 21):
			img.set_pixel(x, y, metall)
	for y in range(8, 13):          # la fulla baixa per un costat
		for x in range(10, 13):
			img.set_pixel(x, y, metall)
	_textura_aixada = ImageTexture.create_from_image(img)
	return _textura_aixada

static func _material() -> StandardMaterial3D:
	if _material_aixada == null:
		_material_aixada = StandardMaterial3D.new()
		_material_aixada.albedo_texture = textura_aixada()
		_material_aixada.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material_aixada.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_aixada.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_aixada.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_aixada.no_depth_test = true
		_material_aixada.vertex_color_use_as_albedo = true
	return _material_aixada
