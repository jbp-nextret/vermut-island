extends Camera3D
## Càmera del jugador:
##  - zoom amb la rodeta
##  - gir al voltant del jugador: Z / C a passos de 45°, o arrossegant amb el botó central
##    (en deixar-lo, s'ajusta al pas més proper). R torna a la vista inicial.
##  - segueix el jugador amb una mica de suavitat
##  - postprocessat (vores blanques i color): F10 l'activa o el desactiva

const ZOOM_SPEED = 0.5
const MIN_ZOOM = 6.0
const MAX_ZOOM = 11.0
const PAS_GIR := 45.0
const SENSIBILITAT_GIR := 0.008
const SUAVITAT_SEGUIMENT := 10.0
const SUAVITAT_GIR := 12.0
const SHADER_POSTPROCESSAT := preload("res://Shaders/postprocessat.gdshader")

var target_zoom = 10.0
var target_size = 7.0

var pivot: Node3D
var jugador: Node3D
var offset_pivot := Vector3.ZERO
var gir_inicial := 0.0
var gir_objectiu := 0.0
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
		# El pivot deixa d'anar enganxat al jugador i el segueix amb suavitat
		pivot.top_level = true
		pivot.global_position = jugador.global_position + offset_pivot
	_crear_postprocessat()

func _physics_process(delta: float) -> void:
	size = lerp(size, target_size, delta * 8.0)
	if pivot and jugador is CharacterBody3D:
		var desti := jugador.global_position + offset_pivot
		pivot.global_position = pivot.global_position.lerp(desti, 1.0 - exp(-SUAVITAT_SEGUIMENT * delta))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, gir_objectiu, 1.0 - exp(-SUAVITAT_GIR * delta))

## Quan el jugador apareix en un altre lloc (porta, càrrega...), la càmera hi salta de cop
func centrar_de_cop():
	if pivot and jugador:
		pivot.global_position = jugador.global_position + offset_pivot
		pivot.rotation.y = gir_objectiu

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
		gir_objectiu -= event.relative.x * SENSIBILITAT_GIR

func _unhandled_input(event):
	if not current:
		return
	if event.is_action_pressed("girar_camera_esquerra"):
		gir_objectiu = _ajustar_al_pas(gir_objectiu) - deg_to_rad(PAS_GIR)
	elif event.is_action_pressed("girar_camera_dreta"):
		gir_objectiu = _ajustar_al_pas(gir_objectiu) + deg_to_rad(PAS_GIR)
	elif event.is_action_pressed("reset_camera"):
		gir_objectiu = gir_inicial
	elif event.is_action_pressed("alternar_postprocessat") and postprocessat:
		postprocessat.visible = not postprocessat.visible

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
	add_child(postprocessat)
