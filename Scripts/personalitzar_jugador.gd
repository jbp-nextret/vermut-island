extends Node3D
class_name PersonalitzacioJugador

const SHADER_TINT: Shader = preload("res://shaders/tint_part.gdshader")
const SHADER_TINT_ULLS: Shader = preload("res://shaders/tint_part_llindar.gdshader")

@export var hair: AnimatedSprite3D
@export var skin: AnimatedSprite3D
@export var eyes: AnimatedSprite3D
@export var clothes: AnimatedSprite3D

var colors_actuals: Dictionary = {
	"hair": Color("3b2a1a"),
	"skin": Color("f2c9a1"),
	"eyes": Color("2b2b2b"),
	"clothes": Color.WHITE,
}

func _ready() -> void:
	_preparar_materials()
	aplicar_tots_els_colors()

func _preparar_materials() -> void:
	for nom_part in colors_actuals.keys():
		var sprite: AnimatedSprite3D = _sprite_per_nom(nom_part)
		if sprite == null:
			push_warning("Falta assignar el sprite: " + nom_part)
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_TINT_ULLS if nom_part == "eyes" else SHADER_TINT
		sprite.material_override = mat

func canviar_color_part(nom_part: String, nou_color: Color) -> void:
	if not colors_actuals.has(nom_part):
		push_warning("No existeix la part: " + nom_part)
		return
	colors_actuals[nom_part] = nou_color
	var sprite: AnimatedSprite3D = _sprite_per_nom(nom_part)
	if sprite and sprite.material_override:
		sprite.material_override.set_shader_parameter("color_tint", nou_color)

func aplicar_tots_els_colors() -> void:
	for nom_part in colors_actuals.keys():
		canviar_color_part(nom_part, colors_actuals[nom_part])

func ajustar_llindar_ulls(valor: float) -> void:
	if eyes and eyes.material_override:
		eyes.material_override.set_shader_parameter("llindar_blanc", valor)

func _sprite_per_nom(nom_part: String) -> AnimatedSprite3D:
	match nom_part:
		"hair": return hair
		"skin": return skin
		"eyes": return eyes
		"clothes": return clothes
		_: return null
