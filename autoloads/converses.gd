extends Node
## Converses amb els NPCs (fet amb Dialogic). Mentre dura una conversa, el jugador no
## es mou ni ataca, el temps s'atura i el HUD d'accions s'amaga (GameState.en_dialeg).
##
## Des dels diàlegs (.dtl) es pot fer servir:
##   {Converses.nom_jugador}             el nom del jugador
##   if Missions.disponible("id"): ...   (vegeu autoloads/missions.gd)
##   do Missions.acceptar("id")
##   do Grup.unir("marta")              (vegeu autoloads/grup.gd)

signal conversa_iniciada(npc: Node)
signal conversa_acabada(npc: Node)

var npc_actual: Node = null

var nom_jugador: String:
	get: return Customization.nom

func _ready():
	Dialogic.timeline_ended.connect(_on_acabada)

func parlant() -> bool:
	return npc_actual != null or Dialogic.current_timeline != null

## Comença la conversa amb un NPC (fa servir el seu `dialeg`)
func parlar(npc: Node) -> void:
	if parlant() or npc.dialeg.is_empty():
		return
	npc_actual = npc
	GameState.en_dialeg = true
	conversa_iniciada.emit(npc)
	# Un fotograma després: així la mateixa tecla que l'ha obert no avança el primer text
	Dialogic.call_deferred("start", npc.dialeg)

func _on_acabada():
	var npc := npc_actual
	npc_actual = null
	GameState.en_dialeg = false
	conversa_acabada.emit(npc)
