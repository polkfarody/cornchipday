extends Node

# FB5 (partial): centralized SFX playback -- an autoload (the project's
# second, after GameProgress) rather than an AudioStreamPlayer hand-added to
# every scene, so any script can just call AudioManager.play("jump") without
# needing a node reference wired through. A small player pool avoids two
# overlapping sounds (e.g. two beans grabbed in the same frame) cutting each
# other off.

const SFX := {
	"jump": preload("res://Assets/generated/audio/jump.tres"),
	"bean_collect": preload("res://Assets/generated/audio/bean_collect.tres"),
	"hit": preload("res://Assets/generated/audio/hit.tres"),
	"life_pickup": preload("res://Assets/generated/audio/life_pickup.tres"),
	"level_complete": preload("res://Assets/generated/audio/level_complete.tres"),
}

const POOL_SIZE := 6

var _players: Array = []

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(sfx_name: String) -> void:
	if not SFX.has(sfx_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = SFX[sfx_name]
			p.play()
			return
	_players[0].stream = SFX[sfx_name]
	_players[0].play()
