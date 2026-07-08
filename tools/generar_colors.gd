@tool
extends EditorScript

const PLAYER_PATH := "res://sprites/player"

const COLORS := {
	"hair": {
		"brown": Color("57350f"),
		"black": Color("1a1a1a"),
		"blonde": Color("d8b347")
	},
	"eyes": {
		"blue": Color("00b4bbff"),
		"green": Color("00b53aff"),
		"ambar": Color("cf9514ff")
	},
	"skin": {
		"light": Color("f2c9a1"),
		"tan": Color("b78963"),
		"dark": Color("725645")
	},
	"tshirt": {
		"green": Color("61a86a"),
		"blue": Color("6a89ff"),
		"red": Color("ff5959")
	},

	"jeans": {
		"blue": Color("255b5a"),
		"brown": Color("7d4621"),
		"green": Color("61a86a")
	},

	"shoes": {
		"black": Color("202020"),
		"brown": Color("5b3714"),
		"tan": Color("b68253")
	}
}

func _run():

	var root := DirAccess.open(PLAYER_PATH)

	if root == null:
		push_error("No existeix " + PLAYER_PATH)
		return

	root.list_dir_begin()

	while true:

		var anim = root.get_next()

		if anim == "":
			break

		if !root.current_is_dir():
			continue

		_process_animation(anim)

	root.list_dir_end()

	print("✔ Variants generades!")

func _process_animation(anim_name:String):
	

	var anim_path = PLAYER_PATH + "/" + anim_name

	var dir := DirAccess.open(anim_path)

	if dir == null:
		return

	dir.list_dir_begin()

	while true:

		var file = dir.get_next()

		if file == "":
			break

		if dir.current_is_dir():
			continue

		if !file.to_lower().ends_with(".png"):
			print("Animació: ", anim_name, "  Fitxer: ", file)
			continue
			

		var part = file.get_basename().strip_edges().to_lower()

		if !COLORS.has(part):
			print("Part =", part, " existeix? ", COLORS.has(part))
			continue

		_generate_variants(anim_path, file, part)

	dir.list_dir_end()

func _generate_variants(anim_path:String, file:String, part:String):
	print("Generant ", part, " de ", anim_path)
	var image := Image.load_from_file(anim_path + "/" + file)

	if image == null:
		return

	for variant in COLORS[part].keys():

		var output := image.duplicate()

		var tint : Color = COLORS[part][variant]

		for y in output.get_height():

			for x in output.get_width():

				var p = output.get_pixel(x,y)

				# Conservem transparència
				if p.a == 0:
					continue

				var g = p.r

				p.r = g * tint.r
				p.g = g * tint.g
				p.b = g * tint.b

				output.set_pixel(x,y,p)

		var folder = anim_path + "/variants/" + variant
		var  dir = DirAccess.open(anim_path)
		dir.make_dir_recursive("variants/"+variant)

		output.save_png(folder + "/" + file)
		var error = output.save_png(folder + "/" + file)
		print("Desant a: ", folder + "/" + file, " -> ", error)
