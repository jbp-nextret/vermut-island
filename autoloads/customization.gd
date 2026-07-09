extends Node

const VARIANTS := {
	"hair": ["brown", "black", "blonde"],
	"eyes": ["blue", "green", "ambar"],
	"skin": ["light", "tan", "dark"],
	"tshirt": ["green", "blue", "red"],
	"jeans": ["blue", "brown", "green"],
	"boots": ["black", "brown", "tan"],
}

var nom: String = "Jugador"
var variants_actuals: Dictionary = {
	"hair": "brown",
	"eyes": "blue",
	"skin": "light",
	"tshirt": "green",
	"jeans": "blue",
	"boots": "black",
}

var _originals: Dictionary = {}          # instance_id del sprite -> SpriteFrames original
var _cache_sprite_frames: Dictionary = {} # "part:variant" -> SpriteFrames

func canviar_variant(part: String, variant: String, sprites: Dictionary = {}) -> void:
	if not VARIANTS.has(part):
		push_warning("No existeix la part: " + part)
		return
	variants_actuals[part] = variant
	if sprites.has(part):
		_aplicar_variant(part, variant, sprites[part])
	_resincronitzar(sprites)

func aplicar_aparenca(sprites: Dictionary) -> void:
	for part in sprites.keys():
		_aplicar_variant(part, variants_actuals.get(part, VARIANTS[part][0]), sprites[part])

func _aplicar_variant(part: String, variant: String, sprite: AnimatedSprite3D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	# Guarda l'original NOMÉS la primera vegada, abans de tocar-lo
	var id := sprite.get_instance_id()
	if not _originals.has(id):
		_originals[id] = sprite.sprite_frames

	var original: SpriteFrames = _originals[id]

	var clau := part + ":" + variant
	if not _cache_sprite_frames.has(clau):
		print("Construint SpriteFrames per part=", part, " variant=", variant)
		_cache_sprite_frames[clau] = _construir_sprite_frames(original, variant)

	var anim_actual := sprite.animation
	var frame_actual := sprite.frame
	var estava_reproduint := sprite.is_playing()

	sprite.sprite_frames = _cache_sprite_frames[clau]

	if sprite.sprite_frames.has_animation(anim_actual):
		sprite.animation = anim_actual
		sprite.frame = frame_actual
		if estava_reproduint:
			sprite.play()

func _construir_sprite_frames(original: SpriteFrames, variant: String) -> SpriteFrames:
	var nou := SpriteFrames.new()
	for anim in original.get_animation_names():
		nou.add_animation(anim)
		nou.set_animation_speed(anim, original.get_animation_speed(anim))
		nou.set_animation_loop(anim, original.get_animation_loop(anim))
		for i in original.get_frame_count(anim):
			var tex := original.get_frame_texture(anim, i)
			var duracio := original.get_frame_duration(anim, i)
			print("Construint frame: anim=", anim, " frame=", i, " tex_path=", tex.resource_path if not (tex is AtlasTexture) else (tex as AtlasTexture).atlas.resource_path)
			var nova_tex := _construir_frame_texture(tex, variant)
			nou.add_frame(anim, nova_tex, duracio)
	return nou

func _construir_frame_texture(tex: Texture2D, variant: String) -> Texture2D:
	if tex is AtlasTexture:
		var original_atlas: AtlasTexture = tex
		var path_base := _path_original(original_atlas.atlas)
		var nou_path := _path_variant(path_base, variant)
		var nova_base: Texture2D = load(nou_path)
		if nova_base == null:
			push_warning("No trobat: " + nou_path + " (mantenint original)")
			return tex
		var nou_atlas := AtlasTexture.new()
		nou_atlas.atlas = nova_base
		nou_atlas.region = original_atlas.region
		nou_atlas.margin = original_atlas.margin
		return nou_atlas
	else:
		var path_base := _path_original(tex)
		var nou_path := _path_variant(path_base, variant)
		var nova_tex: Texture2D = load(nou_path)
		if nova_tex == null:
			push_warning("No trobat: " + nou_path + " (mantenint original)")
			return tex
		return nova_tex

func _path_original(tex: Texture2D) -> String:
	var actual: Texture2D = tex
	var nivell := 0
	while actual != null:
		print("  Nivell ", nivell, ": tipus=", actual.get_class(), " path='", actual.resource_path, "'")
		if actual is AtlasTexture:
			var atlas_tex: AtlasTexture = actual
			actual = atlas_tex.atlas
		else:
			break
		nivell += 1
	if actual == null:
		return ""
	return actual.resource_path

func _path_variant(original_path: String, variant: String) -> String:
	var directori := original_path.get_base_dir()
	var fitxer := original_path.get_file()
	return directori + "/variants/" + variant + "/" + fitxer
	
func _resincronitzar(sprites: Dictionary) -> void:
	for part in sprites.keys():
		var sprite: AnimatedSprite3D = sprites[part]
		if sprite == null or sprite.sprite_frames == null:
			continue
		var anim := sprite.animation
		if sprite.sprite_frames.has_animation(anim):
			sprite.stop()
			sprite.frame = 0
			sprite.play(anim)
