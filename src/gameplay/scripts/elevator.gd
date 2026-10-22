extends Node2D
## Elevador da recepção. Fica atrás dos atores, que passam na frente dele até a porta.
##   await elevator.receive(ator)                 # ator anda até a porta e entra; o elevador fecha
##   await elevator.release(ator, destino)        # ator sai pela porta e anda até o destino
## Entradas (receive) começam na hora, mesmo com outra em andamento. Saídas (release) esperam
## o elevador esvaziar e a porta fechar, para ninguém sair enquanto alguém está entrando.
##
## Cada ator é MEDIDO (área visível do sprite atual) e encaixado na porta: a escala faz a figura
## caber na altura da abertura e a posição põe o topo da cabeça logo abaixo do batente. Assim
## funciona para qualquer NPC, mesmo com artes de tamanhos/deslocamentos diferentes.

## Abertura da porta, em pixels da arte do elevador (antes da escala do nó).
const PORTA_ARTE := Rect2(100, 70, 32, 129) # abaixo da luz indicadora (y 52–56) e do batente

## Fração da altura da porta que a figura ocupa (o resto é folga entre cabeça e batente).
@export_range(0.5, 1.0) var ocupacao_da_porta: float = 0.86
## Nunca deixa o ator maior que isto em relação ao tamanho que tinha no balcão.
@export var scale_maxima_na_porta: float = 0.92
## Quanto o ator anda para dentro/fora a partir da porta. A área dos atores termina na
## borda direita da porta, então essa parte fica escondida atrás do batente.
@export var distancia_entrando: float = 100.0
@export var tempo_entrando: float = 0.5
## Cor do ator lá dentro (na sombra do elevador).
@export var cor_dentro: Color = Color(0.45, 0.45, 0.5)

var _em_uso: int = 0 # entradas/saídas em andamento
var _used_rect_cache: Dictionary = {} # RID da textura -> área visível (sem transparência)

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _door_point: Marker2D = $DoorPoint


func _ready() -> void:
	_sprite.play("fechar")
	_sprite.frame = _sprite.sprite_frames.get_frame_count("fechar") - 1
	_sprite.pause()


## som_da_marta: a chegada fica grave e no volume cheio (ver _tocar_chegada).
func open(som_da_marta: bool = false) -> void:
	_tocar_chegada(som_da_marta)
	_sprite.play("abrir")
	await _sprite.animation_finished


func close() -> void:
	_sprite.play("fechar")
	await _sprite.animation_finished


## Som de chegada do elevador, só quando a porta estava fechada (não toca se já está aberta).
## Comum: 50% mais baixo. Quando quem sai é a Marta: volume original e mais grave.
func _tocar_chegada(som_da_marta: bool = false) -> void:
	if _sprite.animation != &"fechar":
		return
	if som_da_marta:
		Audio.play_sfx(Audio.CHEGOU_ELEVADOR, 0.0, Audio.ELEVADOR_MARTA_PITCH)
	else:
		Audio.play_sfx(Audio.CHEGOU_ELEVADOR, Audio.ELEVADOR_VOLUME_DB)


## Retângulo global da abertura da porta.
func door_rect() -> Rect2:
	var top_left: Vector2 = to_global(PORTA_ARTE.position)
	var bottom_right: Vector2 = to_global(PORTA_ARTE.end)
	return Rect2(top_left, bottom_right - top_left)


## Ponto (global) em frente à porta. Sem ator, devolve o marcador da cena.
func door_position(actor: Node2D = null) -> Vector2:
	if actor == null:
		return _door_point.global_position
	return _encaixe(actor)["posicao"]


func is_busy() -> bool:
	return _em_uso > 0


## O ator anda até a porta (encolhendo até caber nela), entra e o elevador fecha.
## O ator é liberado no fim.
func receive(actor: Node2D) -> void:
	_em_uso += 1
	_tocar_chegada()
	_sprite.play("abrir") # abre enquanto o ator caminha até a porta
	var encaixe: Dictionary = _encaixe(actor)
	var arrived: Array[bool] = [false]
	if "desk_scale" in actor:
		actor.desk_scale = encaixe["escala"]
	if actor.has_method("move_to_slot"):
		actor.move_to_slot(encaixe["posicao"], func(): arrived[0] = true, true)
	else:
		arrived[0] = true
	if _sprite.animation == &"abrir" and _sprite.is_playing():
		await _sprite.animation_finished
	while not arrived[0] and is_instance_valid(actor) and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree(): # a cena foi trocada no meio (ex.: menu principal pelo pause)
		return

	if is_instance_valid(actor):
		# Entra: segue para dentro e vai ficando na sombra; o recorte esconde o que passa da porta
		var entering := create_tween().set_parallel(true)
		entering.tween_property(actor, "global_position:x", actor.global_position.x + distancia_entrando, tempo_entrando)
		entering.tween_property(actor, "modulate", cor_dentro, tempo_entrando)
		await entering.finished
		if not is_inside_tree():
			return
		actor.queue_free()
	_em_uso -= 1
	if _em_uso == 0:
		await close()


## O ator começa dentro do elevador (escondido), sai pela porta e anda até "destino".
## Termina quando o ator chega ao destino; a porta fecha atrás dele.
## som_da_marta: a chegada do elevador fica grave (a Marta saindo).
func release(actor: Node2D, destino: Vector2, som_da_marta: bool = false) -> void:
	actor.visible = false
	while _em_uso > 0 or (_sprite.animation == &"fechar" and _sprite.is_playing()):
		if not is_inside_tree():
			return
		await get_tree().process_frame
	_em_uso += 1
	var escala_final: Vector2 = actor.scale
	var encaixe: Dictionary = _encaixe(actor)
	var porta: Vector2 = encaixe["posicao"]
	actor.scale = encaixe["escala"]
	actor.global_position = porta + Vector2(distancia_entrando, 0.0)
	actor.modulate = cor_dentro
	actor.visible = true

	await open(som_da_marta)
	# Sai: vem de dentro até a porta, saindo da sombra
	var leaving := create_tween().set_parallel(true)
	leaving.tween_property(actor, "global_position", porta, tempo_entrando)
	leaving.tween_property(actor, "modulate", Color.WHITE, tempo_entrando)
	await leaving.finished
	if not is_inside_tree():
		return

	# Anda até o destino voltando ao tamanho normal; a porta fecha logo depois que ele sai
	var arrived: Array[bool] = [false]
	if "desk_scale" in actor:
		actor.desk_scale = escala_final
	if actor.has_method("move_to_slot"):
		actor.move_to_slot(destino, func(): arrived[0] = true, true)
	else:
		actor.global_position = destino
		actor.scale = escala_final
		arrived[0] = true
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	_em_uso -= 1
	if _em_uso == 0:
		await close()
	while not arrived[0] and is_instance_valid(actor) and is_inside_tree():
		await get_tree().process_frame


## Escala e posição para o ator caber na porta: {"escala": Vector2, "posicao": Vector2}.
func _encaixe(actor: Node2D) -> Dictionary:
	var porta: Rect2 = door_rect()
	var escala: Vector2 = actor.scale * scale_maxima_na_porta
	var posicao := Vector2(_door_point.global_position.x, porta.position.y)
	var figura: Rect2 = _visible_rect_local(actor) # em coordenadas do ator, sem a escala dele
	if figura.size.y <= 0.0:
		return {"escala": escala, "posicao": _door_point.global_position}

	var altura_maxima: float = porta.size.y * ocupacao_da_porta
	var fator: float = minf(escala.y, altura_maxima / figura.size.y) / absf(actor.scale.y)
	escala = actor.scale * fator
	# Topo da figura logo abaixo do batente, com metade da folga em cima
	var folga: float = (porta.size.y - figura.size.y * absf(escala.y)) * 0.5
	posicao.y = porta.position.y + minf(folga, 6.0) - figura.position.y * absf(escala.y)
	return {"escala": escala, "posicao": posicao}


## Área visível (pixels não transparentes) dos sprites do ator, no espaço do ator sem a escala dele.
func _visible_rect_local(actor: Node2D) -> Rect2:
	var resultado := Rect2()
	var achou: bool = false
	var inverso: Transform2D = Transform2D(actor.global_rotation, Vector2.ONE, 0.0, actor.global_position).affine_inverse()
	for sprite in _sprites_visiveis(actor):
		var textura: Texture2D = _textura_atual(sprite)
		if textura == null:
			continue
		var usado: Rect2 = _used_rect(textura)
		var tamanho: Vector2 = textura.get_size()
		var origem: Vector2 = sprite.offset
		if sprite.centered:
			origem -= tamanho * 0.5
		var local := Rect2(origem + usado.position, usado.size)
		# Leva os cantos para o espaço do ator ignorando a escala do próprio ator
		var xform: Transform2D = inverso * sprite.global_transform
		var cantos: Array[Vector2] = [xform * local.position, xform * local.end,
			xform * Vector2(local.end.x, local.position.y), xform * Vector2(local.position.x, local.end.y)]
		for canto in cantos:
			var c: Vector2 = canto / actor.global_scale.abs()
			if not achou:
				resultado = Rect2(c, Vector2.ZERO)
				achou = true
			else:
				resultado = resultado.expand(c)
	return resultado


func _sprites_visiveis(raiz: Node) -> Array[Node2D]:
	var lista: Array[Node2D] = []
	for filho in raiz.get_children():
		if (filho is Sprite2D or filho is AnimatedSprite2D) and filho.visible:
			lista.append(filho)
		lista.append_array(_sprites_visiveis(filho))
	return lista


func _textura_atual(sprite: Node2D) -> Texture2D:
	if sprite is Sprite2D:
		return sprite.texture
	if sprite is AnimatedSprite2D and sprite.sprite_frames:
		return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return null


func _used_rect(textura: Texture2D) -> Rect2:
	var chave: RID = textura.get_rid()
	if not _used_rect_cache.has(chave):
		var imagem: Image = textura.get_image()
		_used_rect_cache[chave] = Rect2(imagem.get_used_rect()) if imagem else Rect2(Vector2.ZERO, textura.get_size())
	return _used_rect_cache[chave]
