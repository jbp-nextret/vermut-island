extends Node
## Il·luminació segons l'hora i el temps:
##  - el sol surt per l'est i es pon per l'oest, amb colors càlids a l'alba i al capvespre
##  - de nit, llum de lluna blavosa (no negre total) i una llum càlida suau al voltant del jugador
##  - el cel, la llum ambient i la boira canvien de color amb l'hora
##  - els núvols i la pluja ho enfosqueixen i ho tornen més gris; els llamps ho il·luminen de cop

const COLORS = {
	"nit":       {"llum": Color(0.45, 0.55, 0.95), "cel": Color(0.03, 0.04, 0.12), "horitzo": Color(0.1, 0.12, 0.25), "ambient": Color(0.35, 0.42, 0.7)},
	"alba":      {"llum": Color(1.0, 0.62, 0.38), "cel": Color(0.45, 0.45, 0.75), "horitzo": Color(1.0, 0.65, 0.45), "ambient": Color(0.9, 0.7, 0.65)},
	"mati":      {"llum": Color(1.0, 0.92, 0.78), "cel": Color(0.38, 0.65, 1.0), "horitzo": Color(0.95, 0.88, 0.75), "ambient": Color(0.95, 0.93, 0.88)},
	"migdia":    {"llum": Color(1.0, 0.98, 0.92), "cel": Color(0.3, 0.6, 1.0), "horitzo": Color(0.8, 0.9, 1.0), "ambient": Color(1.0, 0.98, 0.95)},
	"tarda":     {"llum": Color(1.0, 0.8, 0.55), "cel": Color(0.45, 0.55, 0.9), "horitzo": Color(1.0, 0.75, 0.5), "ambient": Color(1.0, 0.9, 0.8)},
	"capvespre": {"llum": Color(1.0, 0.45, 0.25), "cel": Color(0.3, 0.2, 0.45), "horitzo": Color(1.0, 0.45, 0.3), "ambient": Color(0.8, 0.55, 0.6)},
}
const COLOR_TEMPORAL := Color(0.55, 0.58, 0.63)   # el gris dels dies de pluja

var llum_principal: DirectionalLight3D
var llum_rebliment: DirectionalLight3D
var entorn: WorldEnvironment
var meteo: Node
var llum_jugador: OmniLight3D
var jugador: Node3D

func _ready():
	llum_principal = get_node_or_null("../GridMap/DirectionalLight3D")
	llum_rebliment = get_node_or_null("../GridMap/DirectionalLight3D/DirectionalLight3D")
	entorn = get_node_or_null("../WorldEnvironment")
	meteo = get_node_or_null("../WeatherManager")
	if llum_principal:
		llum_principal.shadow_enabled = true
		# La càmera és a 45 unitats: les ombres han d'arribar més enllà
		llum_principal.directional_shadow_max_distance = 110.0
	# Llum càlida al voltant del jugador, que només s'encén de nit
	jugador = get_tree().get_first_node_in_group("player")
	if jugador:
		llum_jugador = OmniLight3D.new()
		llum_jugador.light_color = Color(1.0, 0.8, 0.55)
		llum_jugador.omni_range = 6.0
		llum_jugador.light_energy = 0.0
		llum_jugador.shadow_enabled = false
		llum_jugador.top_level = true
		jugador.add_child(llum_jugador)

func _process(_delta):
	if not llum_principal or not entorn:
		return
	var hora: float = GestorTemps.hora_actual
	var c := _colors(hora)
	var nuvols: float = Meteorologia.nuvols
	var flaix: float = meteo.flaix if meteo else 0.0

	# Sol (o lluna): color, força i angle
	var dia := _llum_de_dia(hora)
	var color_llum: Color = c.llum.lerp(COLOR_TEMPORAL, nuvols * 0.6)
	llum_principal.light_color = color_llum.lerp(Color(0.85, 0.9, 1.0), flaix)
	llum_principal.light_energy = lerpf(0.25, 1.35, dia) * (1.0 - nuvols * 0.55) + flaix * 2.5
	llum_principal.shadow_opacity = clampf(dia * (1.0 - nuvols), 0.0, 1.0) * 0.8
	if llum_rebliment:
		llum_rebliment.light_energy = llum_principal.light_energy * 0.2
	# De dia el sol fa un arc d'est a oest; de nit, la lluna, més alta i quieta
	if dia > 0.0:
		var t := clampf((hora - 6.0) / 14.0, 0.0, 1.0)
		llum_principal.rotation_degrees = Vector3(-lerpf(12.0, 12.0, t) - sin(t * PI) * 50.0, lerpf(-70.0, 70.0, t), 0.0)
	else:
		llum_principal.rotation_degrees = Vector3(-55.0, 30.0, 0.0)

	# Cel, llum ambient i boira
	var env := entorn.environment
	var cel := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	if cel:
		cel.sky_top_color = c.cel.lerp(COLOR_TEMPORAL * 0.8, nuvols * 0.7).lerp(Color.WHITE, flaix * 0.6)
		cel.sky_horizon_color = c.horitzo.lerp(COLOR_TEMPORAL, nuvols * 0.7)
	env.ambient_light_color = c.ambient.lerp(COLOR_TEMPORAL, nuvols * 0.5)
	env.ambient_light_energy = lerpf(0.35, 0.5, dia) + flaix * 0.6
	env.fog_light_color = c.horitzo.lerp(COLOR_TEMPORAL, 0.6)

	if llum_jugador:
		var foscor := 1.0 - dia
		llum_jugador.light_energy = lerpf(llum_jugador.light_energy, foscor * 1.6 + nuvols * 0.3, 0.05)
		# Una mica per davant del personatge (cap a la càmera): si fos al mateix pla que
		# el sprite, la llum hi arribaria de fil i gairebé no l'il·luminaria
		var camera := get_viewport().get_camera_3d()
		var davant: Vector3 = camera.global_basis.z if camera else Vector3.BACK
		llum_jugador.global_position = jugador.global_position + Vector3.UP * 1.0 + davant * 1.5

## 0 de nit, 1 de dia, amb l'alba i el capvespre graduals
func _llum_de_dia(hora: float) -> float:
	if hora < 5.5 or hora > 20.5:
		return 0.0
	if hora < 7.5:
		return (hora - 5.5) / 2.0
	if hora > 18.5:
		return (20.5 - hora) / 2.0
	return 1.0

func _colors(hora: float) -> Dictionary:
	var trams := [[0.0, "nit"], [5.0, "nit"], [6.5, "alba"], [9.0, "mati"], [13.0, "migdia"], [17.0, "tarda"], [19.5, "capvespre"], [21.0, "nit"], [24.0, "nit"]]
	for i in trams.size() - 1:
		var a: Array = trams[i]
		var b: Array = trams[i + 1]
		if hora >= a[0] and hora <= b[0]:
			var t: float = (hora - a[0]) / maxf(0.001, b[0] - a[0])
			var ca: Dictionary = COLORS[a[1]]
			var cb: Dictionary = COLORS[b[1]]
			var r := {}
			for clau in ca:
				r[clau] = ca[clau].lerp(cb[clau], t)
			return r
	return COLORS["nit"]
