extends Control

const ESCENA_PREVIEW := preload("res://Scenes/PreviewPersonatge.tscn")
const ESCENA_JOC := "res://Scenes/World.tscn"

@export var subviewport: SubViewport
@export var nom_input: LineEdit
@export var picker_hair: ColorPickerButton
@export var picker_skin: ColorPickerButton
@export var picker_eyes: ColorPickerButton
@export var picker_tshirt: ColorPickerButton
@export var picker_jeans: ColorPickerButton
@export var picker_boots: ColorPickerButton
@export var boto_confirmar: Button
@export var nom_preview: Label

var preview: PersonatgePreview
var pickers: Dictionary

func _ready() -> void:
	preview = ESCENA_PREVIEW.instantiate()
	subviewport.add_child(preview)
	print("Preview afegit? ", preview != null, " Fills del viewport: ", subviewport.get_children())
	print("Posició preview: ", preview.global_position)

	pickers = {
		"hair": picker_hair,
		"skin": picker_skin,
		"eyes": picker_eyes,
		"tshirt": picker_tshirt,
		"jeans": picker_jeans,
		"boots": picker_boots,
	}

	for nom_part in pickers.keys():
		var picker: ColorPickerButton = pickers[nom_part]
		picker.color = Customization.colors_actuals.get(nom_part, Color.WHITE)
		picker.color_changed.connect(_on_color_changed.bind(nom_part))

	boto_confirmar.pressed.connect(_on_confirmar_pressed)
	
	# Label nom
	nom_input.text_changed.connect(_on_nom_changed)
	_on_nom_changed(nom_input.text)

func _on_nom_changed(nou_text: String) -> void:
	if nou_text.strip_edges().is_empty():
		nom_preview.text = "Jugador"
	else:
		nom_preview.text = nou_text
		
func _on_color_changed(color: Color, nom_part: String) -> void:
	preview.canviar_color(nom_part, color)

func _on_confirmar_pressed() -> void:
	var nom := nom_input.text.strip_edges()
	if nom.is_empty():
		nom = "Keru"
	Customization.nom = nom
	get_tree().change_scene_to_file(ESCENA_JOC)
