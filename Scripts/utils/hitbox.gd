extends Area3D
class_name Hitbox

@export var damage: int = 10
var ja_impactats: Array = []

func _ready():
	area_entered.connect(_on_area_entered)
	monitoring = false  # desactivat per defecte

func activar():
	ja_impactats.clear()
	monitoring = true

func desactivar():
	monitoring = false

func _on_area_entered(area: Area3D):
	if area is Hurtbox and area not in ja_impactats:
		ja_impactats.append(area)
		area.rebre_dany(damage)
