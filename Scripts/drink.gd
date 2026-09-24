extends Node3D
class_name Drink

@export var product := "vermut"
@export var anim_name := "buidar"
@export var mida := 0.5   # escala del got (el sprite fa 16 px amb pixel_size 0.05)

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
	scale = Vector3.ONE * mida
	sprite.animation = anim_name
	sprite.frame = 0          # comença ple
	sprite.pause()
	# L'origen passa a ser la base del got, perquè quedi recolzat sobre la taula
	var textura := sprite.sprite_frames.get_frame_texture(anim_name, 0)
	if textura:
		sprite.offset.y = textura.get_height() / 2.0

# Es buida en exactament "duration" segons, tingui els frames que tingui
func start_drinking(duration: float) -> void:
	var last := sprite.sprite_frames.get_frame_count(anim_name) - 1
	var tween := create_tween()
	tween.tween_method(func(t: float): sprite.frame = int(round(t * last)), 0.0, 1.0, duration)
	tween.tween_callback(queue_free)
