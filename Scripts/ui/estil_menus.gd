class_name EstilMenus
## Estil comú dels menús (pausa, opcions, menú principal): fons fosc, vores arrodonides,
## botons amb un toc càlid de vermut.

const COLOR_FONS := Color(0.07, 0.06, 0.09, 0.92)
const COLOR_ACCENT := Color(0.85, 0.35, 0.3)
const COLOR_TEXT := Color(0.96, 0.93, 0.88)

static func tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", COLOR_TEXT)
	for estat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var caixa := StyleBoxFlat.new()
		caixa.set_corner_radius_all(6)
		caixa.set_content_margin_all(8)
		caixa.content_margin_left = 16
		caixa.content_margin_right = 16
		match estat:
			"normal": caixa.bg_color = Color(0.18, 0.15, 0.2)
			"hover": caixa.bg_color = Color(0.3, 0.2, 0.24)
			"pressed": caixa.bg_color = COLOR_ACCENT.darkened(0.2)
			"focus":
				caixa.bg_color = Color(0.3, 0.2, 0.24)
				caixa.set_border_width_all(2)
				caixa.border_color = COLOR_ACCENT
			"disabled": caixa.bg_color = Color(0.12, 0.11, 0.13)
		t.set_stylebox(estat, "Button", caixa)
	t.set_color("font_color", "Button", COLOR_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	t.set_color("font_color", "CheckButton", COLOR_TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	var buida := StyleBoxEmpty.new()
	for estat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(estat, "CheckButton", buida)
	var pestanya := StyleBoxFlat.new()
	pestanya.bg_color = Color(0.18, 0.15, 0.2)
	pestanya.set_corner_radius_all(4)
	pestanya.set_content_margin_all(8)
	var pestanya_activa: StyleBoxFlat = pestanya.duplicate()
	pestanya_activa.bg_color = COLOR_ACCENT.darkened(0.15)
	t.set_stylebox("tab_unselected", "TabContainer", pestanya)
	t.set_stylebox("tab_hovered", "TabContainer", pestanya)
	t.set_stylebox("tab_selected", "TabContainer", pestanya_activa)
	var panell_pestanyes := StyleBoxFlat.new()
	panell_pestanyes.bg_color = Color(0, 0, 0, 0.2)
	panell_pestanyes.set_corner_radius_all(6)
	panell_pestanyes.set_content_margin_all(14)
	t.set_stylebox("panel", "TabContainer", panell_pestanyes)
	return t

static func caixa_fons() -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = COLOR_FONS
	c.set_corner_radius_all(10)
	c.set_border_width_all(2)
	c.border_color = Color(COLOR_ACCENT, 0.6)
	c.set_content_margin_all(22)
	return c
