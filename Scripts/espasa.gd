extends Node3D
@onready var hitbox: Area3D = $Espasa/EspasaSprite/Hitbox
@onready var slash_tall: Sprite3D = $Espasa/SlashTall
@onready var slash_estocada: Sprite3D = $Espasa/SlashEstocada
@export var slash_colors: Array[Color] = [Color.WHITE, Color(0.8, 0.9, 1.0), Color(1.0, 0.95, 0.7)]
var dany_actual = 10
var pot_fer_mal = false

func _ready():
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	slash_tall.visible = false
	slash_estocada.visible = false
	hitbox.monitoring = true

func _on_hitbox_body_entered(body):
	if body == get_tree().get_first_node_in_group("jugador"):
		return  # ignora el propi jugador
	if body.has_method("prendre_dany"):
		print("Enemic detectat ", body.name)
		body.prendre_dany(dany_actual)

func activar_hitbox():
	print("Hitbox espasa activat")
	hitbox.monitoring = true

func desactivar_hitbox():
	print("Hitbox espasa desactivat")
	hitbox.monitoring = false

func mostrar_slash_tall():
	_randomitzar_slash(slash_tall, 0.8, 1.0)
	slash_tall.visible = true

func amagar_slash_tall():
	slash_tall.visible = false

func mostrar_slash_estocada():
	_randomitzar_slash(slash_estocada, 1.1, 1.4)
	slash_estocada.visible = true

func amagar_slash_estocada():
	slash_estocada.visible = false

func _randomitzar_slash(slash: Sprite3D, mida_min: float, mida_max: float):
	slash.rotation_degrees.z = randf_range(-15.0, 15.0)
	slash.scale = Vector3.ONE * randf_range(mida_min, mida_max)
	slash.modulate = slash_colors[randi() % slash_colors.size()]
	slash.modulate.a = 1.0
