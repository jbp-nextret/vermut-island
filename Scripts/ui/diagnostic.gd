extends CanvasLayer
## Comptador de rendiment (F3): fotogrames per segon, temps de cada fotograma (el pitjor
## dels últims segons), tics de física i resolució. Serveix per saber si les estrebades
## vénen del rendiment (el joc no arriba als Hz del monitor) o d'una altra cosa.

var label: Label
var temps_fotogrames: Array[float] = []

func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	label = Label.new()
	label.position = Vector2(10, 60)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible

func _process(delta):
	temps_fotogrames.append(delta * 1000.0)
	if temps_fotogrames.size() > 240:
		temps_fotogrames.pop_front()
	if not visible:
		return
	var pitjor: float = temps_fotogrames.max()
	var hz := DisplayServer.screen_get_refresh_rate()
	var vsync: String = ["desactivat", "activat", "adaptatiu", "mailbox"][DisplayServer.window_get_vsync_mode()]
	label.text = "FPS: %d  (monitor: %d Hz)\nFotograma: %.1f ms · pitjor recent: %.1f ms\nFísica: %d tics/s\nVSync: %s\nResolució: %s" % [
		Engine.get_frames_per_second(), 0 if is_nan(hz) else roundi(hz), delta * 1000.0, pitjor,
		Engine.physics_ticks_per_second, vsync, str(get_window().size)]
	# En vermell si el joc no arriba als Hz del monitor
	var ok: bool = is_nan(hz) or Engine.get_frames_per_second() >= hz - 3.0
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7) if ok else Color(1.0, 0.55, 0.5))
