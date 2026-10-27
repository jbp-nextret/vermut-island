extends Node3D
class_name Barrica
## Una barrica de la vermuteria. Va com a fill de l'escena de moble de la barrica.
## Fora del servei: obre el menú per posar-hi a fermentar una recepta o, quan ja és a punt,
## treure'n i guardar-hi com en un cofre. Durant el servei: omple gots del que hi ha.
## El que conté es guarda a Celler (per la cel·la on és el moble).

const VERMUT := preload("res://Scenes/Vermut.tscn")

var etiqueta: Label3D
var temps_etiqueta := 0.0

func _ready():
	# La preview del mode construcció no és a "mobles_base": així no s'hi pot interactuar
	if not get_parent().is_in_group("mobles_base"):
		return
	add_to_group("interactuables")
	etiqueta = Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.font_size = 32
	etiqueta.pixel_size = 0.006
	etiqueta.outline_size = 10
	etiqueta.no_depth_test = true
	etiqueta.position = Vector3.UP * 0.75
	add_child(etiqueta)
	Celler.canviat.connect(func(_c): _actualitzar_etiqueta())
	_actualitzar_etiqueta()

func clau() -> String:
	return Celler.clau(get_parent().global_position)

func _process(delta):
	temps_etiqueta -= delta
	if etiqueta and temps_etiqueta <= 0.0:
		temps_etiqueta = 0.5
		_actualitzar_etiqueta()

## A sobre de la barrica: què hi fermenta (i quant falta) o què hi ha a punt
func _actualitzar_etiqueta():
	var e := Celler.estat(clau())
	if e.is_empty():
		etiqueta.text = ""
		return
	# (sense emojis: als Label3D no sempre es veuen)
	var nom: String = CatalegObjectes.info(e.producte).nom
	if Celler.fermentant(clau()):
		etiqueta.text = "%s\n⏳ %d%%" % [nom, roundi(Celler.progres(clau()) * 100.0)]
		etiqueta.modulate = Color(1.0, 0.85, 0.55)
	else:
		etiqueta.text = "%s\n×%d" % [nom, int(e.quantitat)]
		etiqueta.modulate = Color(0.75, 1.0, 0.7)

func punt_interaccio() -> Vector3:
	return global_position

func pot_interactuar(jugador: InteraccioJugador) -> bool:
	# Sempre es pot tornar un got; omplir-ne només mentre la vermuteria és oberta
	return jugador.porta_objecte() or GameState.mode in [GameState.Mode.SERVEI, GameState.Mode.EXPLORAR]

func text_interaccio(jugador: InteraccioJugador) -> String:
	if jugador.porta_objecte():
		return "Tornar el got"
	if GameState.mode != GameState.Mode.SERVEI:
		return "Barrica"
	var c := clau()
	if Celler.fermentant(c):
		return "Encara fermenta (%d h)" % ceili(Celler.hores_que_queden(c))
	var queden := Celler.a_punt(c)
	if queden <= 0:
		return "Barrica buida"
	var producte: String = Celler.estat(c).producte
	if not Celler.SERVIBLES.has(producte):
		return "Això no es serveix"
	return "Omplir un got de %s (%d)" % [CatalegObjectes.info(producte).nom.to_lower(), queden]

func interactuar(jugador: InteraccioJugador) -> void:
	var c := clau()
	if jugador.porta_objecte():
		var got = jugador.deixar_objecte()
		# El vermut torna a la barrica (si hi cap; si no, a la que en tingui o es perd)
		var producte: String = got.product if got is Drink else "vermut"
		got.queue_free()
		var e := Celler.estat(c)
		if (e.is_empty() or e.producte == producte) and not Celler.fermentant(c):
			Celler.posar(c, producte, 1)
		return
	if GameState.mode != GameState.Mode.SERVEI:
		MenuFabricacio.obrir(self, "barrica")
		return
	var e := Celler.estat(c)
	if e.is_empty() or not Celler.SERVIBLES.has(e.producte) or Celler.a_punt(c) <= 0:
		TextFlotant.mostrar(get_parent().get_parent(), global_position + Vector3.UP, "Barrica buida 🍷", Color(1, 0.5, 0.5))
		return
	var producte := Celler.servir_un(c)
	var got: Drink = VERMUT.instantiate()
	got.product = producte
	got.color = Celler.color(producte)
	jugador.agafar(got)
	# Petit bot de la barrica
	efecte_fabricar("")

## Un bot de la barrica (en fabricar o omplir un got)
func efecte_fabricar(_icona: String):
	var moble := get_parent() as Node3D
	var t := moble.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(moble, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
	t.tween_property(moble, "scale", Vector3.ONE, 0.12)
