class_name EinaMagica
## Eines espectrals que apareixen, fan un cop i s'esvaeixen (com l'aixada de llaurar):
## "destral" per talar arbres i "pic" per picar roques.

static var _textures := {}
static var _materials := {}

## Fa el cop a `punt`. Retorna quant triga a tocar (per sincronitzar-hi l'efecte).
static func invocar(pare: Node, punt: Vector3, eina: String, color: Color) -> float:
	var camera := pare.get_viewport().get_camera_3d()
	var pivot := Node3D.new()
	pare.add_child(pivot)
	pivot.global_position = punt
	var sprite := Sprite3D.new()
	sprite.texture = textura(eina)
	sprite.pixel_size = 0.05
	sprite.material_override = _material(eina)
	sprite.modulate = Color(color, 0.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(0, 0.8, 0)   # s'agafa pel mànec: el cap queda amunt
	pivot.add_child(sprite)

	# Mira a càmera i gira al voltant del seu eix (com un sprite 2D)
	var base := camera.global_basis if camera else Basis()
	var girar := func(angle: float): pivot.global_basis = base * Basis(Vector3(0, 0, 1), angle)
	girar.call(deg_to_rad(70))
	var t := pivot.create_tween()
	t.tween_property(sprite, "modulate:a", 0.95, 0.08)
	t.parallel().tween_method(girar, deg_to_rad(70), deg_to_rad(100), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_method(girar, deg_to_rad(100), deg_to_rad(-10), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_interval(0.1)
	t.tween_property(sprite, "modulate:a", 0.0, 0.18)
	t.tween_callback(pivot.queue_free)
	return 0.23

## Textures de 32x32 en pixel art
static func textura(eina: String) -> ImageTexture:
	if _textures.has(eina):
		return _textures[eina]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var fusta := Color(0.75, 0.55, 0.3)
	var metall := Color(0.9, 0.92, 0.95)
	for y in range(6, 31):
		for x in range(15, 17):
			img.set_pixel(x, y, fusta)
	match eina:
		"destral":
			# Fulla ampla a un costat, que s'eixampla cap al tall
			for y in range(3, 13):
				var ample := 4 + int((y - 3) * 0.5) if y < 8 else 6 - int((y - 8) * 0.5)
				for x in range(17, 17 + ample):
					img.set_pixel(x, y, metall)
			for y in range(4, 11):
				img.set_pixel(13, y, metall)
				img.set_pixel(14, y, metall)
		"pic":
			# Cap corbat cap als dos costats, acabat en punta
			for x in range(5, 27):
				var dy := int(abs(x - 15.5) * 0.35)
				for y in range(4 + dy, 7 + dy):
					img.set_pixel(x, y, metall)
	_textures[eina] = ImageTexture.create_from_image(img)
	return _textures[eina]

static func _material(eina: String) -> StandardMaterial3D:
	if not _materials.has(eina):
		var m := StandardMaterial3D.new()
		m.albedo_texture = textura(eina)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = true
		m.vertex_color_use_as_albedo = true
		_materials[eina] = m
	return _materials[eina]
