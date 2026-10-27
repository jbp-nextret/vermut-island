extends CanvasLayer
class_name HudDiners
## Comptador de diners. Afegeix-lo a qualsevol escena amb add_child(HudDiners.new()).

var marge_superior := 12.0

var label: Label
var mostrat := 0
var tween_compte: Tween

func _ready():
	label = Label.new()
	label.position = Vector2(12, marge_superior)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)

	mostrat = Inventari.diners
	_pintar()
	Inventari.diners_canviats.connect(_on_diners_canviats)

func _on_diners_canviats(nous: int):
	# El número "compta" fins al valor nou i fa un petit bot
	if tween_compte:
		tween_compte.kill()
	tween_compte = create_tween()
	tween_compte.tween_method(func(v: float): mostrat = int(v); _pintar(), float(mostrat), float(nous), 0.5)

	label.pivot_offset = label.size / 2.0
	var bot := create_tween()
	bot.tween_property(label, "scale", Vector2.ONE * 1.25, 0.08)
	bot.tween_property(label, "scale", Vector2.ONE, 0.15)

func _pintar():
	label.text = "🪙 %d" % mostrat
