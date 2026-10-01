extends Node3D
## Espasa del jugador (script del PivotEspasa).
##
## El cop s'anima amb tweens: anticipació → cop ràpid → petit rebot → torna.
## Els angles surten de les animacions "sword_attack_*" de l'AnimationPlayer,
## així que per ajustar-los n'hi ha prou d'editar-les allà.
##
## Els impactes es calculen per arc (distància + angle davant del jugador), no per
## contacte físic: així també toca els ratpenats que ataquen suspesos una mica lluny.

signal cop_encertat(enemic: Node3D, dany: int)

@onready var sprite_espasa: Sprite3D = $Espasa/EspasaSprite
@onready var hitbox: Area3D = $Espasa/EspasaSprite/Hitbox
@onready var slash_tall: Sprite3D = $Espasa/SlashTall
@onready var slash_estocada: Sprite3D = $Espasa/SlashEstocada
@export var slash_colors: Array[Color] = [Color.WHITE, Color(0.8, 0.9, 1.0), Color(1.0, 0.95, 0.7)]

const ABAST := {"tall": 2.0, "estocada": 2.7}
const MIG_ANGLE := {"tall": 80.0, "estocada": 30.0}   # obertura del con, a cada costat
const ALCADA_MAXIMA := 2.4                            # ratpenats una mica alts també compten

# Temps de cada fase del cop (segons)
const ANTICIPACIO := 0.07
const COP := 0.08
const REBOT := 0.07
const RECUPERACIO := 0.08

var dany_actual := 10
var tipus_actual := "tall"
var cop_actiu := false
var ja_tocats := {}
var jugador: Node3D
var tween_cop: Tween

func _ready():
	jugador = owner
	# La detecció antiga per contacte (i el component Hitbox) ja no es fan servir
	hitbox.monitoring = false
	hitbox.monitorable = false
	slash_tall.visible = false
	slash_estocada.visible = false

## Fa el cop i retorna quant dura
func atacar(tipus: String, animacio: Animation, dany: int, invers: bool) -> float:
	tipus_actual = tipus
	dany_actual = dany
	ja_tocats.clear()
	if tween_cop:
		tween_cop.kill()

	var inici: Vector3 = animacio.track_get_key_value(0, 0)
	var final: Vector3 = animacio.track_get_key_value(0, animacio.track_get_key_count(0) - 1)
	position = animacio.track_get_key_value(1, 0)
	if invers:   # als combos, el segon cop va en sentit contrari
		var t := inici
		inici = final
		final = t
	var recorregut := final - inici
	rotation = inici
	sprite_espasa.scale = Vector3.ONE

	var slash := slash_estocada if tipus == "estocada" else slash_tall
	tween_cop = create_tween()
	# 1. Anticipació: tira l'espasa enrere
	tween_cop.tween_property(self, "rotation", inici - recorregut * 0.2, ANTICIPACIO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Cop: molt ràpid, s'activa el dany i es veu el tall
	tween_cop.tween_callback(func(): _obrir_finestra_cop(slash))
	tween_cop.tween_property(self, "rotation", final + recorregut * 0.12, COP).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if tipus == "estocada":
		tween_cop.parallel().tween_property(sprite_espasa, "scale", Vector3(1.0, 1.35, 1.0), COP)
	# 3. Rebot i recuperació
	tween_cop.tween_callback(func(): cop_actiu = false)
	tween_cop.tween_property(self, "rotation", final, REBOT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_cop.parallel().tween_property(sprite_espasa, "scale", Vector3.ONE, REBOT)
	tween_cop.tween_interval(RECUPERACIO)
	return ANTICIPACIO + COP + REBOT + RECUPERACIO

func _obrir_finestra_cop(slash: Sprite3D):
	cop_actiu = true
	_comprovar_cops()   # de seguida, i després cada frame mentre dura
	_mostrar_slash(slash)

func _physics_process(_delta):
	if cop_actiu:
		_comprovar_cops()

func _comprovar_cops():
	if not jugador or not jugador.has_method("_direccio_mirada"):
		return
	var davant: Vector3 = jugador._direccio_mirada()
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if ja_tocats.has(enemic) or not is_instance_valid(enemic):
			continue
		var cap_enemic: Vector3 = enemic.global_position - jugador.global_position
		if absf(cap_enemic.y) > ALCADA_MAXIMA:
			continue
		var pla := Vector3(cap_enemic.x, 0, cap_enemic.z)
		if pla.length() > ABAST[tipus_actual]:
			continue
		if pla.length() > 0.4 and rad_to_deg(davant.angle_to(pla.normalized())) > MIG_ANGLE[tipus_actual]:
			continue
		ja_tocats[enemic] = true
		enemic.prendre_dany(dany_actual, jugador.global_position)
		cop_encertat.emit(enemic, dany_actual)

func _mostrar_slash(slash: Sprite3D):
	slash.rotation_degrees.z = randf_range(-15.0, 15.0)
	var mida := randf_range(1.1, 1.4) if slash == slash_estocada else randf_range(0.8, 1.0)
	slash.modulate = slash_colors[randi() % slash_colors.size()]
	slash.modulate.a = 1.0
	slash.scale = Vector3.ONE * mida * 0.6
	slash.visible = true
	var t := create_tween().set_parallel(true)
	t.tween_property(slash, "scale", Vector3.ONE * mida, COP).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(slash, "modulate:a", 0.0, 0.16).set_delay(COP * 0.6)
	t.chain().tween_callback(func(): slash.visible = false)

# Les animacions encara criden aquests mètodes: ara no fan res
func activar_hitbox(): pass
func desactivar_hitbox(): pass
func mostrar_slash_tall(): pass
func amagar_slash_tall(): pass
func mostrar_slash_estocada(): pass
func amagar_slash_estocada(): pass
