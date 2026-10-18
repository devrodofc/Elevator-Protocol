extends RefCounted

# Estado compartilhado apenas durante a sessão, como o fullscreen anterior.
static var _windowed_size := Vector2i.ZERO
static var _changing := false


static func current_text() -> String:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or \
		mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return "TELA CHEIA"
	return "JANELA"


static func cycle(tree: SceneTree) -> void:
	if _changing:
		return
	_changing = true
	var current := current_text()
	if current == "JANELA":
		_windowed_size = DisplayServer.window_get_size()
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if _windowed_size == Vector2i.ZERO:
			_windowed_size = Vector2i(
				ProjectSettings.get_setting("display/window/size/window_width_override", 640),
				ProjectSettings.get_setting("display/window/size/window_height_override", 360)
			)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Permite ao gerenciador de janelas sair do fullscreen antes de redimensionar.
		# O timer também avança com o jogo pausado (process_always = true).
		await tree.create_timer(0.1, true).timeout
		var screen := DisplayServer.window_get_current_screen()
		var usable := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		var size := _windowed_size.min(usable.size)
		DisplayServer.window_set_size(size)
		await tree.process_frame
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
	_changing = false
