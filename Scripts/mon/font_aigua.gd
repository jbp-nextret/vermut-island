extends Node3D
class_name FontAigua
## L'aigua dolça del mig de l'illa: amb la F hi omples la regadora de cop.
## (També s'omple sola a poc a poc, i de cop quan plou.)

var aigua: MeshInstance3D
var regador: Regador

static func crear(p_aigua: MeshInstance3D, p_regador: Regador) -> FontAigua:
	var f := FontAigua.new()
	f.name = "FontAigua"
	f.aigua = p_aigua
	f.regador = p_regador
	return f

func _ready():
	add_to_group("interactuables")

func pot_interactuar(_jugador: Node) -> bool:
	return is_instance_valid(aigua) and is_instance_valid(regador) and regador.carregues < regador.carregues_max() - 0.05

func text_interaccio(_jugador: Node) -> String:
	return "💧 Omplir la regadora"

## El punt de la vora de l'aigua més proper al jugador
func punt_interaccio() -> Vector3:
	var caixa := aigua.global_transform * aigua.get_aabb()
	var j := get_tree().get_first_node_in_group("player") as Node3D
	var p := j.global_position if j else caixa.get_center()
	return Vector3(clampf(p.x, caixa.position.x, caixa.end.x), caixa.end.y, clampf(p.z, caixa.position.z, caixa.end.z))

func interactuar(_interaccio: Node) -> void:
	regador.carregues = regador.carregues_max()
	var punt := punt_interaccio()
	TextFlotant.mostrar(get_tree().current_scene, punt + Vector3.UP * 0.8, "💧 Regadora plena", Regador.COLOR_AIGUA)
	# Unes gotes que salten de l'aigua
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.09
	var malla := SphereMesh.new()
	malla.radius = 0.5
	malla.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Regador.COLOR_AIGUA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = mat
	p.mesh = malla
	get_tree().current_scene.add_child(p)
	p.global_position = punt
	p.emitting = true
	p.finished.connect(p.queue_free)
