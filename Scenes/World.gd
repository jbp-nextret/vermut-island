extends Node3D

@export var cultiu_escena: PackedScene
@onready var zona_hort = $ZonaHort
@onready var cursor = $CursorPlantacio
@onready var particules_plantar = $ParticulesPlantar
@onready var particules_collir = $ParticulesCollir

var mode_plantacio = false

func _ready():
	cursor.visible = false
	
	# Crea el material del cursor per codi
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
	cursor.set_surface_override_material(0, material)

func _input(event):
	if Input.is_action_just_pressed("plantar"):
		if Inventari.tenir("llavor_raim") > 0:
			mode_plantacio = true
			cursor.visible = true
			print("Mode plantació activat — clica al terra")
		else:
			print("No tens llavors!")
	
	# Cancel·la el mode plantació amb Escape
	if Input.is_action_just_pressed("ui_cancel"):
		mode_plantacio = false
		cursor.visible = false
	
	if mode_plantacio and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			plantar_a_cursor()

func _process(delta):
	if not mode_plantacio:
		return
	
	# Mou el cursor a la posició del ratolí
	var espai = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var pos_ratolí = get_viewport().get_mouse_position()
	
	var origen = camera.project_ray_origin(pos_ratolí)
	var direccio = camera.project_ray_normal(pos_ratolí)
	
	var query = PhysicsRayQueryParameters3D.create(
		origen,
		origen + direccio * 100.0
	)
	
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		var posicio = resultat.position
		posicio.y = 0.05  # lleugerament per sobre del terra
		cursor.global_position = posicio
		
		# Canvia de color segons si es pot plantar o no
		var material = cursor.get_surface_override_material(0)
		if material == null:
			return
		if not dins_zona_hort(posicio) or cultiu_a_prop(posicio):
			material.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
		else:
			material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)

func plantar_a_cursor():
	var espai = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var pos_ratolí = get_viewport().get_mouse_position()
	
	var origen = camera.project_ray_origin(pos_ratolí)
	var direccio = camera.project_ray_normal(pos_ratolí)
	
	var query = PhysicsRayQueryParameters3D.create(
		origen,
		origen + direccio * 100.0
	)
	
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		var posicio = resultat.position
		posicio.y = 0.0
		
		if not dins_zona_hort(posicio):
			print("No pots plantar aquí!")
			return
		
		if cultiu_a_prop(posicio):
			print("Ja hi ha un cultiu aquí!")
			return
		
		var cultiu = cultiu_escena.instantiate()
		add_child(cultiu)
		cultiu.global_position = posicio
		
		llançar_particules(particules_plantar, posicio)
		
		Inventari.items["llavor_raim"] -= 1
		mode_plantacio = false
		cursor.visible = false
		print("Plantat! Llavors restants: ", Inventari.tenir("llavor_raim"))

func dins_zona_hort(posicio: Vector3) -> bool:
	return zona_hort.conte_punt(posicio)

func cultiu_a_prop(posicio: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("cultius"):
		if node.global_position.distance_to(posicio) < 1.0:
			return true
	return false
	
func llançar_particules(particules: GPUParticles3D, posicio: Vector3):
	particules.global_position = posicio
	particules.restart()
	particules.emitting = true
