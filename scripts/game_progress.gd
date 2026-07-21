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

# FB25: the "shopping basket" ingredient checklist (level_base.gd) needs to
# know which of the 6 boss-dropped ingredients have been collected so far.
# That's fully derivable from highest_unlocked_level (levels below the
# current frontier are, by construction, already beaten -- unlock_level(N+1)
# only ever fires from collecting level N's ingredient) rather than tracked
# as separate state that could drift out of sync with it.
const INGREDIENT_TEXTURE_PATHS := [
	"res://Assets/generated/items/lettuce_ingredient.png",
	"res://Assets/generated/items/cheese_ingredient.png",
	"res://Assets/generated/items/guac_ingredient.png",
	"res://Assets/generated/items/tomato_ingredient.png",
	"res://Assets/generated/items/sour_cream_ingredient.png",
	"res://Assets/generated/items/crunchy_shell_ingredient.png",
]

func is_ingredient_collected(level_number: int) -> bool:
	return level_number < highest_unlocked_level

# FB24: unlike highest_unlocked_level/last_played_level above (deliberately
# in-memory only, see this file's header comment), the bean total is a
# genuine cross-session high score -- saved to disk on every change and
# loaded once at startup, since "beans ever collected" should keep climbing
# across separate play sessions rather than resetting with the app.
const SAVE_PATH := "user://progress.save"

var total_beans_collected := 0

func _ready() -> void:
	_load_beans()

func add_beans(amount: int) -> void:
	total_beans_collected += amount
	_save_beans()

func _save_beans() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({"total_beans_collected": total_beans_collected})

func _load_beans() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = file.get_var()
	if typeof(data) == TYPE_DICTIONARY and data.has("total_beans_collected"):
		total_beans_collected = data["total_beans_collected"]

func unlock_level(level_number: int) -> void:
	highest_unlocked_level = max(highest_unlocked_level, min(level_number, LEVEL_COUNT))

func is_unlocked(level_number: int) -> bool:
	return level_number <= highest_unlocked_level

func level_scene_path(level_number: int) -> String:
	return LEVEL_SCENE_PATHS[level_number - 1]
