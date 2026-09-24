extends Resource
class_name AcabatInterior
## Un acabat que el jugador pot posar a la casa: un tipus de terra o un color de paret.
## Crea'n de nous duplicant un .tres de Resources/acabats i afegeix-lo a CatalegAcabats.

enum Superficie { TERRA, PARET }

@export var id: String
@export var nom: String
@export var superficie: Superficie
@export var color := Color.WHITE
## Opcional. Dibuixa-la en escala de grisos i `color` la tenyirà:
## amb una sola textura de maó tens maons de tots els colors.
@export var textura: Texture2D
@export var preu := 0
## Quant suma a la decoració de la vermuteria
@export var punts_decoracio := 0

func es_gratuit() -> bool:
	return preu <= 0

func aplicar(material: StandardMaterial3D) -> void:
	material.albedo_color = color
	material.albedo_texture = textura
	if textura:
		# Coordenades del món: la textura es repeteix una vegada per cel·la,
		# sigui terra o paret, i quadra amb la graella de construcció
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE
	else:
		material.uv1_triplanar = false

func icona() -> Texture2D:
	if textura:
		return textura
	var imatge := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	imatge.fill(color)
	return ImageTexture.create_from_image(imatge)
