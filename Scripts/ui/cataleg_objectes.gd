class_name CatalegObjectes
## Nom, icona i descripció de cada objecte de l'inventari.
## Els que no hi són es mostren amb el seu identificador i una caixa.

const OBJECTES := {
	"llavor_raim": {"nom": "Llavors", "icona": "🌱", "descripcio": "Llavors per plantar qualsevol cultiu de l'hort. En culls més quan fas collita."},
	"raim": {"nom": "Raïm", "icona": "🍇", "descripcio": "Collit dels ceps. A la barrica, cada raïm dona 3 vermuts."},
	"fusta": {"nom": "Fusta", "icona": "🪵", "descripcio": "La dels arbres que tales amb la destral màgica. Servirà per construir i fabricar."},
	"fibra": {"nom": "Fibra", "icona": "🌾", "descripcio": "La treus de tallar l'herba amb l'espasa. Servirà per fer cordes i teixits."},
	"pedra": {"nom": "Pedra", "icona": "🪨", "descripcio": "La pices de les roques amb el pic màgic. Servirà per construir."},
	"dosis_vermut": {"nom": "Vermut preparat", "icona": "🍷", "descripcio": "Vermut ja fet a la barrica, a punt per servir."},
}

static func info(id: String) -> Dictionary:
	if OBJECTES.has(id):
		return OBJECTES[id]
	return {"nom": id.capitalize(), "icona": "📦", "descripcio": ""}
