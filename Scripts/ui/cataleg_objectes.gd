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
	"eina_espasa": {"nom": "Espasa espectral", "icona": "⚔️", "descripcio": "Eina. Posa-la a la barra ràpida: clic per fer un tall, clic dret per a l'estocada. Talla l'herba i en treu fibra."},
	"eina_destral": {"nom": "Destral màgica", "icona": "🪓", "descripcio": "Eina. Amb ella a la mà, clica un arbre per talar-lo i treure'n fusta (i a vegades olives)."},
	"eina_pic": {"nom": "Pic màgic", "icona": "⛏️", "descripcio": "Eina. Amb ell a la mà, clica una roca per picar-la i treure'n pedra."},
	"eina_grimori_foc": {"nom": "Grimori de foc", "icona": "🔥", "descripcio": "Eina. Amb ell a la mà, cada clic llança una bola de foc cap al ratolí (gasta mana)."},
	"eina_regadora": {"nom": "Regadora màgica", "icona": "💧", "descripcio": "Eina. Clic sobre la terra per regar-la amb un encanteri. L'aigua es recupera sola o amb la pluja."},
	"eina_aixada": {"nom": "Aixada màgica", "icona": "⛏", "descripcio": "Eina. Llaura l'herba per fer-la cultivable. Si hi ha una marca de terra remoguda, desenterra el que hi ha."},
	"olives": {"nom": "Olives", "icona": "🫒", "descripcio": "De les oliveres de l'illa (a vegades en cauen quan tales un arbre). A la barrica les pots marinar."},
	"olives_marinades": {"nom": "Olives marinades", "icona": "🥗", "descripcio": "Llança-les (L) a prop d'una criatura herbívora: s'hi acostarà a menjar i la podràs domesticar."},
	"vermut_hipnotic": {"nom": "Vermut hipnòtic", "icona": "🧪", "descripcio": "Llança'l (L) a una criatura: la deixa atordida uns segons i la podràs domesticar. Les més fortes, debilita-les abans."},
}

static func info(id: String) -> Dictionary:
	if OBJECTES.has(id):
		return OBJECTES[id]
	# Fòssils i tresors: els defineix l'arqueologia
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre and arbre.root.has_node("Arqueologia"):
		var i: Dictionary = arbre.root.get_node("Arqueologia").info_objecte(id)
		if not i.is_empty():
			return i
	return {"nom": id.capitalize(), "icona": "📦", "descripcio": ""}
