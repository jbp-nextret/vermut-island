extends Node
class_name PuntsExcavacio
## Punts d'excavació: cada dia surten unes marques a terra (terra remoguda amb uns
## cuquets que es mouen) a la illa principal i a les illetes. Si hi llaures a sobre amb
## l'aixada, desenterres el que hi ha: un fòssil o un tresor. Les marques que brillen
## amaguen alguna cosa important i es desenterren amb el minijoc d'excavació.
##
## Les marques del dia surten sempre al mateix lloc (la llavor és el dia), i les que
## ja has excavat es recorden fins l'endemà.

const PER_ILLETA := 2
const A_LA_PRINCIPAL := 3
const FITXER := "user://excavacions.save"

var mon: Node3D
var gridmap: GridMap
var zones := []        # [{celles, quants, zona}]
var punts := {}        # Vector3i -> {botí, marca: Node3D, zona}
var dia := -1
var excavats := []     # cel·les excavades avui
var cua := []          # excavacions importants pendents (si n'hi ha més d'una alhora)
var qte_obert := false

static var _textures: Array[ImageTexture] = []

func configurar(p_mon: Node3D, p_gridmap: GridMap):
	mon = p_mon
	gridmap = p_gridmap

func afegir_zona(celles: Array, quants: int, zona: String):
	if not celles.is_empty():
		zones.append({"celles": celles, "quants": quants, "zona": zona})

func _ready():
	_carregar()

func _process(_delta):
	if GestorTemps.dia_actual != dia:
		if dia >= 0:
			excavats.clear()
		dia = GestorTemps.dia_actual
		_generar()

func hi_ha(cella: Vector3i) -> bool:
	return punts.has(cella)

# ─────────────── Generar les marques del dia

func _generar():
	for p in punts.values():
		if is_instance_valid(p.marca):
			p.marca.queue_free()
	punts.clear()
	var r := RandomNumberGenerator.new()
	r.seed = hash(dia * 7919 + 13)
	for z in zones:
		var posats := 0
		for intent in 40:
			if posats >= z.quants:
				break
			var cella: Vector3i = z.celles[r.randi() % z.celles.size()]
			var boti := Arqueologia.boti(z.zona, r)   # sempre se sorteja, perquè el dia sigui igual
			if punts.has(cella) or cella in excavats or not _lliure(cella):
				continue
			_posar(cella, boti, z.zona)
			posats += 1

func _lliure(cella: Vector3i) -> bool:
	if gridmap.get_cell_item(cella + Vector3i.UP) != GridMap.INVALID_CELL_ITEM:
		return false
	if mon.llaurades.has(cella):
		return false
	var pos := _superficie(cella)
	if mon.has_method("recurs_a") and mon.recurs_a(pos):
		return false
	if mon.has_method("zona_de_conreu_a_prop") and mon.zona_de_conreu_a_prop(pos, 1.0):
		return false
	var casa := mon.get_node_or_null("Casa") as Node3D
	if casa and Vector2(casa.global_position.x - pos.x, casa.global_position.z - pos.z).length() < 5.0:
		return false
	return true

func _superficie(cella: Vector3i) -> Vector3:
	var local := gridmap.map_to_local(cella)
	local.y = cella.y + 1.0
	return gridmap.to_global(local)

func _posar(cella: Vector3i, boti: Dictionary, zona: String):
	var marca := Sprite3D.new()
	marca.texture = textures()[0]
	marca.pixel_size = 1.05 / 32.0
	marca.rotation_degrees.x = -90.0
	marca.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	marca.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	marca.shaded = true
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mon.add_child(marca)
	marca.global_position = _superficie(cella) + Vector3.UP * 0.025
	marca.set_meta("fase", randf() * 10.0)
	# Les importants brillen una mica
	if boti.raresa >= 1:
		var guspira := CPUParticles3D.new()
		guspira.amount = 4 if boti.raresa == 1 else 8
		guspira.lifetime = 1.4
		guspira.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		guspira.emission_box_extents = Vector3(0.3, 0.0, 0.3)
		guspira.direction = Vector3.UP
		guspira.spread = 15.0
		guspira.initial_velocity_min = 0.2
		guspira.initial_velocity_max = 0.5
		guspira.gravity = Vector3.ZERO
		guspira.scale_amount_min = 0.5
		guspira.scale_amount_max = 1.0
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = PartFossil.COLORS_RARESA[boti.raresa]
		quad.material = mat
		guspira.mesh = quad
		guspira.rotation_degrees.x = 90.0   # (la marca està girada; així surten cap amunt)
		marca.add_child(guspira)
	punts[cella] = {"boti": boti, "marca": marca, "zona": zona}

## Els cuquets es mouen (dos fotogrames)
func _physics_process(_delta):
	var t := Time.get_ticks_msec() / 1000.0
	for p in punts.values():
		if is_instance_valid(p.marca):
			p.marca.texture = textures()[int(t * 2.5 + p.marca.get_meta("fase")) % 2]

# ─────────────── Excavar

## Cridat pel llaurador en llaurar una cel·la
func excavar(cella: Vector3i):
	if not punts.has(cella):
		return
	var p: Dictionary = punts[cella]
	punts.erase(cella)
	excavats.append(cella)
	_guardar()
	var pos := _superficie(cella)
	if is_instance_valid(p.marca):
		p.marca.queue_free()
	if p.boti.raresa == 0:
		_saltar_troballa(pos, p.boti)
		Arqueologia.donar(p.boti, pos)
	else:
		cua.append({"boti": p.boti, "pos": pos})
		_seguent_qte()

func _seguent_qte():
	if qte_obert or cua.is_empty():
		return
	qte_obert = true
	var e: Dictionary = cua.pop_front()
	EventBus.avis.emit("Hi ha alguna cosa %s enterrada... Compte!" % PartFossil.NOMS_RARESA[e.boti.raresa])
	await get_tree().create_timer(0.5).timeout
	var qte := ExcavacioQTE.comencar(get_tree(), e.boti)
	qte.acabat.connect(func(exit: bool, impecable: bool):
		qte_obert = false
		if exit:
			_saltar_troballa(e.pos, e.boti)
			Arqueologia.donar(e.boti, e.pos)
			if impecable:
				Progressio.guanyar_xp("excavar", 2.0)
		else:
			# S'ha esmicolat: alguna cosa en queda
			var resta := {"tipus": "tresor", "id": "fragments_fossil" if e.boti.tipus == "fossil" else "diners", "quantitat": 2 if e.boti.tipus == "fossil" else 10, "raresa": 0}
			Arqueologia.donar(resta, e.pos)
		_seguent_qte())

## L'objecte surt de terra fent un bot
func _saltar_troballa(pos: Vector3, boti: Dictionary):
	var l := Label3D.new()
	l.text = "🪙" if boti.id == "diners" else CatalegObjectes.info(boti.id).icona
	l.font_size = 96
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 16
	mon.add_child(l)
	l.global_position = pos + Vector3.UP * 0.2
	var t := l.create_tween()
	t.tween_property(l, "global_position", pos + Vector3.UP * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "global_position", pos + Vector3.UP * 1.1, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)

# ─────────────── Desat (què s'ha excavat avui)

func _guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"dia": GestorTemps.dia_actual, "excavats": excavats.map(func(c): return [c.x, c.y, c.z])}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and int(d.get("dia", -1)) == GestorTemps.dia_actual:
		for c in d.get("excavats", []):
			excavats.append(Vector3i(int(c[0]), int(c[1]), int(c[2])))

# ─────────────── Textura de la marca (provisional, en pixel art)

static func textures() -> Array[ImageTexture]:
	if _textures.is_empty():
		for fotograma in 2:
			_textures.append(ImageTexture.create_from_image(_dibuixar(fotograma)))
	return _textures

static func _dibuixar(fotograma: int) -> Image:
	const M := 32
	var img := Image.create(M, M, false, Image.FORMAT_RGBA8)
	var terra := Color(0.36, 0.24, 0.14)
	var fosca := Color(0.22, 0.14, 0.08)
	var clara := Color(0.58, 0.42, 0.26)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	# Un clap de terra remoguda (irregular), amb la vora més clara i grumolls
	for x in M:
		for y in M:
			var d := Vector2(x - 15.5, (y - 15.5) * 1.1).length() + r.randf_range(-1.6, 1.6)
			if d < 13.0:
				var c := terra
				var s := r.randf()
				if d > 10.5:
					c = clara if s < 0.6 else terra
				elif s < 0.22:
					c = fosca
				elif s < 0.32:
					c = clara
				img.set_pixel(x, y, c)
	# Tres cuquets que es belluguen
	var cuquets := [Vector2i(10, 14), Vector2i(16, 10), Vector2i(20, 20)]
	for i in cuquets.size():
		var base: Vector2i = cuquets[i]
		for k in 5:
			var ona := 1 if ((k + fotograma + i) % 2 == 0) else 0
			var p := base + Vector2i(ona, -k)
			img.set_pixel(p.x, p.y, Color(0.85, 0.6, 0.55))
		img.set_pixel(base.x + ((fotograma + i) % 2), base.y - 5, Color(0.95, 0.72, 0.68))
	return img
