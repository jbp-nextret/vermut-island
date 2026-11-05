extends Node3D
class_name Esquer
## Unes olives marinades a terra. Atrauen les criatures herbívores del voltant; cada
## una se'n menja una ració. Al cap d'una estona es fan malbé i desapareixen.

const DURADA := 30.0
const RACIONS := 2

var racions := RACIONS
var temps := 0.0
var temps_crida := 0.0
var olives: Array[MeshInstance3D] = []

func _ready():
	add_to_group("esquers")
	var esfera := SphereMesh.new()
	esfera.radius = 0.07
	esfera.height = 0.11
	for i in 5:
		var m := MeshInstance3D.new()
		m.mesh = esfera
		m.material_override = Llancable._material(Color(0.42, 0.52, 0.18).darkened(randf() * 0.25))
		m.position = Vector3(randf_range(-0.14, 0.14), 0.05, randf_range(-0.14, 0.14))
		add_child(m)
		olives.append(m)
	_cridar()

func _process(delta):
	temps += delta
	temps_crida -= delta
	if temps_crida <= 0.0:
		temps_crida = 1.0
		_cridar()
	if temps > DURADA:
		_acabar()

## Avisa les herbívores que hi ha menjar
func _cridar():
	if racions <= 0:
		return
	var interessades := 0
	for c in get_tree().get_nodes_in_group("criatures_salvatges"):
		if c.esquer == self:
			interessades += 1
	for c in get_tree().get_nodes_in_group("criatures_salvatges"):
		if interessades >= racions:
			return
		if c.esquer != self and Criatura._pla(c.global_position - global_position).length() <= Criatura.RADI_ESQUER and c.atraure(self):
			interessades += 1

## Una criatura arriba a menjar: si en queden, se'n menja una ració
func menjar() -> bool:
	if racions <= 0:
		return false
	racions -= 1
	for i in 2:
		if not olives.is_empty():
			olives.pop_back().queue_free()
	if racions <= 0:
		get_tree().create_timer(Criatura.DURADA_MENJAR).timeout.connect(_acabar)
	return true

func _acabar():
	if is_queued_for_deletion():
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	t.tween_callback(queue_free)
