class_name ParkingPanicAudio
extends Node

func move_sound(move_index: int) -> void:
	_play_tone(500.0 + float(move_index % 5) * 35.0, 0.045, 0.08)

func blocked_sound() -> void:
	_play_tone(170.0, 0.055, 0.07)

func undo_sound() -> void:
	_play_tone(390.0, 0.045, 0.08)

func play_win_chime() -> void:
	_play_tone(660.0, 0.08, 0.10)
	await get_tree().create_timer(0.075).timeout
	_play_tone(880.0, 0.09, 0.11)
	await get_tree().create_timer(0.075).timeout
	_play_tone(1174.0, 0.14, 0.12)

func _play_tone(freq: float, duration: float, volume: float) -> void:
	var player := AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.15
	player.stream = generator
	player.volume_db = linear_to_db(clamp(volume, 0.01, 1.0))
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
	var frames := int(generator.mix_rate * duration)
	for i in range(frames):
		var envelope := 1.0 - float(i) / float(max(1, frames))
		var sample := sin(TAU * freq * float(i) / generator.mix_rate) * envelope * 0.38
		playback.push_frame(Vector2(sample, sample))
	_free_audio_later(player, duration + 0.10)

func _free_audio_later(player: AudioStreamPlayer, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(player):
		player.queue_free()
