extends AudioStreamPlayer


func play_if_stopped() -> void:
	if not playing:
		play()


func stop_music() -> void:
	stop()
