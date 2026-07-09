extends Control

const ESCENA_PREVIEW := preload("res://Scenes/PreviewPersonatge.tscn")
const ESCENA_JOC := "res://Scenes/World.tscn"

@export var subviewport: SubViewport
@export var nom_input: LineEdit
@export var picker_hair: OptionButton
@export var picker_skin: OptionButton
@export var picker_eyes: OptionButton
@export var picker_tshirt: OptionButton
@export var picker_jeans: OptionButton
@export var picker_boots: OptionButton
@export var boto_confirmar: Button
@export var nom_preview: Label

var preview: Node3D
var pickers: Dictionary

func _ready() -> void:
	preview = ESCENA_PREVIEW.instantiate()
	subviewport.add_child(preview)

	pickers = {
		"hair": picker_hair,
		"skin": picker_skin,
		"eyes": picker_eyes,
		"tshirt": picker_tshirt,
		"jeans": picker_jeans,
		"boots": picker_boots,
	}

	for nom_part in pickers.keys():
		var picker: OptionButton = pickers[nom_part]
		picker.clear()
		var opcions: Array = Customization.VARIANTS[nom_part]
		for opcio in opcions:
			picker.add_item(opcio)

		var variant_actual: String = Customization.variants_actuals.get(nom_part, opcions[0])
		var index_actual := opcions.find(variant_actual)
		picker.select(max(index_actual, 0))

		picker.item_selected.connect(_on_variant_selected.bind(nom_part, picker))

	boto_confirmar.pressed.connect(_on_confirmar_pressed)

	nom_input.text_changed.connect(_on_nom_changed)
	_on_nom_changed(nom_input.text)

func _on_variant_selected(index: int, nom_part: String, picker: OptionButton) -> void:
	var variant := picker.get_item_text(index)
	preview.canviar_color(nom_part, variant)

func _on_nom_changed(nou_text: String) -> void:
	nom_preview.text = "Jugador" if nou_text.strip_edges().is_empty() else nou_text

func _on_confirmar_pressed() -> void:
	var nom := nom_input.text.strip_edges()
	if nom.is_empty():
		nom = "Keru"
	Customization.nom = nom
	get_tree().change_scene_to_file(ESCENA_JOC)
