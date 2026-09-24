extends Node3D

const PORING := preload("res://Scenes/Poring.tscn")
const VERMUT := preload("res://Scenes/Vermut.tscn")   
@export var door: Marker3D

func _ready() -> void:
	print("TestSpawner llest. Door: ", door)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:   # F1: fer entrar un poring (prova)
			print("F1 premuda")
			spawn_poring()
		elif event.keycode == KEY_F2:   # F2: servir tothom (prova)
			serve_all()

func spawn_poring() -> void:
	var seats := get_tree().get_nodes_in_group("seats")
	print("Seients al grup: ", seats.size())
	var free_seats := seats.filter(func(s): return s.is_free())
	if free_seats.is_empty():
		print("No hi ha seients lliures")
		return
	var p: Poring = PORING.instantiate()
	get_parent().add_child(p)
	p.global_position = door.global_position
	p.setup(free_seats.pick_random(), door.global_position)
	print("Poring creat a ", p.global_position)
	p.order_placed.connect(func(po, product): print(po.name, " demana ", product))
	p.left.connect(func(po): print(po.name, " ha marxat"))

func serve_all() -> void:
	for p in get_tree().get_nodes_in_group("porings"):
		if p.state != Poring.State.WAITING_ORDER:
			continue
		var drink: Drink = VERMUT.instantiate()
		get_parent().add_child(drink)
		drink.global_position = p.global_position + Vector3(0.4, 0, 0)   # provisional
		if not p.serve(drink):
			drink.queue_free()
