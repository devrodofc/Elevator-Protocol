extends Node
## Áudio global (autoload "Audio"): música do gameplay (bus Music) e efeitos sonoros (bus SFX).
##   Audio.play_sfx(Audio.SUCESSO)
##   Audio.play_music(Audio.MUSICA_GAMEPLAY)   # não reinicia se já estiver tocando a mesma
##   Audio.start_loop(Audio.DIGITANDO) / Audio.stop_loop()
## A música do menu continua no autoload MusicMenu.

const BOTAO := preload("res://sounds/music/wav/BotãoPressionado.mp3")
const CHEGOU_ELEVADOR := preload("res://sounds/music/wav/chegou_elevador.mp3")
const DIGITANDO := preload("res://sounds/music/wav/digitando.mp3")
const ERRO := preload("res://sounds/music/wav/erro.mp3")
const SUCESSO := preload("res://sounds/music/wav/sucess.mp3")
const PASSANDO_PAGINA := preload("res://sounds/music/wav/passando_pagina.mp3")
const MUSICA_GAMEPLAY := preload("res://sounds/music/wav/musica_gameplay.mp3")
const MUSICA_ERRADA := preload("res://sounds/music/wav/musica_errada.mp3")

## Volumes (dB). A música do menu está em -33 dB no MusicMenu.
const MUSIC_VOLUME_DB: float = -20.0
const SFX_VOLUME_DB: float = -6.0
const LOOP_VOLUME_DB: float = -10.0
## Chegada comum do elevador: 50% da amplitude (-6 dB). Quando é a Marta: volume normal e mais grave.
const ELEVADOR_VOLUME_DB: float = -6.0
const ELEVADOR_MARTA_PITCH: float = 0.7
## Quantos efeitos podem tocar ao mesmo tempo
const SFX_VOICES: int = 6

var _music: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _music_fade: Tween


func _ready() -> void:
	# Continua tocando com o jogo pausado (menu de pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Os MP3 foram importados sem loop: música e "digitando" repetem
	for stream in [MUSICA_GAMEPLAY, MUSICA_ERRADA, DIGITANDO]:
		stream.loop = true
	_music = _new_player(&"Music", MUSIC_VOLUME_DB)
	_loop = _new_player(&"SFX", LOOP_VOLUME_DB)
	for i in SFX_VOICES:
		_sfx.append(_new_player(&"SFX", SFX_VOLUME_DB))


## volume_db é somado ao volume padrão dos efeitos; pitch < 1 deixa o som mais grave (e mais lento).
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	player.stream = stream
	player.volume_db = SFX_VOLUME_DB + volume_db
	player.pitch_scale = pitch
	player.play()


func play_music(stream: AudioStream) -> void:
	if _music.stream == stream and _music.playing:
		return
	_kill_music_fade()
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_kill_music_fade()
	_music.stop()
	_music.stream = null


## Abaixa a música até sumir e para (o próximo play_music recomeça no volume normal).
func fade_out_music(seconds: float) -> void:
	if not _music.playing:
		return
	_kill_music_fade()
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", -60.0, seconds).set_ease(Tween.EASE_IN)
	_music_fade.tween_callback(_music.stop)
	_music_fade.tween_callback(func(): _music.volume_db = MUSIC_VOLUME_DB)


func _kill_music_fade() -> void:
	if _music_fade:
		_music_fade.kill()
		_music_fade = null
	_music.volume_db = MUSIC_VOLUME_DB


func start_loop(stream: AudioStream) -> void:
	if _loop.stream == stream and _loop.playing:
		return
	_loop.stream = stream
	_loop.play()


func stop_loop() -> void:
	_loop.stop()


func _new_player(bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	return player
