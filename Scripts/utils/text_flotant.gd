extends Label3D
class_name TextFlotant
## Text 3D que puja i s'esvaeix ("+12", "Grr!"...).

static func mostrar(pare: Node, posicio: Vector3, text_mostrar: String, color := Color.WHITE) -> void:
	var t := TextFlotant.new()
	t.text = text_mostrar
	t.modulate = color
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.no_depth_test = true
	t.font_size = 64
	t.outline_size = 16
	t.pixel_size = 0.004
	pare.add_child(t)
	t.global_position = posicio

	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "global_position:y", posicio.y + 0.6, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.chain().tween_callback(t.queue_free)
