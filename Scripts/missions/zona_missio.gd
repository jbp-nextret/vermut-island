extends Area3D
class_name ZonaMissio
## Un lloc per als objectius de missió "Arribar a...". Quan hi entra el jugador, avisa
## les missions. Mentre alguna missió activa hi vol anar, es veu una columna de llum.

@export var id := ""
@export var nom := ""

var llum: MeshInstance3D

func _ready():
	add_to_group("zones_missio")
	body_entered.connect(_on_entrar)
	monitoring = true
	collision_mask = 0xFFFFFFFF
	llum = MeshInstance3D.new()
	var cilindre := CylinderMesh.new()
	cilindre.top_radius = 0.6
	cilindre.bottom_radius = 0.6
	cilindre.height = 6.0
	cilindre.cap_top = false
	cilindre.cap_bottom = false
	llum.mesh = cilindre
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.18)
	llum.material_override = mat
	llum.position = Vector3.UP * 3.0
	llum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(llum)
	Missions.missions_canviades.connect(_actualitzar)
	_actualitzar()

func _on_entrar(body: Node3D):
	if body.is_in_group("player"):
		Missions.arribat(id)

## La llum només surt si alguna missió activa hi ha d'anar (i encara no hi ha anat)
func _actualitzar():
	var cal := false
	for m in Missions.missions_actives():
		for i in m.objectius.size():
			var o: ObjectiuMissio = m.objectius[i]
			if o.tipus == ObjectiuMissio.Tipus.ARRIBAR and o.lloc == id and Missions.progres(m.id, i) < 1:
				cal = true
	llum.visible = cal

func _process(delta):
	if llum.visible:
		llum.rotate_y(delta * 0.5)
		(llum.material_override as StandardMaterial3D).albedo_color.a = 0.14 + 0.06 * sin(Time.get_ticks_msec() * 0.003)
