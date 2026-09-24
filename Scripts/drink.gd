extends Node3D
class_name Drink

@export var product := "vermut"
@export var anim_name := "buidar"

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
	sprite.animation = anim_name
	sprite.frame = 0          # comença ple
	sprite.pause()

# Es buida en exactament "duration" segons, tingui els frames que tingui
func start_drinking(duration: float) -> void:
	var last := sprite.sprite_frames.get_frame_count(anim_name) - 1
	var tween := create_tween()
	tween.tween_method(func(t: float): sprite.frame = int(round(t * last)), 0.0, 1.0, duration)
	tween.tween_callback(queue_free)
