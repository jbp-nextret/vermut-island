extends Label

# Dies de la setmana
const DIES = ["Dilluns", "Dimarts", "Dimecres", "Dijous", "Divendres", "Dissabte", "Diumenge"]

func _ready():
	text = "00:00"

func _process(delta):
	var hora_actual = GestorTemps.hora_actual
	
	var hores = int(hora_actual)
	var minuts = int((hora_actual - hores) * 60)
	
	var icona = ""
	if hora_actual < 6.0:
		icona = "🌙"
	elif hora_actual < 9.0:
		icona = "🌅"
	elif hora_actual < 18.0:
		icona = "☀️"
	elif hora_actual < 20.0:
		icona = "🌇"
	else:
		icona = "🌙"
	
	var dia_setmana = DIES[(GestorTemps.dia_actual - 1) % 7]
	text = "%s %02d:%02d\n%s" % [icona, hores, minuts, dia_setmana]
