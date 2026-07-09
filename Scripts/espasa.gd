extends Node3D

signal atac_finalitzat

@onready var hitbox: Area3D = $EspasaOrientacio/EspasaSprite/Hitbox
var atacant = false
var dany_actual = 0
const ANGLE_BASE_CAMERA := -50.0

func _ready():
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
func atacar_rapid():
	_swing(0.05, 0.10, 1)   # dany baix, ràpid

func atacar_fort():
	_swing(0.15, 0.35, 2)   # dany alt, més lent

func _swing(temps_ida, temps_tornada, dany):
	if atacant:
		return
	atacant = true
	dany_actual = dany
	hitbox.monitoring = true
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:y", -90.0, temps_ida)
	tween.tween_property(self, "rotation_degrees:y", 90.0, temps_tornada)
	tween.tween_property(self, "rotation_degrees:y", 0.0, temps_tornada * 0.5)
	tween.tween_callback(func():
		hitbox.monitoring = false
		atacant = false
		atac_finalitzat.emit()
	)

func _on_hitbox_body_entered(body):
	if body.has_method("rebre_dany"):
		body.rebre_dany(dany_actual)
