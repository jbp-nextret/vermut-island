extends Node3D

@export var cultiu_escena: PackedScene
@onready var zona_hort = $ZonaHort
@onready var cursor = $CursorPlantacio
@onready var particules_plantar = $ParticulesPlantar
@onready var particules_collir = $ParticulesCollir

var mode_plantacio = false
var blocs_plantables = ["cube-top_001","cube-top_002","cube-top_003","cube-top_004","cube-top_005","cube-top_006","cube-top_007","cube-top_008","cube-top_009","cube_half-top_001", "cube_half-top_002", "cube_half-top_003", "cube_half-top_004","cube_half-top_005","cube_half-top_006","cube_half-top_007","cube_half-top_008","cube_half-top_009"]

func _ready():
	cursor.visible = false
	
	# Crea el material del cursor per codi
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
	cursor.set_surface_override_material(0, material)
	
	# Assigna mesh a les partícules
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	particules_plantar.draw_pass_1 = mesh
		
	# Partícules de collir
	var mesh2 = QuadMesh.new()
	mesh2.size = Vector2(0.1, 0.1)
	particules_collir.draw_pass_1 = mesh2

	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3(0, -9.8, 0)
	process_mat.scale_min = 0.3
	process_mat.scale_max = 0.6
	particules_collir.process_material = process_mat
	particules_collir.one_shot = true
	particules_collir.explosiveness = 0.9
	particules_collir.amount = 40
	particules_collir.lifetime = 1.5
	process_mat.color = Color(1.0, 0.85, 0.0, 1.0)

	if EventBus.has_signal("cultiu_recollit"):
		EventBus.cultiu_recollit.connect(_on_cultiu_recollit)
	else:
		print("Signal cultiu_recollit no existeix a EventBus")

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
	
	if mode_plantacio and Input.is_action_just_pressed("accio_primaria"):
		plantar_a_cursor()
func _on_cultiu_recollit(posicio: Vector3):
	print("Event rebut a posicio: ", posicio)
	llançar_particules(particules_collir, posicio)
	
func _process(delta):
	if not mode_plantacio: return
	var espai = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var pos_ratolí = get_viewport().get_mouse_position()
	var origen = camera.project_ray_origin(pos_ratolí)
	var direccio = camera.project_ray_normal(pos_ratolí)
	
	var query = PhysicsRayQueryParameters3D.create(origen, origen + direccio * 100.0)
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		var posicio = resultat.position
		var gridmap = get_node("GridMap")
		
		# Busca el bloc plantable més pròxim horitzontalment
		var distancia_minima = 999.0
		var cell_coords_mes_propa = Vector3i.ZERO
		var item_name_mes_propa = ""
		var bloc_trobat = false
		
		for cell_coords in gridmap.get_used_cells():
			var cell_item = gridmap.get_cell_item(cell_coords)
			if cell_item >= 0:
				var item_name = gridmap.mesh_library.get_item_name(cell_item)
				print("Bloc trobat: ", item_name, " - En blocs_plantables? ", item_name in blocs_plantables)
				if item_name in blocs_plantables:
					# Distància només en X, Z (ignora Y)
					var dist_xz = sqrt(pow(cell_coords.x - int(posicio.x), 2) + pow(cell_coords.z - int(posicio.z), 2))
					
					# Prefereix blocs a la mateixa altura o una/dues per sota
					var altura_ok = (cell_coords.y <= int(posicio.y) and cell_coords.y >= int(posicio.y) - 2)
					
					if altura_ok and dist_xz < distancia_minima:
						distancia_minima = dist_xz
						cell_coords_mes_propa = cell_coords
						item_name_mes_propa = item_name
						bloc_trobat = true
		
		if bloc_trobat:
			var posicio_cursor = gridmap.map_to_local(cell_coords_mes_propa)

			if item_name_mes_propa.contains("half"):
				posicio_cursor.y = float(cell_coords_mes_propa.y) + 0.5
			else:
				posicio_cursor.y = float(cell_coords_mes_propa.y) + 1.0
				cursor.global_position = posicio_cursor
				cursor.visible = true
		else:
			cursor.visible = false
		
		var mat = cursor.get_surface_override_material(0)
		if mat == null: return
		
		if bloc_trobat and (item_name_mes_propa in blocs_plantables) and not cultiu_a_prop(cursor.global_position):
			mat.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
		else:
			mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
	else:
		cursor.visible = false


func plantar_a_cursor():
	print("plantar_a_cursor() cridat")
	var espai = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var pos_ratolí = get_viewport().get_mouse_position()
	var origen = camera.project_ray_origin(pos_ratolí)
	var direccio = camera.project_ray_normal(pos_ratolí)
	
	var query = PhysicsRayQueryParameters3D.create(origen, origen + direccio * 100.0)
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		print("Raycast hit")
		var posicio = resultat.position
		var gridmap = get_node("GridMap")
		
		# Busca el bloc plantable més pròxim horitzontalment
		var distancia_minima = 999.0
		var cell_coords_mes_propa = Vector3i.ZERO
		var item_name_mes_propa = ""
		var bloc_trobat = false
		
		for cell_coords in gridmap.get_used_cells():
			var cell_item = gridmap.get_cell_item(cell_coords)
			if cell_item >= 0:
				var item_name = gridmap.mesh_library.get_item_name(cell_item)
				if item_name in blocs_plantables:
					# Distància només en X, Z (ignora Y)
					var dist_xz = sqrt(pow(cell_coords.x - int(posicio.x), 2) + pow(cell_coords.z - int(posicio.z), 2))
					
					# Prefereix blocs a la mateixa altura o una/dues per sota
					var altura_ok = (cell_coords.y <= int(posicio.y) and cell_coords.y >= int(posicio.y) - 2)
					
					if altura_ok and dist_xz < distancia_minima:
						distancia_minima = dist_xz
						cell_coords_mes_propa = cell_coords
						item_name_mes_propa = item_name
						bloc_trobat = true
		
		if not bloc_trobat:
			print("No hi ha bloc plantable aquí!")
			return
		
		var posicio_cultiu = gridmap.map_to_local(cell_coords_mes_propa)

		# Detecta l'altura real del bloc
		if item_name_mes_propa.contains("half"):
			posicio_cultiu.y = float(cell_coords_mes_propa.y) + 1  # Half-blocks a +0.5
		else:
			posicio_cultiu.y = float(cell_coords_mes_propa.y) + 1.5  # Blocs normals a +1.0

		print("Posició cultiu: ", posicio_cultiu, " - Bloc: ", item_name_mes_propa)
		print("Posició cultiu: ", posicio_cultiu)
		
		print("Comprova dins_zona_hort: ", dins_zona_hort(posicio_cultiu))
		if not dins_zona_hort(posicio_cultiu):
			print("Fora de zona hort")
			return
		
		if cultiu_a_prop(posicio_cultiu):
			print("Cultiu a prop")
			return
		
		print("Tot OK, plantant...")
		var cultiu = cultiu_escena.instantiate()
		add_child(cultiu)
		cultiu.global_position = posicio_cultiu
		llançar_particules(particules_plantar, posicio_cultiu)
		Inventari.items["llavor_raim"] -= 1
		mode_plantacio = false
		cursor.visible = false
		print("Cultiu plantat!")
	else:
		print("Cap raycast hit")
	
func llançar_particules(particules: GPUParticles3D, posicio: Vector3):
	particules.global_position = posicio
	particules.restart()
	particules.emitting = true
	
func cultiu_a_prop(posicio: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("cultius"):
		if node.global_position.distance_to(posicio) < 1.0:
			return true
	return false
	
func dins_zona_hort(posicio: Vector3) -> bool:
	return zona_hort.conte_punt(posicio)
