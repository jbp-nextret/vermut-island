extends Node

const SHADER_TINT: Shader = preload("res://shaders/tint_part.gdshader")
const SHADER_TINT_ULLS: Shader = preload("res://shaders/tint_part_llindar.gdshader")

var colors_actuals: Dictionary = {
	"hair": Color("cc9a13ff"),
	"skin": Color("f2c9a1"),
	"eyes": Color("4fdfffff"),
	"tshirt": Color.DARK_RED,
	"jeans": Color.CADET_BLUE,
	"boots": Color.SADDLE_BROWN,
}

var llindar_ulls: float = 0.9

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
