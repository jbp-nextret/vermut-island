@tool
extends StaticBody3D
class_name TaulaFabricacio
## La taula de fabricació màgica (provisional: feta amb codi, es pot substituir per un
## model propi). F a prop obre el menú de fabricació. Un cercle màgic hi gira a sobre.

const CERCLE := preload("res://Sprites/Misc/magic-3.png")

var cercle: Sprite3D
var cristall: MeshInstance3D
var temps := 0.0

func _ready():
	_construir()
	if Engine.is_editor_hint():
		return
	add_to_group("interactuables")
	add_to_group("taula_fabricacio")

func pot_interactuar(_jugador: Node) -> bool:
	return true

func text_interaccio(_jugador: Node) -> String:
	return "Fabricar"

func punt_interaccio() -> Vector3:
	return global_position + Vector3.UP * 0.6

func interactuar(_interaccio: Node) -> void:
	MenuFabricacio.obrir(self, "taula")

## Ocupa aquest punt? (perquè no hi surtin arbres ni roques)
func ocupa(posicio: Vector3, marge := 0.0) -> bool:
	return Vector2(posicio.x - global_position.x, posicio.z - global_position.z).length() < 1.5 + marge

func _process(delta):
	temps += delta
	if cercle:
		cercle.rotation.y = temps * 0.6
		cercle.modulate.a = 0.55 + 0.25 * sin(temps * 2.0)
	if cristall:
		cristall.position.y = 1.55 + 0.06 * sin(temps * 1.7)
		cristall.rotation.y = temps * 1.2

## Quan fabriques: el cercle s'encén i l'objecte surt flotant
func efecte_fabricar(icona: String):
	var l := Label3D.new()
	l.text = icona
	l.font_size = 110
	l.pixel_size = 0.006
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(l)
	l.position = Vector3.UP * 1.1
	var t := l.create_tween()
	t.tween_property(l, "position", Vector3.UP * 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	t.tween_callback(l.queue_free)
	var p := CPUParticles3D.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.one_shot = true
	p.emitting = true
	p.amount = 30
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.6
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.0
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.85, 0.65, 1.0)
	quad.material = mat
	p.mesh = quad
	add_child(p)
	p.position = Vector3.UP * 0.95
	get_tree().create_timer(1.5, true, false, true).timeout.connect(p.queue_free)

# ─────────────── Model provisional

func _construir():
	for c in get_children():
		c.queue_free()
	var fusta := StandardMaterial3D.new()
	fusta.albedo_color = Color(0.45, 0.3, 0.2)
	fusta.roughness = 1.0
	var tapa := StandardMaterial3D.new()
	tapa.albedo_color = Color(0.36, 0.26, 0.42)
	tapa.roughness = 0.8
	_caixa(Vector3(1.4, 0.12, 0.9), Vector3(0, 0.85, 0), tapa)
	for x in [-0.6, 0.6]:
		for z in [-0.35, 0.35]:
			_caixa(Vector3(0.12, 0.8, 0.12), Vector3(x, 0.4, z), fusta)
	# Col·lisió de tota la taula
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.4, 0.95, 0.9)
	forma.shape = caixa
	forma.position = Vector3.UP * 0.47
	add_child(forma)
	# Cercle màgic a sobre de la taula
	cercle = Sprite3D.new()
	cercle.texture = CERCLE
	cercle.pixel_size = 1.1 / maxf(1.0, CERCLE.get_width())
	cercle.rotation_degrees.x = -90
	cercle.position = Vector3.UP * 0.92
	cercle.modulate = Color(0.8, 0.6, 1.0, 0.7)
	cercle.shaded = false
	cercle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.add_child(cercle)
	# Un cristall que flota
	cristall = MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(0.2, 0.35, 0.2)
	cristall.mesh = prisma
	var vidre := StandardMaterial3D.new()
	vidre.albedo_color = Color(0.75, 0.55, 1.0)
	vidre.emission_enabled = true
	vidre.emission = Color(0.6, 0.35, 1.0)
	vidre.emission_energy_multiplier = 1.5
	cristall.material_override = vidre
	cristall.position = Vector3.UP * 1.55
	add_child(cristall)
	var llum := OmniLight3D.new()
	llum.light_color = Color(0.75, 0.55, 1.0)
	llum.light_energy = 0.8
	llum.omni_range = 3.5
	llum.position = Vector3.UP * 1.4
	add_child(llum)

func _caixa(mida: Vector3, pos: Vector3, mat: Material):
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = mida
	m.mesh = b
	m.material_override = mat
	m.position = pos
	add_child(m)
