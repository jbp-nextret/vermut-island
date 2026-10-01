extends Camera3D
## Càmera del jugador:
##  - zoom amb la rodeta
##  - gir al voltant del jugador: Z / C a passos de 45°, o arrossegant amb el botó central
##    (en deixar-lo, s'ajusta al pas més proper). R torna a la vista inicial.
##    El gir està limitat a GIR_MAXIM per banda: més enllà, els sprites de vegetació
##    (que no giren amb la càmera) es veurien de costat o per darrere.
##  - segueix el jugador amb una mica de suavitat
##  - postprocessat (vores blanques i color): F10 l'activa o el desactiva

const ZOOM_SPEED = 0.5
const MIN_ZOOM = 7.0
const MAX_ZOOM = 14.0
const PAS_GIR := 45.0
const GIR_MAXIM := 45.0   # graus a cada costat de la vista inicial
const SENSIBILITAT_GIR := 0.008
const SUAVITAT_SEGUIMENT := 10.0
const SUAVITAT_GIR := 12.0
const SHADER_POSTPROCESSAT := preload("res://Shaders/postprocessat.gdshader")

var target_zoom = 10.0
var target_size = 9.5   # més lluny que abans (7): es veu més tros de món

var pivot: Node3D
var jugador: Node3D
var offset_pivot := Vector3.ZERO
var gir_inicial := 0.0
var gir_objectiu := 0.0
var girant_amb_ratoli := false
var postprocessat: MeshInstance3D
## On seria el pivot si no l'ajustéssim als píxels (el seguiment suau es fa sobre aquest)
var posicio_suau := Vector3.ZERO

func _ready():
	position.z = target_zoom
	pivot = get_parent() as Node3D
	jugador = pivot.get_parent() as Node3D if pivot else null
	if pivot and jugador is CharacterBody3D:
		offset_pivot = pivot.position
		gir_inicial = pivot.rotation.y
		gir_objectiu = gir_inicial
		# El pivot deixa d'anar enganxat al jugador i el segueix amb suavitat
		pivot.top_level = true
		posicio_suau = jugador.global_position + offset_pivot
		pivot.global_position = posicio_suau
	_crear_postprocessat()

func _physics_process(delta: float) -> void:
	size = lerp(size, target_size, delta * 8.0)
	if pivot and jugador is CharacterBody3D:
		var desti := jugador.global_position + offset_pivot
		posicio_suau = posicio_suau.lerp(desti, 1.0 - exp(-SUAVITAT_SEGUIMENT * delta))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, gir_objectiu, 1.0 - exp(-SUAVITAT_GIR * delta))
		pivot.global_position = ajustar_a_pixels(posicio_suau)

## Mida d'un píxel de la pantalla del joc, en unitats del món
func mida_pixel() -> float:
	return size / maxf(1.0, get_viewport().get_visible_rect().size.y)

## Mou el punt (en el pla de la càmera) al píxel sencer més proper. Si la càmera queda
## entre píxels, la imatge de baixa resolució "llisca" i fa pampallugues en moure's.
func ajustar_a_pixels(punt: Vector3) -> Vector3:
	var px := mida_pixel()
	var base := global_basis.orthonormalized()
	var local := base.inverse() * punt
	local.x = round(local.x / px) * px
	local.y = round(local.y / px) * px
	return base * local

## Quan el jugador apareix en un altre lloc (porta, càrrega...), la càmera hi salta de cop
func centrar_de_cop():
	if pivot and jugador:
		posicio_suau = jugador.global_position + offset_pivot
		pivot.rotation.y = gir_objectiu
		pivot.global_position = ajustar_a_pixels(posicio_suau)

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
		gir_objectiu = _limitar(gir_objectiu - event.relative.x * SENSIBILITAT_GIR)

func _unhandled_input(event):
	if not current:
		return
	if event.is_action_pressed("girar_camera_esquerra"):
		gir_objectiu = _limitar(_ajustar_al_pas(gir_objectiu) - deg_to_rad(PAS_GIR))
	elif event.is_action_pressed("girar_camera_dreta"):
		gir_objectiu = _limitar(_ajustar_al_pas(gir_objectiu) + deg_to_rad(PAS_GIR))
	elif event.is_action_pressed("reset_camera"):
		gir_objectiu = gir_inicial
	elif event.is_action_pressed("alternar_postprocessat") and postprocessat:
		# Es desa a GameState: en canviar d'escena (o de partida) es manté com el vas deixar
		GameState.postprocessat_actiu = not GameState.postprocessat_actiu
		postprocessat.visible = GameState.postprocessat_actiu

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
