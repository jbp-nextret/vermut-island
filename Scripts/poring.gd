extends CharacterBody3D
class_name Poring

enum State { NONE, WALKING_TO_SEAT, WAITING_ORDER, EATING, LEAVING }

var state: State = State.NONE

signal order_placed(poring: Poring, product: String)
signal left(poring: Poring)

@export var speed := 1.5          # ara són unitats/segon, no píxels
@export var patience := 30.0
@export var eat_time := 6.0
@export var products: Array[String] = ["vermut"]
@export var product_icons: Dictionary = {
	"vermut": preload("res://Sprites/drinks/vermut/vermut_icon.tres"),
}

@onready var order_icon: Sprite3D = $OrderBubble/Icon   # o $OrderBubble si no tens fons

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var order_bubble: Node3D = $OrderBubble


var seat: Seat
var exit_pos: Vector3
var floor_y: float
var order := ""
var wait_time := 0.0

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
			if wait_time >= patience:
				_change_state(State.LEAVING)
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
			wait_time = 0.0
			order_bubble.show()
			order_placed.emit(self, order)
		State.EATING:
			order_bubble.hide()
			sprite.play("eating")
			await get_tree().create_timer(eat_time).timeout
			_change_state(State.LEAVING)
		State.LEAVING:
			order_bubble.hide()
			seat.occupant = null
			global_position.y = floor_y   # baixa de la cadira
			sprite.play("walking")

func serve(drink: Drink) -> bool:
	if state != State.WAITING_ORDER or drink.product != order:
		return false
	drink.start_drinking(eat_time)
	_change_state(State.EATING)
	return true
