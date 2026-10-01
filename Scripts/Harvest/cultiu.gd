extends Node3D

enum Estat { LLAVOR, CREIXENT, MIG, GRAN, MADUR }
## Afegeix els tipus nous al final (el número es desa a les escenes).
enum TipusCultiu {
	NORMAL,          # es cull un cop i desapareix
	DEFENSA_RANGED,  # torre: dispara projectils
	DEFENSA_MELEE,   # torre: mossega el que té a tocar
	VINYEDO,         # dona raïm i torna a créixer
	FLOR,            # millora el dany de les torres i protegeix els cultius del voltant
	ESQUER,          # molt resistent; els enemics hi van abans que a res
	ORTIGA,          # alenteix els enemics que passen a prop
}

@export var nom_cultiu := "Cultiu"
@export_multiline var descripcio := ""
@export var tint := Color.WHITE   # per distingir els tipus mentre no tinguin sprites propis

@export var dies_per_fase = 2
@export var textures: Array[Texture2D] = []
@export var llavor_drop_escena: PackedScene
@export var projectil_escena: PackedScene

@export var tipus_cultiu: TipusCultiu = TipusCultiu.NORMAL

@export_group("Defensa")
@export var defensa_range: float = 5.0
@export var defensa_cooldown: float = 1.2
@export var defensa_dany_base: int = 8
@export var defensa_velocitat: float = 18.0
@export var defensa_abast: float = 12.0

@export_group("Efecte als veïns")
@export var radi_influencia: float = 3.0
@export var modificador_dany: float = 0.0     # FLOR: +30 % = 0.3
@export var proteccio: float = 0.0            # FLOR: els cultius del voltant reben un 30 % menys de dany = 0.3
@export var alentiment: float = 0.5           # ORTIGA: velocitat dels enemics dins del radi
@export var mostrar_radi_influencia: bool = true

@export_group("Collita")
@export var raim_min := 1
@export var raim_max := 1

@export_group("")
@export var vida_maxima: int = 10
## Quina part de la vida es recupera cada segon, un cop fa estona que no rep cops.
## De dia, el triple de ràpid.
@export var regeneracio := 0.05
## Es manté només per compatibilitat amb les partides desades: el comportament el decideix el tipus.
@export var es_torre: bool = true

const SHADER_CULTIU := preload("res://Shaders/cultiu.gdshader")
const COLOR_RANG_TORRE := Color(1.0, 0.85, 0.3)
const ESPERA_REGENERACIO := 4.0   # segons sense rebre dany abans de començar a curar-se

var estat_actual = Estat.LLAVOR
var dies_passats = 0
var recollit = false
var temps_darrer_defensa: float = 0.0
var temps_darrera_recalculacio: float = 0.0
var vida_actual: int = 0
var defensa_dany: int = 0
var modificador_total_actual: float = 0.0
var temps_ortiga := 0.0
var temps_des_del_dany := 99.0
var vida_acumulada := 0.0

@onready var sprite = $Sprite
@onready var area = $Area3D
@onready var icona = $IconaRecollir

var indicador_radi: Node3D = null

# Rec: un cultiu només creix si el dia anterior l'han regat (i en passar el dia s'asseca)
var regat := false
var taca_humitat: MeshInstance3D
var icona_set: Label3D
static var _material_humitat: StandardMaterial3D
var ressaltat := false
var barra_vida: BarraVida3D

func _ready():
	icona.visible = false   # ara la collita va amb el sistema d'interacció ([F] Collir)
	add_to_group("cultius")
	add_to_group("interactuables")
	if vida_actual <= 0:
		vida_actual = vida_maxima
	defensa_dany = defensa_dany_base
	barra_vida = BarraVida3D.crear(self, 1.1)
	barra_vida.mostrar(vida_actual, vida_maxima)

	if es_defensa() and not projectil_escena and ResourceLoader.exists("res://Scenes/Projectil.tscn"):
		projectil_escena = load("res://Scenes/Projectil.tscn")

	actualitzar_sprite()

	if tipus_cultiu == TipusCultiu.DEFENSA_RANGED and mostrar_radi_influencia:
		indicador_radi = AnellAbast.crear(self, radi_efecte(), COLOR_RANG_TORRE if es_defensa() else tint)
		indicador_radi.visible = false
		EventBus.mode_plantar_canviat.connect(_on_mode_plantar_canviat)

# ─────────────── Tipus

func es_defensa() -> bool:
	return tipus_cultiu == TipusCultiu.DEFENSA_RANGED or tipus_cultiu == TipusCultiu.DEFENSA_MELEE

func es_collita() -> bool:
	return tipus_cultiu == TipusCultiu.NORMAL or tipus_cultiu == TipusCultiu.VINYEDO

func es_madur() -> bool:
	return estat_actual == Estat.MADUR

## Radi que es dibuixa en mode plantar (abast de la torre o de l'efecte), 0 si no en té
func radi_efecte() -> float:
	if es_defensa():
		return defensa_range
	if tipus_cultiu == TipusCultiu.FLOR or tipus_cultiu == TipusCultiu.ORTIGA or tipus_cultiu == TipusCultiu.ESQUER:
		return radi_influencia
	return 0.0

## Quant atrau els enemics: l'esquer "sembla" més a prop del que és
func atraccio() -> float:
	return 3.0 if tipus_cultiu == TipusCultiu.ESQUER else 1.0

# ─────────────── Aspecte

func _on_mode_plantar_canviat(actiu: bool):
	if indicador_radi and not actiu:
		indicador_radi.visible = false

## El món el crida en mode plantar: només es mostren les àrees que cobreixen el cursor
func mostrar_radi(mostrar: bool) -> void:
	if indicador_radi:
		indicador_radi.visible = mostrar

## En mode plantar: aquest cultiu es veuria afectat (o afecta) el que plantaràs
func ressaltar(actiu: bool) -> void:
	if ressaltat == actiu:
		return
	ressaltat = actiu
	_actualitzar_tint_influencia()
	sprite.scale = Vector3.ONE * (1.12 if actiu else 1.0)

const NOMS_ESTAT := ["Llavor", "Creixent", "Mitjana", "Gran", "Madura"]

## Text curt per a l'etiqueta que surt en passar-hi el ratolí
## Té set si encara ha de créixer i avui no l'han regat
func necessita_aigua() -> bool:
	return not recollit and not es_madur() and not regat

func regar() -> void:
	if recollit or regat:
		return
	regat = true
	_actualitzar_humitat()

## Taca fosca a terra quan està regat (no cal cap sprite nou de terra mullada)
func _actualitzar_humitat() -> void:
	if taca_humitat == null:
		if not regat:
			return
		taca_humitat = MeshInstance3D.new()
		var pla := PlaneMesh.new()
		pla.size = Vector2(0.95, 0.95)
		taca_humitat.mesh = pla
		taca_humitat.material_override = _material_taca()
		taca_humitat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		taca_humitat.position = Vector3(0, -0.47, 0)   # just a sobre del terra
		taca_humitat.rotation.y = randf() * TAU            # que no totes les taques siguin iguals
		add_child(taca_humitat)
		taca_humitat.transparency = 1.0
	var t := create_tween()
	t.tween_property(taca_humitat, "transparency", 0.0 if regat else 1.0, 0.5 if regat else 1.5)

static func _material_taca() -> StandardMaterial3D:
	if _material_humitat:
		return _material_humitat
	# Taca de 16x16 en pixel art: fosca al centre i vores irregulars
	var imatge := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var soroll := FastNoiseLite.new()
	soroll.seed = 7
	soroll.frequency = 0.25
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			var valor := 1.0 - d + soroll.get_noise_2d(x, y) * 0.35
			if valor > 0.15:
				imatge.set_pixel(x, y, Color(0.12, 0.07, 0.04, 0.55 if valor > 0.4 else 0.35))
	_material_humitat = StandardMaterial3D.new()
	_material_humitat.albedo_texture = ImageTexture.create_from_image(imatge)
	_material_humitat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material_humitat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_humitat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material_humitat

## En mode regar: una gota sobre els cultius que tenen set
func mostrar_set(mostrar: bool) -> void:
	if mostrar and icona_set == null:
		icona_set = Label3D.new()
		icona_set.text = "💧"
		icona_set.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icona_set.no_depth_test = true
		icona_set.font_size = 48
		icona_set.pixel_size = 0.006
		icona_set.position = Vector3.UP * 0.75
		add_child(icona_set)
	if icona_set:
		icona_set.visible = mostrar

func text_info() -> String:
	var text := "%s\n%s · ❤ %d/%d" % [nom_cultiu, NOMS_ESTAT[estat_actual], vida_actual, vida_maxima]
	if not es_madur():
		text += "\n💧 Regat" if regat else "\n💧 Té set: sense aigua no creix"
	if es_defensa() and not es_madur():
		text += "\n(defensarà quan sigui madura)"
	elif es_collita() and es_madur():
		text += "\n[F] Collir"
	return text

func passar_dia():
	var estava_regat := regat
	# Cada dia el terra s'asseca
	regat = false
	_actualitzar_humitat()
	if recollit or estat_actual == Estat.MADUR:
		return
	if not estava_regat:
		return   # sense aigua no creix
	dies_passats += 1
	if dies_passats >= dies_per_fase:
		dies_passats = 0
		if estat_actual < Estat.MADUR:
			estat_actual += 1
			actualitzar_sprite()

func actualitzar_sprite():
	if textures.size() == 0:
		push_warning("No hi ha textures assignades al cultiu " + nom_cultiu)
		return
	var index_visual = clampi(_index_visual_per_estat(estat_actual), 0, textures.size() - 1)
	# Material propi amb el shader que el fa gronxar amb el vent
	var material := sprite.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = SHADER_CULTIU
		sprite.set_surface_override_material(0, material)
	material.set_shader_parameter("textura", textures[index_visual])
	# Els cultius grans es gronxen més que les llavors
	material.set_shader_parameter("gronxament", [0.2, 0.5, 0.8, 1.0, 1.0][estat_actual])
	_actualitzar_tint_influencia()
	if barra_vida:
		barra_vida.mostrar(vida_actual, vida_maxima)

func _index_visual_per_estat(estat: int) -> int:
	match estat:
		Estat.LLAVOR: return 0
		Estat.CREIXENT: return 1
		Estat.MIG: return 1
		Estat.GRAN: return 2
		Estat.MADUR: return 2
		_: return clamp(estat, 0, textures.size() - 1)

func _actualitzar_tint_influencia():
	var material := sprite.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		return
	var color := tint
	if ressaltat:
		color = color.lerp(Color(1.0, 0.95, 0.5), 0.55)   # daurat: afectat pel que plantaràs
	elif modificador_total_actual > 0.01:
		# Potenciada per una flor: una mica més verda
		var intensitat = clamp(modificador_total_actual, 0.0, 1.0)
		color = color * Color(1.0 - intensitat * 0.4, 1.0, 1.0 - intensitat * 0.4)
	material.set_shader_parameter("tint", color)

# ─────────────── Cada frame

func _process(delta):
	if recollit:
		return

	_regenerar(delta)

	if es_defensa():
		temps_darrera_recalculacio += delta
		if temps_darrera_recalculacio >= 1.0:
			temps_darrera_recalculacio = 0.0
			recalcular_dany()

	# Les torres només defensen quan són grans (el jugador ha de protegir les joves)
	if es_defensa() and es_madur() and GestorTemps.es_nit():
		temps_darrer_defensa += delta
		if tipus_cultiu == TipusCultiu.DEFENSA_MELEE:
			atacar_enemic_melee()
		else:
			atacar_enemic_proper()

	if tipus_cultiu == TipusCultiu.ORTIGA and es_madur():
		temps_ortiga += delta
		if temps_ortiga >= 0.2:
			temps_ortiga = 0.0
			for enemic in get_tree().get_nodes_in_group("enemics"):
				if enemic.has_method("alentir") and global_position.distance_to(enemic.global_position) <= radi_influencia:
					enemic.alentir(alentiment, 0.4)

## Les flors madures del voltant potencien el dany de les torres
func recalcular_dany():
	var modificador_total: float = 0.0
	for flor in _flors_properes():
		modificador_total += flor.modificador_dany
	modificador_total_actual = modificador_total
	defensa_dany = max(1, int(round(defensa_dany_base * (1.0 + modificador_total))))
	_actualitzar_tint_influencia()

func _flors_properes() -> Array:
	var resultat := []
	for cultiu in get_tree().get_nodes_in_group("cultius"):
		if cultiu == self or not is_instance_valid(cultiu):
			continue
		if cultiu.tipus_cultiu != TipusCultiu.FLOR or not cultiu.es_madur():
			continue
		if global_position.distance_to(cultiu.global_position) <= cultiu.radi_influencia:
			resultat.append(cultiu)
	return resultat

# ─────────────── Defensa

func atacar_enemic_proper():
	if temps_darrer_defensa < defensa_cooldown:
		return
	var millor: Node3D = null
	var millor_dist = INF
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(enemic):
			continue
		var dist = global_position.distance_to(enemic.global_position)
		if dist <= defensa_range and dist < millor_dist:
			millor_dist = dist
			millor = enemic
	if millor:
		temps_darrer_defensa = 0.0
		disparar_projectil(millor)

func atacar_enemic_melee():
	if temps_darrer_defensa < defensa_cooldown:
		return
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(enemic):
			continue
		if global_position.distance_to(enemic.global_position) <= defensa_range:
			temps_darrer_defensa = 0.0
			if enemic.has_method("prendre_dany"):
				enemic.prendre_dany(defensa_dany)
			# Petita "mossegada" visual
			var t := create_tween()
			t.tween_property(sprite, "scale", Vector3(1.25, 0.8, 1.0), 0.06)
			t.tween_property(sprite, "scale", Vector3.ONE, 0.12)
			return

func disparar_projectil(objetiu: Node3D):
	if not projectil_escena:
		push_warning("No hi ha escena de projectil assignada")
		return
	var projectil = projectil_escena.instantiate()
	get_parent().add_child(projectil)
	projectil.global_position = global_position + Vector3(0, 0.5, 0)
	if projectil.has_method("inicialitzar"):
		projectil.inicialitzar(objetiu, defensa_dany, defensa_velocitat, defensa_abast, self)

func prendre_dany(quantitat: int):
	# Una flor a prop protegeix (només compta la que protegeix més)
	var millor_proteccio := 0.0
	for flor in _flors_properes():
		millor_proteccio = maxf(millor_proteccio, flor.proteccio)
	var dany := maxi(1, int(ceil(quantitat * (1.0 - millor_proteccio))))

	vida_actual -= dany
	temps_des_del_dany = 0.0
	vida_acumulada = 0.0
	barra_vida.mostrar(vida_actual, vida_maxima)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(0.85, 1.15, 1.0), 0.05)
	t.tween_property(sprite, "scale", Vector3.ONE, 0.1)
	if vida_actual <= 0:
		_morir()

func _regenerar(delta: float) -> void:
	if vida_actual >= vida_maxima or vida_actual <= 0:
		return
	temps_des_del_dany += delta
	if temps_des_del_dany < ESPERA_REGENERACIO:
		return
	var ritme := regeneracio * vida_maxima * (1.0 if GestorTemps.es_nit() else 3.0)
	vida_acumulada += ritme * delta
	if vida_acumulada >= 1.0:
		var punts := int(vida_acumulada)
		vida_acumulada -= punts
		vida_actual = mini(vida_maxima, vida_actual + punts)
		barra_vida.mostrar(vida_actual, vida_maxima)   # quan torna a estar plena, s'amaga

func _morir():
	GestorOnades.cultiu_perdut()
	remove_from_group("cultius")
	remove_from_group("interactuables")
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.25)
	t.tween_callback(queue_free)
	GestorPartida.call_deferred("guardar_mundo")

# ─────────────── Collita (amb el sistema d'interacció: [F] Collir)

func punt_interaccio() -> Vector3:
	return global_position

func pot_interactuar(jugador) -> bool:
	return es_collita() and es_madur() and not recollit and not jugador.porta_objecte()

func text_interaccio(_jugador) -> String:
	return "Collir raïm"

func interactuar(_jugador) -> void:
	var raim := randi_range(raim_min, raim_max)
	Inventari.afegir("raim", raim)
	TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.2, "+%d 🍇" % raim, Color(0.75, 0.55, 1.0))
	for i in range(randi_range(1, 2)):
		generar_llavor_drop()
	EventBus.emit_signal("cultiu_recollit", global_position)

	if tipus_cultiu == TipusCultiu.VINYEDO:
		# El cep no desapareix: torna a fer raïm d'aquí a uns dies
		estat_actual = Estat.GRAN
		dies_passats = 0
		actualitzar_sprite()
	else:
		recollit = true
		remove_from_group("cultius")
		queue_free()
	GestorPartida.guardar_mundo()

func generar_llavor_drop():
	if not llavor_drop_escena:
		return
	var drop = llavor_drop_escena.instantiate()
	get_parent().add_child(drop)
	var offset = Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
	drop.global_position = global_position + offset
	drop.tipus_llavor = "llavor_raim"
	drop.quantitat = 1
