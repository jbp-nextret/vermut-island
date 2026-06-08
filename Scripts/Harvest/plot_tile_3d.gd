class_name PlotTile3D
extends Node3D

signal crop_ready(plot)
signal crop_harvested(ingredient: IngredientData)

@export var seed_data: SeedData

@onready var sprite := $AnimatedSprite3D
@onready var area := $Area3D

enum State { EMPTY, GROWING, READY, WILTED }
var state := State.EMPTY
var days_grown := 0
var quality := 1.0
var watered_today := false

func plant(seed: SeedData) -> void:
	seed_data = seed
	state = State.GROWING
	days_grown = 0
	quality = 1.0
	sprite.play("sprout")

func water() -> void:
	watered_today = true
	# efecte visual: partícula d'aigua, so, etc.

func advance_day() -> void:
	if state != State.GROWING:
		return
	if not watered_today:
		quality -= 0.2  # penalització per no regar
	watered_today = false
	days_grown += 1
	_update_visual()
	if days_grown >= seed_data.grow_days:
		state = State.READY
		sprite.play("mature")
		crop_ready.emit(self)

func harvest() -> IngredientData:
	var item := IngredientData.new()
	item.nom = seed_data.nom
	item.quality = clampf(quality, 0.0, 1.0)
	item.quantity = seed_data.rendiment_base
	state = State.EMPTY
	sprite.play("empty")
	crop_harvested.emit(item)
	return item

func _update_visual() -> void:
	var progress := float(days_grown) / seed_data.grow_days
	sprite.scale = Vector3.ONE * lerpf(0.3, 1.0, progress)
	if progress < 0.5:
		sprite.play("sprout")
	else:
		sprite.play("growing")

func _ready() -> void:
	area.input_event.connect(_on_input_event)

func _on_input_event(_cam, event, _pos, _normal, _idx) -> void:
	if event is InputEventMouseButton and event.pressed:
		if state == State.READY:
			harvest()
		elif state == State.EMPTY:
			GameManager.open_seed_selector(self)
