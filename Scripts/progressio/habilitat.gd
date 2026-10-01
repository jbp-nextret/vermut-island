@tool
extends Resource
class_name Habilitat
## Una habilitat d'un arbre (s'edita a l'inspector de Godot).

@export var id := ""
@export var nom := ""
@export var icona := "✨"
## Text de l'efecte. Si conté %d, s'hi posa el valor total (rangs × per_rang)
@export_multiline var text := ""
## Opcional: un text per a cada rang (substitueix `text`)
@export var textos: PackedStringArray = []
## Rangs màxims (0 = encara no disponible, surt com "Aviat")
@export var max := 1
## Quant suma cada rang (el que retorna Progressio.valor(id))
@export var per_rang := 1.0
## Si el valor és un percentatge (0.15 → "15 %")
@export var percent := false
## Posició dins de l'arbre al menú
@export var col := 0
@export var fila := 0
## Condicions per desbloquejar-la (el primer rang)
@export var requisits: Array[Requisit] = []

func text_efecte(rangs: int) -> String:
	if textos.size() > 0 and rangs > 0:
		return textos[clampi(rangs - 1, 0, textos.size() - 1)]
	if not "%" in text:
		return text
	var v: float = per_rang * rangs
	return text % (roundi(v * 100.0) if percent else roundi(v))

## Les habilitats de les quals depèn (per dibuixar les línies)
func habilitats_requerides() -> Array:
	return requisits.filter(func(r): return r.tipus == Requisit.Tipus.HABILITAT)
