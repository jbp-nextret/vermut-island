@tool
extends EditorScript

const COLORS = {
	"brown": Color("57350f"),
	"black": Color("1a1a1a"),
	"blonde": Color("d8b347")
}

const INPUT_DIR = "res://assets/player/hair/base/"
const OUTPUT_DIR = "res://assets/player/hair/"

func _run():

	var dir = DirAccess.open(INPUT_DIR)

	if dir == null:
		push_error("No existeix la carpeta")
		return

	dir.list_dir_begin()

	while true:

		var file = dir.get_next()

		if file == "":
			break

		if dir.current_is_dir():
			continue

		if not file.ends_with(".png"):
			continue

		generar_fitxer(file)

	dir.list_dir_end()

	print("Fet!")
func generar_fitxer(file:String):

	var image = Image.load_from_file(INPUT_DIR + file)

	for color_name in COLORS:

		var copia = image.duplicate()

		var color = COLORS[color_name]

		for y in copia.get_height():
			for x in copia.get_width():

				var p = copia.get_pixel(x,y)

				var g = p.r

				p.r = g * color.r
				p.g = g * color.g
				p.b = g * color.b

				copia.set_pixel(x,y,p)

		var carpeta = OUTPUT_DIR + color_name

		DirAccess.make_dir_recursive_absolute(carpeta)

		copia.save_png(carpeta + "/" + file)
