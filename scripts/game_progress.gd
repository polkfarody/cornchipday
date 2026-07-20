extends Node

# Phase 4 world map (confirmed 2026-07-20): the project's first autoload --
# nothing before this needed state to survive a scene change (has_double_jump/
# has_spin_dash deliberately don't, see player.gd's comment on that). Level
# unlock progress does, so it lives here instead. In-memory only, resets on
# app restart -- the confirmed scope is "survives scene changes", not a save
# file, so no disk persistence is added here.

const LEVEL_COUNT := 7
const LEVEL_SCENE_PATHS := [
	"res://scenes/Level1.tscn",
	"res://scenes/Level2.tscn",
	"res://scenes/Level3.tscn",
	"res://scenes/Level4.tscn",
	"res://scenes/Level5.tscn",
	"res://scenes/Level6.tscn",
	"res://scenes/Level7.tscn",
]

var highest_unlocked_level := 1
var last_played_level := 1

func unlock_level(level_number: int) -> void:
	highest_unlocked_level = max(highest_unlocked_level, min(level_number, LEVEL_COUNT))

func is_unlocked(level_number: int) -> bool:
	return level_number <= highest_unlocked_level

func level_scene_path(level_number: int) -> String:
	return LEVEL_SCENE_PATHS[level_number - 1]
