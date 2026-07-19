extends Control

const ESCENA_PREVIEW := preload("res://Scenes/PreviewPersonatge.tscn")
const ESCENA_JOC := "res://Scenes/World.tscn"

const MIDA_SWATCH := Vector2(36, 36)

@export var subviewport: SubViewport
@export var nom_input: LineEdit
@export var swatches_hair: HBoxContainer
@export var swatches_skin: HBoxContainer
@export var swatches_eyes: HBoxContainer
@export var swatches_tshirt: HBoxContainer
@export var swatches_jeans: HBoxContainer
@export var swatches_boots: HBoxContainer
@export var boto_confirmar: Button
@export var nom_preview: Label

var preview: Node3D
var contenidors: Dictionary
var grups: Dictionary = {}

func _ready() -> void:
	preview = ESCENA_PREVIEW.instantiate()
	subviewport.add_child(preview)

	contenidors = {
		"hair": swatches_hair,
		"skin": swatches_skin,
		"eyes": swatches_eyes,
		"tshirt": swatches_tshirt,
		"jeans": swatches_jeans,
		"boots": swatches_boots,
	}

	for nom_part in contenidors.keys():
		_generar_swatches(nom_part)

	boto_confirmar.pressed.connect(_on_confirmar_pressed)
	nom_input.text_changed.connect(_on_nom_changed)
	_on_nom_changed(nom_input.text)

func _generar_swatches(nom_part: String) -> void:
	var container: HBoxContainer = contenidors[nom_part]
	var grup := ButtonGroup.new()
	grups[nom_part] = grup

	var variant_actual: String = Customization.variants_actuals.get(nom_part, Customization.VARIANTS[nom_part][0])

	for variant in Customization.VARIANTS[nom_part]:
		var boto := Button.new()
		boto.custom_minimum_size = MIDA_SWATCH
		boto.toggle_mode = true
		boto.button_group = grup
		boto.tooltip_text = variant

		var color: Color = Customization.COLORS_UI[nom_part].get(variant, Color.WHITE)
		var estil_normal := StyleBoxFlat.new()
		estil_normal.bg_color = color
		estil_normal.corner_radius_top_left = 6
		estil_normal.corner_radius_top_right = 6
		estil_normal.corner_radius_bottom_left = 6
		estil_normal.corner_radius_bottom_right = 6
		estil_normal.border_width_left = 2
		estil_normal.border_width_right = 2
		estil_normal.border_width_top = 2
		estil_normal.border_width_bottom = 2
		estil_normal.border_color = Color(0, 0, 0, 0.3)

		var estil_seleccionat := estil_normal.duplicate()
		estil_seleccionat.border_color = Color.WHITE
		estil_seleccionat.border_width_left = 3
		estil_seleccionat.border_width_right = 3
		estil_seleccionat.border_width_top = 3
		estil_seleccionat.border_width_bottom = 3

		boto.add_theme_stylebox_override("normal", estil_normal)
		boto.add_theme_stylebox_override("hover", estil_normal)
		boto.add_theme_stylebox_override("pressed", estil_seleccionat)

		if variant == variant_actual:
			boto.button_pressed = true

		boto.pressed.connect(_on_swatch_pressed.bind(nom_part, variant))
		container.add_child(boto)

func _on_swatch_pressed(nom_part: String, variant: String) -> void:
	preview.canviar_color(nom_part, variant)

func _on_nom_changed(nou_text: String) -> void:
	nom_preview.text = "Jugador" if nou_text.strip_edges().is_empty() else nou_text

func _on_confirmar_pressed() -> void:
	var nom := nom_input.text.strip_edges()
	if nom.is_empty():
		nom = "Keru"
	Customization.nom = nom
	get_tree().change_scene_to_file(ESCENA_JOC)
