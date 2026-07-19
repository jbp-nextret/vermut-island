extends Node3D
class_name PersonatgePreview

@export var hair: AnimatedSprite3D
@export var skin: AnimatedSprite3D
@export var eyes: AnimatedSprite3D
@export var tshirt: AnimatedSprite3D
@export var jeans: AnimatedSprite3D
@export var boots: AnimatedSprite3D

@onready var sprites: Array[AnimatedSprite3D] = [hair, skin, eyes, tshirt, jeans, boots]

func _ready() -> void:
	Customization.aplicar_aparenca(_sprites())
	for sprite in sprites:
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.animation = "idle"
			sprite.frame = 0
			sprite.play()

func _sprites() -> Dictionary:
	return {
		"hair": hair, "skin": skin, "eyes": eyes,
		"tshirt": tshirt, "jeans": jeans, "boots": boots,
	}

func canviar_color(part: String, variant: String) -> void:
	Customization.canviar_variant(part, variant, _sprites())
