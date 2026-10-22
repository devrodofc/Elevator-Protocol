extends Node
## Áudio global (autoload "Audio"): música do gameplay (bus Music) e efeitos sonoros (bus SFX).
##   Audio.play_sfx(Audio.SUCESSO)
##   Audio.play_music(Audio.MUSICA_GAMEPLAY)   # não reinicia se já estiver tocando a mesma
##   Audio.start_loop(Audio.DIGITANDO) / Audio.stop_loop()
## A música do menu continua no autoload MusicMenu, mas o volume dela é definido aqui (MENU_MUSIC_VOLUME_DB).
##
## Volumes: ao abrir o jogo, os buses começam em DEFAULT_BUS_PERCENT (o que os sliders das opções
## mostram; Music = 50%). Os *_VOLUME_DB abaixo são em dB (não em %) e equilibram os arquivos entre si.

const BOTAO := preload("res://sounds/sfx/BotãoPressionado.mp3")
const CHEGOU_ELEVADOR := preload("res://sounds/sfx/chegou_elevador.mp3")
const DIGITANDO := preload("res://sounds/sfx/digitando.mp3")
const ERRO := preload("res://sounds/sfx/erro.mp3")
const SUCESSO := preload("res://sounds/sfx/sucess.mp3")
const PASSANDO_PAGINA := preload("res://sounds/sfx/passando_pagina.mp3")
const MUSICA_GAMEPLAY := preload("res://sounds/music/musica_gameplay.mp3")
const MUSICA_ERRADA := preload("res://sounds/music/musica_errada.mp3")

## Volume inicial de cada bus, em % (0 a 100), igual aos sliders das opções. 50% = -6 dB.
const DEFAULT_BUS_PERCENT := {&"Master": 100.0, &"Music": 50.0, &"SFX": 100.0}

## Volumes de cada player, em dB (0 = volume do arquivo; não passar de ~+6).
## Medido: menu a -6 dB e gameplay a 0 dB (com o limitador) ficam iguais, ~-19,5 dBFS de média;
## com o slider de música em 50% ficam em ~-25,5 dBFS.
const MENU_MUSIC_VOLUME_DB: float = -6.0
const MUSIC_VOLUME_DB: float = 0.0
const SFX_VOLUME_DB: float = 2.2
const LOOP_VOLUME_DB: float = 2.2
## Chegada comum do elevador: 50% da amplitude (-6 dB). Quando é a Marta: volume normal e mais grave.
const ELEVADOR_VOLUME_DB: float = -6.0
const ELEVADOR_MARTA_PITCH: float = 0.7
## Quantos efeitos podem tocar ao mesmo tempo
const SFX_VOICES: int = 6

## A música do gameplay veio ~17 dB mais baixa que a do menu (média -30,7 dBFS, pico -6,7 dBFS):
## subir só o volume_db estoura nos picos. Ela passa por um bus próprio com limitador, que sobe o volume
## (MUSIC_BOOST_DB) e segura os picos no teto (MUSIC_CEILING_DB). O bus manda para o "Music", então o
## slider de música das opções continua valendo; a música do menu não passa por aqui.
## Acima de ~15 dB o limitador só achata (18 dB rende +1 dB de média).
const MUSIC_BUS := &"MusicaGameplay"
const MUSIC_BOOST_DB: float = 15.0
const MUSIC_CEILING_DB: float = -1.0

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
	_apply_default_volumes()
	# O MusicMenu é carregado antes (ordem dos autoloads) e já está tocando
	var menu_music := get_node_or_null("/root/MusicMenu") as AudioStreamPlayer
	if menu_music:
		menu_music.volume_db = MENU_MUSIC_VOLUME_DB
	_create_music_bus()
	_music = _new_player(MUSIC_BUS, MUSIC_VOLUME_DB)
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


## Só na abertura do jogo: depois quem manda são os sliders das opções (o volume não é salvo).
func _apply_default_volumes() -> void:
	for bus_name in DEFAULT_BUS_PERCENT:
		var bus: int = AudioServer.get_bus_index(bus_name)
		if bus == -1:
			push_warning("Bus de áudio não encontrado: " + bus_name)
			continue
		var percent: float = DEFAULT_BUS_PERCENT[bus_name]
		AudioServer.set_bus_mute(bus, percent <= 0.0)
		AudioServer.set_bus_volume_linear(bus, maxf(percent, 0.0) / 100.0)


## Bus da música do gameplay com o limitador (criado em código para não mexer no default_bus_layout.tres).
func _create_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, MUSIC_BUS)
	AudioServer.set_bus_send(bus, &"Music")
	var limiter := AudioEffectHardLimiter.new()
	limiter.pre_gain_db = MUSIC_BOOST_DB
	limiter.ceiling_db = MUSIC_CEILING_DB
	AudioServer.add_bus_effect(bus, limiter)


func _new_player(bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	return player
