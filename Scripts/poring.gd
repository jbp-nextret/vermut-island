extends CharacterBody3D
class_name Poring

enum State { NONE, WALKING_TO_SEAT, WAITING_ORDER, EATING, LEAVING }

signal order_placed(poring: Poring, product: String)
signal left(poring: Poring)
signal ha_pagat(poring: Poring, quantitat: int)
signal ha_marxat_enfadat(poring: Poring)

@export var speed := 1.5
@export var patience := 30.0
@export var eat_time := 6.0
@export var preu_base := 10
@export var propina_maxima := 5      # si el serveixes de seguida; 0 si és a punt de marxar
@export var product_icons: Dictionary = {
	"vermut": preload("res://Sprites/drinks/vermut/vermut_icon.tres"),
}

const COLOR_ENFADAT := Color(1.0, 0.15, 0.15)
const COLOR_DINERS := Color(1.0, 0.85, 0.3)

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var order_bubble: Node3D = $OrderBubble
@onready var order_icon: Sprite3D = $OrderBubble/Icon

var state: State = State.NONE
var seat: Seat
var exit_pos: Vector3
var floor_y: float
var order := ""
var wait_time := 0.0
var propina := 0
var posicio_bombolla: Vector3

func _ready() -> void:
	add_to_group("porings")
	add_to_group("interactuables")
	posicio_bombolla = order_bubble.position

func setup(target_seat: Seat, exit_position: Vector3) -> void:
	seat = target_seat
	seat.occupant = self
	exit_pos = exit_position
	floor_y = global_position.y
	_change_state(State.WALKING_TO_SEAT)

func _physics_process(delta: float) -> void:
	if state == State.NONE:
		return
	if state != State.LEAVING and not is_instance_valid(seat):
		_change_state(State.LEAVING)
		return
	match state:
		State.WALKING_TO_SEAT:
			if _move_towards(seat.get_sit_position()):
				global_position = seat.get_sit_position()   # "puja" a la cadira
				_change_state(State.WAITING_ORDER)
		State.WAITING_ORDER:
			wait_time += delta
			_actualitzar_paciencia()
			if wait_time >= patience:
				_marxar_enfadat()
		State.LEAVING:
			if _move_towards(exit_pos):
				left.emit(self)
				queue_free()

# Es mou només en el pla XZ; l'alçada no la toca
func _move_towards(target: Vector3) -> bool:
	var to_target := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if to_target.length() < 0.05:
		velocity = Vector3.ZERO
		return true
	velocity = to_target.normalized() * speed
	_update_flip()
	move_and_slide()
	return false

# Gira el sprite segons si va cap a l'esquerra o la dreta *de la càmera*
func _update_flip() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		sprite.flip_h = velocity.dot(cam.global_basis.x) < 0

func _change_state(new_state: State) -> void:
	state = new_state
	match state:
		State.WALKING_TO_SEAT:
			sprite.play("walking")
		State.WAITING_ORDER:
			sprite.play("idle")
			order = product_icons.keys().pick_random()
			order_icon.texture = product_icons[order]
			order_icon.modulate = Color.WHITE
			wait_time = 0.0
			_mostrar_bombolla()
			order_placed.emit(self, order)
		State.EATING:
			_amagar_bombolla()
			sprite.play("eating")
			# Un tween lligat al poring: si el poring desapareix, el tween també
			create_tween().tween_callback(_acabar_de_beure).set_delay(eat_time)
		State.LEAVING:
			_amagar_bombolla()
			if is_instance_valid(seat):
				seat.occupant = null
			global_position.y = floor_y   # baixa de la cadira
			sprite.play("walking")

# ─────────────── Paciència

func _actualitzar_paciencia() -> void:
	var r := clampf(wait_time / patience, 0.0, 1.0)
	# La icona es va tornant vermella...
	order_icon.modulate = Color.WHITE.lerp(COLOR_ENFADAT, r)
	# ...i l'últim quart de la paciència la bombolla tremola
	if r > 0.75:
		var forca := (r - 0.75) * 0.3
		order_bubble.position = posicio_bombolla + Vector3(sin(Time.get_ticks_msec() * 0.04) * forca, 0, 0)
	else:
		order_bubble.position = posicio_bombolla

func _marxar_enfadat() -> void:
	TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.4, "Grr!", COLOR_ENFADAT)
	ha_marxat_enfadat.emit(self)
	_change_state(State.LEAVING)

func _mostrar_bombolla() -> void:
	order_bubble.position = posicio_bombolla
	order_bubble.scale = Vector3.ONE * 0.2
	order_bubble.show()
	create_tween().tween_property(order_bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _amagar_bombolla() -> void:
	order_bubble.hide()
	order_bubble.position = posicio_bombolla

# ─────────────── Servir i pagar

func serve(drink: Drink) -> bool:
	if state != State.WAITING_ORDER or drink.product != order:
		return false
	# Com més ràpid el serveixes, més propina
	propina = int(round(propina_maxima * (1.0 - clampf(wait_time / patience, 0.0, 1.0))))
	drink.start_drinking(eat_time)
	_change_state(State.EATING)
	return true

func _acabar_de_beure() -> void:
	if state != State.EATING:   # potser ja marxava (cadira eliminada...)
		return
	_pagar()
	_change_state(State.LEAVING)

func _pagar() -> void:
	var quantitat := preu_base + propina
	Inventari.afegir_diners(quantitat)
	TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.4, "+%d" % quantitat, COLOR_DINERS)
	ha_pagat.emit(self, quantitat)

# El bar tanca: qui encara no s'ha begut res se'n va; qui beu, acaba primer.
func marxar() -> void:
	if state == State.WALKING_TO_SEAT or state == State.WAITING_ORDER:
		_change_state(State.LEAVING)

# ─────────────── Interactuable (el jugador li porta la beguda)

func punt_interaccio() -> Vector3:
	return global_position

func pot_interactuar(jugador: InteraccioJugador) -> bool:
	return state == State.WAITING_ORDER \
		and jugador.objecte_portat is Drink \
		and jugador.objecte_portat.product == order \
		and is_instance_valid(seat) and seat.es_utilitzable()   # sense taula no es pot servir

func text_interaccio(_jugador: InteraccioJugador) -> String:
	return "Servir " + order

func interactuar(jugador: InteraccioJugador) -> void:
	var got: Drink = jugador.deixar_objecte()
	get_parent().add_child(got)
	got.global_position = _posicio_a_taula()
	serve(got)

## On deixar el got: a sobre de la taula del seient, a la vora que toca al poring.
func _posicio_a_taula() -> Vector3:
	var barra := seat.taula()

	var caixa := _aabb_global(barra)
	var marge := 0.15
	return Vector3(
		clampf(global_position.x, caixa.position.x + marge, caixa.end.x - marge),
		caixa.end.y,
		clampf(global_position.z, caixa.position.z + marge, caixa.end.z - marge))

func _aabb_global(node: Node3D) -> AABB:
	var resultat := AABB(node.global_position, Vector3.ZERO)
	var primer := true
	for m in node.find_children("*", "VisualInstance3D", true, false):
		var caixa: AABB = m.global_transform * m.get_aabb()
		resultat = caixa if primer else resultat.merge(caixa)
		primer = false
	return resultat
