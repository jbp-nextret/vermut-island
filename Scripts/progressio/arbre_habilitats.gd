class_name ArbreHabilitats
## Els tres arbres d'habilitats. Cada habilitat té uns quants rangs; cada rang costa un
## punt (en guanyes un per nivell). Algunes en necessiten d'altres abans (`requisit`).
## `per_rang` és quant suma cada rang; `text` es formata amb el valor total.
## `col` i `fila` són la posició dins de l'arbre al menú.

const ARBRES := [
	{
		"id": "atac", "nom": "Màgia d'atac", "icona": "⚔", "color": Color(1.0, 0.55, 0.45),
		"habilitats": [
			{"id": "dany_espasa", "nom": "Fil espectral", "icona": "🗡", "max": 3, "per_rang": 0.15, "percent": true,
				"text": "+%d %% de mal amb l'espasa (tall, remolí i estocada)", "col": 1, "fila": 0},
			{"id": "abast_dash", "nom": "Estocada llarga", "icona": "💨", "max": 3, "per_rang": 0.2, "percent": true,
				"text": "+%d %% de distància de l'estocada", "col": 0, "fila": 1, "requisit": ["dany_espasa", 1]},
			{"id": "recarrega_foc", "nom": "Foc ràpid", "icona": "🔥", "max": 3, "per_rang": 0.12, "percent": true,
				"text": "−%d %% de recàrrega de la bola de foc", "col": 2, "fila": 1, "requisit": ["dany_espasa", 1]},
			{"id": "dany_foc", "nom": "Flama intensa", "icona": "☄", "max": 3, "per_rang": 0.25, "percent": true,
				"text": "+%d %% de mal de la bola de foc", "col": 2, "fila": 2, "requisit": ["recarrega_foc", 2]},
			{"id": "escut", "nom": "Escut arcà", "icona": "🛡", "max": 0, "per_rang": 0.0,
				"text": "Pròximament: un escut que atura els cops", "col": 1, "fila": 2, "requisit": ["dany_espasa", 3]},
		],
	},
	{
		"id": "util", "nom": "Màgia útil", "icona": "✨", "color": Color(0.55, 0.8, 1.0),
		"habilitats": [
			{"id": "mana_max", "nom": "Reserva de mana", "icona": "🔷", "max": 3, "per_rang": 20.0,
				"text": "+%d de mana màxim", "col": 1, "fila": 0},
			{"id": "abast_regar", "nom": "Pluja ampla", "icona": "💧", "max": 2, "per_rang": 0.25, "percent": true,
				"text": "+%d %% d'àrea de l'encanteri de regar", "col": 0, "fila": 1, "requisit": ["mana_max", 1]},
			{"id": "regen_mana", "nom": "Flux arcà", "icona": "✴", "max": 3, "per_rang": 0.3, "percent": true,
				"text": "+%d %% de recuperació de mana", "col": 1, "fila": 1, "requisit": ["mana_max", 1]},
			{"id": "abast_llaurar", "nom": "Aixada llarga", "icona": "⛏", "max": 3, "per_rang": 2.0,
				"text": "+%d cel·les d'àrea i d'abast en llaurar", "col": 2, "fila": 1, "requisit": ["mana_max", 1]},
			{"id": "aigua_regar", "nom": "Núvol generós", "icona": "🌧", "max": 3, "per_rang": 2.0,
				"text": "+%d càrregues d'aigua per regar", "col": 0, "fila": 2, "requisit": ["abast_regar", 1]},
		],
	},
	{
		"id": "munda", "nom": "Mundà", "icona": "🌿", "color": Color(0.6, 0.95, 0.5),
		"habilitats": [
			{"id": "salut_max", "nom": "Constitució", "icona": "❤", "max": 3, "per_rang": 20.0,
				"text": "+%d de vida màxima", "col": 1, "fila": 0},
			{"id": "velocitat", "nom": "Cames lleugeres", "icona": "👟", "max": 3, "per_rang": 0.08, "percent": true,
				"text": "+%d %% de velocitat de moviment", "col": 0, "fila": 1, "requisit": ["salut_max", 1]},
			{"id": "botanica", "nom": "Botànica", "icona": "🌼", "max": 3, "per_rang": 1.0,
				"text": "Desbloqueja cultius nous per plantar", "col": 1, "fila": 1, "requisit": ["salut_max", 1],
				"textos": ["Pots plantar Calèndula", "Pots plantar Calèndula i Ortiga", "Pots plantar Calèndula, Ortiga i Carbassa esquer"]},
			{"id": "regeneracio", "nom": "Recuperació", "icona": "🩹", "max": 3, "per_rang": 1.0,
				"text": "Recupera %d de vida cada 3 s sense rebre mal", "col": 2, "fila": 1, "requisit": ["salut_max", 1]},
			{"id": "motxilla", "nom": "Motxilla gran", "icona": "🎒", "max": 3, "per_rang": 4.0,
				"text": "+%d espais a la motxilla", "col": 0, "fila": 2, "requisit": ["velocitat", 1]},
			{"id": "ma_verda", "nom": "Mà verda", "icona": "🌱", "max": 2, "per_rang": 0.25, "percent": true,
				"text": "%d %% de probabilitat que un cultiu regat creixi el doble", "col": 1, "fila": 2, "requisit": ["botanica", 1]},
			{"id": "vermuter", "nom": "Mestre vermuter", "icona": "🍷", "max": 2, "per_rang": 1.0,
				"text": "+%d vermuts per cada raïm", "col": 2, "fila": 2, "requisit": ["botanica", 1]},
		],
	},
]

static func habilitat(id: String) -> Dictionary:
	for arbre in ARBRES:
		for h in arbre.habilitats:
			if h.id == id:
				return h
	return {}

## Text de l'efecte amb un nombre de rangs concret
static func text_efecte(h: Dictionary, rangs: int) -> String:
	if h.has("textos") and rangs > 0:
		return h.textos[clampi(rangs - 1, 0, h.textos.size() - 1)]
	if not "%" in h.text:
		return h.text
	var v: float = h.per_rang * rangs
	return h.text % (roundi(v * 100.0) if h.get("percent", false) else roundi(v))
