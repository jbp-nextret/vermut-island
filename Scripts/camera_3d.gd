extends Camera3D
## Càmera del jugador:
##  - zoom amb la rodeta
##  - gir al voltant del jugador: Z / C a passos de 45°, o arrossegant amb el botó central
##    en horitzontal (en deixar-lo, s'ajusta al pas més proper). R torna a la vista inicial.
##  - inclinació (perspectiva): X / V, o arrossegant amb el botó central en vertical.
##    Més baixa = més de costat, útil per al plataformeig. Els nivells poden fixar una
##    vista concreta amb `establir_vista()`.
##    El gir està limitat a GIR_MAXIM per banda: més enllà, els sprites de vegetació
##    (que no giren amb la càmera) es veurien de costat o per darrere.
##  - segueix el jugador amb una mica de suavitat
##  - postprocessat (vores blanques i color): F10 l'activa o el desactiva

const ZOOM_SPEED = 0.5
const MIN_ZOOM = 7.0
const MAX_ZOOM = 14.0
const PAS_GIR := 45.0
const PAS_INCLINACIO := 10.0
const INCLINACIO_MINIMA := -75.0   # gairebé des de dalt
const INCLINACIO_MAXIMA := -12.0   # gairebé de costat
const GIR_MAXIM := 45.0   # graus a cada costat de la vista inicial
const SENSIBILITAT_GIR := 0.008
## Com de ràpid segueix el jugador, segons l'opció "Suavitat de la càmera":
## 0 % = enganxada (sense retard) · 25 % (per defecte) ≈ 30 · 100 % = 6 (molt suau)
const SEGUIMENT_MES_RAPID := 40.0
const SEGUIMENT_MES_SUAU := 6.0
const SEGUIMENT_VERTICAL := 8.0
const SUAVITAT_GIR := 12.0
const SHADER_POSTPROCESSAT := preload("res://Shaders/postprocessat.gdshader")

var target_zoom = 10.0
var target_size = 9.5   # més lluny que abans (7): es veu més tros de món

var pivot: Node3D
var jugador: Node3D
var offset_pivot := Vector3.ZERO
var gir_inicial := 0.0
var gir_objectiu := 0.0
var inclinacio_inicial := 0.0
var inclinacio_objectiu := 0.0
var girant_amb_ratoli := false
var postprocessat: MeshInstance3D

func _ready():
	position.z = target_zoom
	pivot = get_parent() as Node3D
	jugador = pivot.get_parent() as Node3D if pivot else null
	if pivot and jugador is CharacterBody3D:
		offset_pivot = pivot.position
		gir_inicial = pivot.rotation.y
		gir_objectiu = gir_inicial
		inclinacio_inicial = pivot.rotation.x
		inclinacio_objectiu = inclinacio_inicial
		# El pivot deixa d'anar enganxat al jugador i el segueix amb suavitat
		pivot.top_level = true
		pivot.global_position = jugador.global_position + offset_pivot
	_crear_postprocessat()

## A cada fotograma (no a cada tic de física): en monitors de més de 60 Hz, si la càmera
## només es mogués a 60 Hz faria batzegades
func _process(delta: float) -> void:
	size = lerp(size, target_size, delta * 8.0)
	if pivot and jugador is CharacterBody3D:
		var posicio_jugador: Vector3 = jugador.posicio_visual if "posicio_visual" in jugador else jugador.global_position
		var desti := posicio_jugador + offset_pivot
		var suavitat: float = SettingsManager.valor("suavitat_camera")
		var actual := pivot.global_position
		# En horitzontal, segons l'opció (0 % = enganxada)
		if suavitat <= 0.01:
			actual.x = desti.x
			actual.z = desti.z
		else:
			var rapidesa := lerpf(SEGUIMENT_MES_RAPID, SEGUIMENT_MES_SUAU, suavitat)
			var t := 1.0 - exp(-rapidesa * delta)
			actual.x = lerpf(actual.x, desti.x, t)
			actual.z = lerpf(actual.z, desti.z, t)
		# En vertical, sempre una mica esmorteïda: pujar o baixar un graó no la sacseja
		actual.y = lerpf(actual.y, desti.y, 1.0 - exp(-SEGUIMENT_VERTICAL * delta))
		pivot.global_position = actual
		pivot.rotation.y = lerp_angle(pivot.rotation.y, gir_objectiu, 1.0 - exp(-SUAVITAT_GIR * delta))
		pivot.rotation.x = lerp_angle(pivot.rotation.x, inclinacio_objectiu, 1.0 - exp(-SUAVITAT_GIR * delta))

## Quan el jugador apareix en un altre lloc (porta, càrrega...), la càmera hi salta de cop
func centrar_de_cop():
	if pivot and jugador:
		pivot.global_position = jugador.global_position + offset_pivot
		pivot.rotation.y = gir_objectiu
		pivot.rotation.x = inclinacio_objectiu

func _input(event):
	if not current:
		return   # construint a casa hi ha una altra càmera activa
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = clamp(target_size - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = clamp(target_size + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			girant_amb_ratoli = event.pressed
			if not event.pressed:
				gir_objectiu = _ajustar_al_pas(gir_objectiu)
	elif event is InputEventMouseMotion and girant_amb_ratoli:
		inclinacio_objectiu = _limitar_inclinacio(inclinacio_objectiu - event.relative.y * SENSIBILITAT_GIR)
		gir_objectiu = _limitar(gir_objectiu - event.relative.x * SENSIBILITAT_GIR)

func _unhandled_input(event):
	if not current:
		return
	if event.is_action_pressed("girar_camera_esquerra"):
		gir_objectiu = _limitar(_ajustar_al_pas(gir_objectiu) - deg_to_rad(PAS_GIR))
	elif event.is_action_pressed("girar_camera_dreta"):
		gir_objectiu = _limitar(_ajustar_al_pas(gir_objectiu) + deg_to_rad(PAS_GIR))
	elif event.is_action_pressed("inclinar_camera_avall"):
		inclinacio_objectiu = _limitar_inclinacio(inclinacio_objectiu + deg_to_rad(PAS_INCLINACIO))
	elif event.is_action_pressed("inclinar_camera_amunt"):
		inclinacio_objectiu = _limitar_inclinacio(inclinacio_objectiu - deg_to_rad(PAS_INCLINACIO))
	elif event.is_action_pressed("reset_camera"):
		gir_objectiu = gir_inicial
		inclinacio_objectiu = inclinacio_inicial
	elif event.is_action_pressed("alternar_postprocessat") and postprocessat:
		# Es desa a GameState: en canviar d'escena (o de partida) es manté com el vas deixar
		GameState.postprocessat_actiu = not GameState.postprocessat_actiu
		postprocessat.visible = GameState.postprocessat_actiu

## Per als nivells (p. ex. una zona de plataformes): fixa el gir i la inclinació, en graus,
## respecte a la vista inicial. `null` deixa el valor com està.
func establir_vista(gir_graus = null, inclinacio_graus = null) -> void:
	if gir_graus != null:
		gir_objectiu = _limitar(gir_inicial + deg_to_rad(gir_graus))
	if inclinacio_graus != null:
		inclinacio_objectiu = _limitar_inclinacio(deg_to_rad(inclinacio_graus))

func _limitar_inclinacio(angle: float) -> float:
	return clampf(angle, deg_to_rad(INCLINACIO_MINIMA), deg_to_rad(INCLINACIO_MAXIMA))

func _limitar(angle: float) -> float:
	return clampf(angle, gir_inicial - deg_to_rad(GIR_MAXIM), gir_inicial + deg_to_rad(GIR_MAXIM))

func _ajustar_al_pas(angle: float) -> float:
	var pas := deg_to_rad(PAS_GIR)
	return gir_inicial + round((angle - gir_inicial) / pas) * pas

func _crear_postprocessat():
	postprocessat = MeshInstance3D.new()
	postprocessat.name = "Postprocessat"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	postprocessat.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = SHADER_POSTPROCESSAT
	material.render_priority = -100   # abans que la resta de coses transparents
	postprocessat.material_override = material
	postprocessat.extra_cull_margin = 16384.0
	postprocessat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	postprocessat.visible = GameState.postprocessat_actiu
	add_child(postprocessat)
	_aplicar_vores()
	SettingsManager.opcio_canviada.connect(_on_opcio_canviada)

func _on_opcio_canviada(clau: String, _valor):
	if clau == "postprocessat":
		postprocessat.visible = GameState.postprocessat_actiu
	elif clau == "vores":
		_aplicar_vores()

func _aplicar_vores():
	var material := postprocessat.material_override as ShaderMaterial
	material.set_shader_parameter("intensitat_vora", 0.75 if SettingsManager.valor("vores") else 0.0)
