extends SpotLight3D
## La llum que entra per una finestra. Segueix l'hora del GestorTemps:
## plena de dia, s'apaga al capvespre i el vidre passa de clar a blau fosc.

const COLOR_VIDRE_DIA := Color(0.75, 0.9, 1.0)
const COLOR_VIDRE_NIT := Color(0.05, 0.08, 0.25)

@export var energia_dia := 2.5
@export var vidre: MeshInstance3D

var material_vidre: StandardMaterial3D

func _ready():
	if vidre:
		material_vidre = vidre.get_active_material(0) as StandardMaterial3D
	_actualitzar()

func _process(_delta):
	_actualitzar()

func _actualitzar():
	var dia := llum_del_dia(GestorTemps.hora_actual)
	light_energy = energia_dia * dia
	if material_vidre:
		material_vidre.emission = COLOR_VIDRE_NIT.lerp(COLOR_VIDRE_DIA, dia)

## 0 de nit, 1 de dia, amb l'alba (6-8 h) i el capvespre (18-20 h) graduals
static func llum_del_dia(hora: float) -> float:
	if hora < 6.0 or hora >= 20.0:
		return 0.0
	if hora < 8.0:
		return (hora - 6.0) / 2.0
	if hora > 18.0:
		return (20.0 - hora) / 2.0
	return 1.0
