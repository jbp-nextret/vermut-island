extends Node

const SHADER_TINT: Shader = preload("res://shaders/tint_part.gdshader")
const SHADER_TINT_ULLS: Shader = preload("res://shaders/tint_part_llindar.gdshader")

var llindar_ulls: float = 0.9

# Nom personatge
var nom: String = "Keru"

# Default colors
var colors_actuals: Dictionary = {
	"hair": Color("cc9a13ff"),
	"skin": Color("f2c9a1"),
	"eyes": Color("c4ae6aff"),
	"tshirt": Color("61a86aff"),
	"jeans": Color("255b5aff"),
	"boots": Color("372805ff"),
}
# Skin tones
var body_color_options = [
	Color(0.96, 0.80, 0.69),
	Color(0.72, 0.54, 0.39),
	Color(0.45, 0.34, 0.27)
]
# Hair colors
var hair_color_options = [
	Color(0.341, 0.206, 0.061, 1.0),
	Color(0.072, 0.074, 0.069, 1.0),
	Color(1.0, 0.6, 0.0, 1.0)
]
# T-shirt colors
var tshirt_color_options = [
	Color(0.367, 0.521, 0.018, 1.0),
	Color(0.417, 0.537, 0.998, 1.0),
	Color(1.0, 0.347, 0.28, 1.0)
]
# Jeans colors
var jeans_color_options = [
	Color(0.169, 0.219, 0.64, 1.0),
	Color(0.321, 0.131, 0.019, 1.0),
	Color(0.367, 0.521, 0.018, 1.0)
]
# Boots color
var boots_color_options = [
	Color(0.063, 0.065, 0.065, 1.0),
	Color(0.321, 0.131, 0.019, 1.0),
	Color(0.737, 0.505, 0.267, 1.0)
]
# Selected values
var selected_body = ""
var selected_hair = ""
var selected_tshirt = ""
var selected_jeans = ""
var selected_boots = ""

func aplicar_aparenca(sprites: Dictionary) -> void:
	for nom_part in sprites.keys():
		var sprite: AnimatedSprite3D = sprites[nom_part]
		if sprite == null:
			continue
		_preparar_material(nom_part, sprite)
		_aplicar_color(nom_part, sprite)

func _preparar_material(nom_part: String, sprite: AnimatedSprite3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_TINT_ULLS if nom_part == "eyes" else SHADER_TINT
	sprite.material_override = mat

	if nom_part == "eyes":
		mat.set_shader_parameter("llindar_blanc", llindar_ulls)

	_actualitzar_textura(sprite, mat)

	var callable := Callable(self, "_on_frame_changed").bind(sprite, mat)

	if not sprite.frame_changed.is_connected(callable):
		sprite.frame_changed.connect(Callable(self, "_on_frame_changed").bind(sprite, mat)
)

func _on_frame_changed(sprite: AnimatedSprite3D, mat: ShaderMaterial) -> void:
	print("Frame changed: ",sprite.name, sprite.frame)
	_actualitzar_textura(sprite, mat)

func _actualitzar_textura(sprite: AnimatedSprite3D, mat: ShaderMaterial) -> void:
	if sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex:
		mat.set_shader_parameter("textura", tex)

func _aplicar_color(nom_part: String, sprite: AnimatedSprite3D) -> void:
	if sprite.material_override and colors_actuals.has(nom_part):
		sprite.material_override.set_shader_parameter("color_tint", colors_actuals[nom_part])

func canviar_color(nom_part: String, nou_color: Color, sprites: Dictionary = {}) -> void:
	if not colors_actuals.has(nom_part):
		push_warning("No existeix la part: " + nom_part)
		return
	colors_actuals[nom_part] = nou_color
	if sprites.has(nom_part):
		_aplicar_color(nom_part, sprites[nom_part])

func ajustar_llindar_ulls(valor: float, sprites: Dictionary = {}) -> void:
	llindar_ulls = valor
	if sprites.has("eyes") and sprites["eyes"].material_override:
		sprites["eyes"].material_override.set_shader_parameter("llindar_blanc", valor)
