extends Node3D

@export var cultiu_escena: PackedScene
@onready var zona_hort = $ZonaHort

var mode_plantacio = false

func _input(event):
	if Input.is_action_just_pressed("plantar"):
		if Inventari.tenir("llavor_raim") > 0:
			mode_plantacio = true
			print("Mode plantació activat — clica al terra")
		else:
			print("No tens llavors!")
	
	if mode_plantacio and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			plantar_a_cursor()

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
		
		print("Cultiu escena: ", cultiu_escena)
		
		var cultiu = cultiu_escena.instantiate()
		add_child(cultiu)
		cultiu.global_position = posicio
		
		Inventari.items["llavor_raim"] -= 1
		mode_plantacio = false
		print("Plantat! Llavors restants: ", Inventari.tenir("llavor_raim"))

func dins_zona_hort(posicio: Vector3) -> bool:
	return zona_hort.conte_punt(posicio)

func cultiu_a_prop(posicio: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("cultius"):
		if node.global_position.distance_to(posicio) < 1.0:
			return true
	return false
