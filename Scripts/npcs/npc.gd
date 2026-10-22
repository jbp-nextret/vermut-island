extends CharacterBody3D
class_name NPC
## Un habitant de l'illa. Té l'aspecte del jugador amb altres colors (fins que hi hagi
## sprites propis), passeja a prop de casa seva i s'hi pot parlar amb F (un diàleg de
## Dialogic). Si està al grup del jugador, el segueix i l'ajuda (vegeu Grup).

enum Estat { QUIET, PASSEJANT, SEGUINT, AJUDANT, TORNANT }

## Identificador: el mateix que el personatge de Dialogic i el que fan servir les missions
@export var id := ""
@export var nom := ""
## Timeline de Dialogic (identificador, p. ex. "marta", o camí a un .dtl)
@export var dialeg := ""
## Colors de cada part (vegeu Customization.VARIANTS)
@export var variants := {"hair": "black", "skin": "tan", "eyes": "green", "tshirt": "blue", "jeans": "brown", "boots": "brown"}
@export var radi_passeig := 2.5
@export var velocitat := 1.6
@export_group("Company")
## Com ajuda quan és al grup: "regar", "transportar"
@export var ajudes: Array[String] = []

const GRAVETAT := 20.0
const DISTANCIA_SEGUIR := 1.8      # no s'acosta més que això al jugador
const DISTANCIA_TELEPORT := 16.0   # si queda tan lluny, apareix al costat del jugador
const RADI_AJUDA := 7.0            # busca feina a aquesta distància del jugador
const INTERVAL_AJUDA := 5.0
const SEPARACIO_CAPES := 0.002

@onready var aparenca: Node3D = $Aparenca
@onready var sprites := {
	"hair": $Aparenca/Skeleton/hair, "skin": $Aparenca/Skeleton/skin, "eyes": $Aparenca/Skeleton/eyes,
	"tshirt": $Aparenca/Skeleton/tshirt, "jeans": $Aparenca/Skeleton/jeans, "boots": $Aparenca/Skeleton/boots,
}

var estat := Estat.QUIET
var casa := Vector3.ZERO
var desti := Vector3.ZERO
var temps_estat := 0.0
var temps_ajuda := 0.0
var feina: Node3D = null
var marcador: Label3D
var etiqueta_nom: Label3D
var posicions_capes := {}
# El mateix ordre de capes que el jugador (pell, ulls, roba, cabell)
const PRIORITATS := {"skin": 0, "eyes": 1, "jeans": 1, "tshirt": 2, "boots": 2, "hair": 3}

func _ready():
	add_to_group("npcs")
	add_to_group("interactuables")
	casa = global_position
	Customization.aplicar_variants(sprites, variants)
	for part in sprites:
		var s: AnimatedSprite3D = sprites[part]
		s.render_priority = PRIORITATS[part]
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		posicions_capes[s] = s.position
	_animar(Vector3.ZERO)

	marcador = _label(96, Color(1.0, 0.85, 0.2))
	marcador.pixel_size = 0.01
	marcador.outline_size = 20
	marcador.position = Vector3.UP * 2.25
	add_child(marcador)
	etiqueta_nom = _label(28, Color(1, 1, 1, 0.85))
	etiqueta_nom.position = Vector3.UP * 2.05
	etiqueta_nom.text = nom
	etiqueta_nom.visible = false
	add_child(etiqueta_nom)

	Grup.grup_canviat.connect(_on_grup_canviat)
	if Grup.es_membre(id):
		estat = Estat.SEGUINT
		_apareixer_quan_estigui_llest()

func _label(mida: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = mida
	l.outline_size = 12
	l.pixel_size = 0.006
	l.modulate = color
	return l

# ─────────────── Interacció (tecla F)

func pot_interactuar(jugador) -> bool:
	if Converses.parlant() or dialeg.is_empty():
		return false
	# Els companys et segueixen de molt a prop: per parlar-hi t'hi has d'acostar més (si no,
	# el "Parlar amb..." taparia collir i altres coses)
	if Grup.es_membre(id):
		return _pla(jugador.global_position - global_position).length() < 1.0
	return true

func text_interaccio(_jugador) -> String:
	return "Parlar amb %s" % nom

func punt_interaccio() -> Vector3:
	return global_position

func interactuar(jugador) -> void:
	_mirar_cap_a(jugador.global_position - global_position)
	velocity = Vector3.ZERO
	estat = Estat.SEGUINT if Grup.es_membre(id) else Estat.QUIET
	temps_estat = 0.0
	Missions.parlat_amb(id)
	Converses.parlar(self)

# ─────────────── Cada frame

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVETAT * delta
	else:
		velocity.y = 0.0
	# Si per algun motiu cau al buit, torna a casa (o al costat del jugador, si és del grup)
	if global_position.y < -10.0:
		if Grup.es_membre(id):
			_apareixer_al_costat_del_jugador()
		else:
			global_position = casa
		velocity = Vector3.ZERO
	temps_estat += delta

	var moviment := Vector3.ZERO
	if Converses.npc_actual == self:
		moviment = Vector3.ZERO   # quiet mentre parla
	else:
		match estat:
			Estat.QUIET:
				if temps_estat > randf_range(3.0, 6.0) and radi_passeig > 0.0:
					var angle := randf() * TAU
					desti = casa + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.5, radi_passeig)
					_canviar_estat(Estat.PASSEJANT)
			Estat.PASSEJANT:
				moviment = _cap_a(desti, 0.3)
				if moviment == Vector3.ZERO or temps_estat > 6.0:
					_canviar_estat(Estat.QUIET)
			Estat.TORNANT:
				moviment = _cap_a(casa, 0.5)
				if moviment == Vector3.ZERO:
					_canviar_estat(Estat.QUIET)
			Estat.SEGUINT:
				moviment = _seguir_jugador(delta)
			Estat.AJUDANT:
				moviment = _ajudar()

	velocity.x = moviment.x * velocitat * (1.6 if estat in [Estat.SEGUINT, Estat.AJUDANT] else 1.0)
	velocity.z = moviment.z * velocitat * (1.6 if estat in [Estat.SEGUINT, Estat.AJUDANT] else 1.0)
	move_and_slide()
	_animar(moviment)

func _process(_delta):
	_separar_capes()
	var m := Missions.marcador_npc(id)
	marcador.text = m
	marcador.visible = not m.is_empty() and Converses.npc_actual != self
	# El nom surt quan el jugador és a prop
	var jugador := _jugador()
	etiqueta_nom.visible = jugador != null and _pla(jugador.global_position - global_position).length() < 4.0 and Converses.npc_actual != self and not marcador.visible

func _canviar_estat(nou: Estat):
	estat = nou
	temps_estat = 0.0

## Direcció (horitzontal, normalitzada) cap a un punt, o zero si ja hi és
func _cap_a(punt: Vector3, marge: float) -> Vector3:
	var d := _pla(punt - global_position)
	return Vector3.ZERO if d.length() < marge else d.normalized()

# ─────────────── Company

func _on_grup_canviat():
	if Grup.es_membre(id):
		if estat not in [Estat.SEGUINT, Estat.AJUDANT]:
			_canviar_estat(Estat.SEGUINT)
	elif estat in [Estat.SEGUINT, Estat.AJUDANT]:
		feina = null
		_canviar_estat(Estat.TORNANT)

func _seguir_jugador(delta: float) -> Vector3:
	var jugador := _jugador()
	if jugador == null:
		return Vector3.ZERO
	var d := _pla(jugador.global_position - global_position)
	if d.length() > DISTANCIA_TELEPORT or absf(jugador.global_position.y - global_position.y) > 5.0:
		_apareixer_al_costat_del_jugador()
		return Vector3.ZERO
	# Busca feina de tant en tant
	temps_ajuda += delta
	if temps_ajuda >= INTERVAL_AJUDA:
		temps_ajuda = 0.0
		feina = _buscar_feina(jugador)
		if feina:
			_canviar_estat(Estat.AJUDANT)
			return Vector3.ZERO
	# Cada company es queda a un costat diferent, una mica per darrere
	var index := Grup.membres.find(id)
	var costat := Vector3(-1.2 if index == 0 else 1.2, 0, 0.8)
	var objectiu: Vector3 = jugador.global_position + costat
	if _pla(objectiu - global_position).length() < 0.4 or d.length() < DISTANCIA_SEGUIR * 0.6:
		return Vector3.ZERO
	return _cap_a(objectiu, 0.4)

func _buscar_feina(jugador: Node3D) -> Node3D:
	if "regar" in ajudes:
		var millor: Node3D = null
		var millor_d := RADI_AJUDA
		for c in get_tree().get_nodes_in_group("cultius"):
			if not c.necessita_aigua() or c.has_meta("regant"):
				continue
			var dist := _pla(c.global_position - jugador.global_position).length()
			if dist < millor_d:
				millor = c
				millor_d = dist
		if millor:
			millor.set_meta("regant", true)   # que dos companys no vagin al mateix
		return millor
	return null

func _ajudar() -> Vector3:
	if not is_instance_valid(feina) or temps_estat > 8.0:
		_acabar_feina()
		return Vector3.ZERO
	var moviment := _cap_a(feina.global_position, 0.9)
	if moviment == Vector3.ZERO:
		_mirar_cap_a(feina.global_position - global_position)
		feina.regar()
		Progressio.accio_feta.emit("regar", 1)   # compta per a les missions (sense XP)
		TextFlotant.mostrar(get_parent(), feina.global_position + Vector3.UP * 0.8, "💧", Color(0.5, 0.8, 1.0))
		_acabar_feina()
	return moviment

func _acabar_feina():
	if is_instance_valid(feina):
		feina.remove_meta("regant")
	feina = null
	_canviar_estat(Estat.SEGUINT)

## En carregar el món: espera que el terreny tingui col·lisions i que el jugador ja sigui
## al seu lloc (si no, el company apareixeria on no toca i cauria al buit)
func _apareixer_quan_estigui_llest():
	set_physics_process(false)
	for i in 3:
		await get_tree().physics_frame
	_apareixer_al_costat_del_jugador()
	set_physics_process(true)

func _apareixer_al_costat_del_jugador():
	var jugador := _jugador()
	if jugador == null:
		return
	var index := maxi(0, Grup.membres.find(id))
	global_position = jugador.global_position + Vector3(-1.2 if index == 0 else 1.2, 0.3, 0.8)
	velocity = Vector3.ZERO

func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

# ─────────────── Aspecte

func _animar(moviment: Vector3):
	if moviment == Vector3.ZERO:
		_reproduir("idle", _mirall)
		return
	_mirar_cap_a(moviment)
	_reproduir("walk_" + _direccio, _mirall)

var _direccio := "down"
var _mirall := false

## Igual que el jugador: de costat (amb mirall), amunt o avall, segons la càmera
func _mirar_cap_a(direccio: Vector3):
	var camera := get_viewport().get_camera_3d()
	if camera == null or _pla(direccio).length() < 0.01:
		return
	var enrere := camera.global_basis.z
	var local := _pla(direccio).rotated(Vector3.UP, -atan2(enrere.x, enrere.z))
	if absf(local.x) >= absf(local.z) * 0.8:
		_direccio = "right"
		_mirall = local.x < 0
	else:
		_direccio = "down" if local.z > 0 else "up"
		_mirall = false

func _reproduir(anim: String, mirall: bool):
	for s in sprites.values():
		if s.sprite_frames == null:
			continue
		var a := anim if s.sprite_frames.has_animation(anim) else "idle"
		if s.animation != a:
			s.play(a)
		s.flip_h = mirall
	# Totes les capes al mateix fotograma
	var skin: AnimatedSprite3D = sprites.skin
	for s in sprites.values():
		if s != skin and s.animation == skin.animation:
			s.frame = skin.frame

## Les capes s'avancen una mica cap a la càmera segons l'ordre (com el jugador)
func _separar_capes():
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var cap_camera := camera.global_basis.z
	for s in sprites.values():
		s.global_position = s.get_parent().to_global(posicions_capes[s]) + cap_camera * SEPARACIO_CAPES * (s.render_priority + 1)

static func _pla(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
