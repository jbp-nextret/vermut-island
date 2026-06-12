extends Node

# Durada d'un dia complet en segons reals
@export var durada_dia: float = 120.0

var hora_actual: float = 8.0  # comença a les 8 del matí (0-24)

@onready var llum_principal = get_node("../CSGBox3D/DirectionalLight3D")
@onready var llum_rebliment = get_node("../CSGBox3D/DirectionalLight3D/DirectionalLight3D")
@onready var entorn = get_node("../WorldEnvironment")
@onready var rellotge = get_node("../CanvasLayer/Rellotge")

# Dies de la setmana
const DIES = ["Dilluns", "Dimarts", "Dimecres", "Dijous", "Divendres", "Dissabte", "Diumenge"]
# Colors per a cada moment del dia
const COLORS = {
	"alba":     { "llum": Color(1.0, 0.6, 0.3), "cel": Color(1.0, 0.5, 0.2), "horitzó": Color(1.0, 0.7, 0.4) },
	"matí":     { "llum": Color(1.0, 0.9, 0.7), "cel": Color(0.4, 0.7, 1.0), "horitzó": Color(1.0, 0.85, 0.6) },
	"migdia":   { "llum": Color(1.0, 0.95, 0.85), "cel": Color(0.3, 0.6, 1.0), "horitzó": Color(0.8, 0.9, 1.0) },
	"tarda":    { "llum": Color(1.0, 0.7, 0.3), "cel": Color(0.8, 0.4, 0.2), "horitzó": Color(1.0, 0.5, 0.2) },
	"capvespre":{ "llum": Color(0.8, 0.3, 0.1), "cel": Color(0.2, 0.1, 0.3), "horitzó": Color(0.8, 0.3, 0.1) },
	"nit":      { "llum": Color(0.1, 0.1, 0.3), "cel": Color(0.02, 0.02, 0.08), "horitzó": Color(0.05, 0.05, 0.15) }
}
func _ready():
	#rellotge.add_theme_font_size_override("font_size", 32)
	#rellotge.add_theme_color_override("font_color", Color(1, 0.85, 0, 1))
	#rellotge.position = Vector2(20, 20)
	rellotge.text = "00:00"
	print("Rellotge node: ", rellotge)
	
func _process(delta):
	hora_actual += (24.0 / durada_dia) * delta
	if hora_actual >= 24.0:
		hora_actual -= 24.0
		GestorTemps.passar_dia()
	
	actualitzar_llum()
	actualitzar_cel()
	actualitzar_angle_llum()
	actualitzar_rellotge()
	
func actualitzar_rellotge():
	var hores = int(hora_actual)
	var minuts = int((hora_actual - hores) * 60)
	var periode = "AM" if hores < 12 else "PM"
	var hores_12 = hores % 12
	if hores_12 == 0:
		hores_12 = 12
	
	var icona = ""
	if hora_actual < 6.0:
		icona = "🌙"
	elif hora_actual < 9.0:
		icona = "🌅"
	elif hora_actual < 18.0:
		icona = "☀️"
	elif hora_actual < 20.0:
		icona = "🌇"
	else:
		icona = "🌙"
	var dia_setmana = DIES[(GestorTemps.dia_actual - 1) % 7]
	rellotge.text = "%s %02d:%02d\n%s" % [icona, hores, minuts, dia_setmana]
	print("Hora actual: ", hora_actual)

func _get_colors_per_hora() -> Array:
	# Retorna [color_actual, color_seguent, t] per interpolar
	if hora_actual < 6.0:      # nit → alba
		return [COLORS["nit"], COLORS["alba"], hora_actual / 6.0]
	elif hora_actual < 9.0:    # alba → matí
		return [COLORS["alba"], COLORS["matí"], (hora_actual - 6.0) / 3.0]
	elif hora_actual < 13.0:   # matí → migdia
		return [COLORS["matí"], COLORS["migdia"], (hora_actual - 9.0) / 4.0]
	elif hora_actual < 17.0:   # migdia → tarda
		return [COLORS["migdia"], COLORS["tarda"], (hora_actual - 13.0) / 4.0]
	elif hora_actual < 20.0:   # tarda → capvespre
		return [COLORS["tarda"], COLORS["capvespre"], (hora_actual - 17.0) / 3.0]
	else:                       # capvespre → nit
		return [COLORS["capvespre"], COLORS["nit"], (hora_actual - 20.0) / 4.0]

func actualitzar_llum():
	var cols = _get_colors_per_hora()
	var color_actual = cols[0]["llum"]
	var color_seguent = cols[1]["llum"]
	var t = cols[2]
	
	llum_principal.light_color = color_actual.lerp(color_seguent, t)
	
	# Intensitat: màxima al migdia, mínima a la nit
	var intensitat = _intensitat_per_hora()
	llum_principal.light_energy = intensitat
	llum_rebliment.light_energy = intensitat * 0.2

func actualitzar_cel():
	var cols = _get_colors_per_hora()
	var t = cols[2]
	
	var sky_mat = entorn.environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	
	sky_mat.sky_top_color = cols[0]["cel"].lerp(cols[1]["cel"], t)
	sky_mat.sky_horizon_color = cols[0]["horitzó"].lerp(cols[1]["horitzó"], t)

func actualitzar_angle_llum():
	# El sol gira 360° en 24 hores
	var angle = (hora_actual / 24.0) * 360.0 - 90.0
	llum_principal.rotation_degrees.x = -angle

func _intensitat_per_hora() -> float:
	# Corba suau: 0 a la nit, 1.4 al migdia
	if hora_actual < 6.0 or hora_actual > 20.0:
		return 0.05
	var t = (hora_actual - 6.0) / 14.0  # 0 a 1 entre les 6 i les 20
	return sin(t * PI) * 1.4
