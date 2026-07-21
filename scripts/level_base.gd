extends Node2D

# Shared logic for every level, reused via configuration rather than one
# script per level (same pattern as boss.gd being reused across bosses):
#   - The 3-life system: Player emits player_hit on every hit regardless of
#     source, and this is what actually decrements lives and restarts the
#     level at 0 -- Player itself just handles the per-hit stumble/respawn.
#   - Counts the scattered bean tokens (group "bean_token") and shows a
#     collected/total counter in the HUD (FB24), plus adds every collected
#     bean to GameProgress's persisted lifetime total.
#   - Returns to WorldMap.tscn once the level's ingredient is collected
#     (Phase 4 world map, confirmed 2026-07-20 -- previously chained
#     straight into next_level_path; the map is now the hub between every
#     level). Bosses call register_level_ingredient() on whichever node is
#     get_tree().current_scene when they spawn the ingredient, since the
#     ingredient doesn't exist until then and a boss can't assume it'll
#     still be alive by the time the player actually walks over and grabs
#     it a few seconds later.

const MAX_LIVES := 3
const RESTART_DELAY := 0.6
const LEVEL_COMPLETE_DELAY := 1.2
const WORLD_MAP_PATH := "res://scenes/WorldMap.tscn"

# FB29: derived from the level's own "Ground*" StaticBody2D pieces (all
# scenes follow this naming convention -- see boss.gd's own reliance on
# "Ground" prefix for floor-ahead patrol checks) rather than hand-authored
# per level, so it stays correct automatically as levels get edited.
const BOUNDARY_WALL_HEIGHT := 4000.0
const BOUNDARY_MARGIN := 40.0

# FB30: full-run-feedback.txt asked for extra lives to be harder to come by,
# and specifically for one to "drop from the sky" as a comeback chance once
# down to the last life -- rather than only ever sitting in a fixed spot on
# the level's main path. Spawns above wherever the player currently is (the
# rolling checkpoint means that's also roughly where they'll respawn) and
# tweens down to rest on the ground, so it's always somewhere the player can
# actually reach without backtracking.
const SKY_LIFE_DROP_SCENE := preload("res://scenes/LifePickup.tscn")
const SKY_LIFE_DROP_HEIGHT_ABOVE := 500.0
const SKY_LIFE_DROP_FALL_TIME := 0.6

# FB24: built at runtime rather than hand-added to all 7 level scenes, same
# reasoning as the boundary walls above -- one place to change, and it can't
# drift out of sync between levels.
const BEAN_ICON_TEXTURE := preload("res://Assets/generated/items/bean_ingredient.png")

# F44: mobile Web export touch controls -- instanced into $HUD here so every
# level picks it up automatically instead of hand-editing all 7 level
# scenes. Self-removes on non-web builds (see touch_controls.gd).
const TOUCH_CONTROLS_SCENE := preload("res://scenes/TouchControls.tscn")

@export var level_number: int = 0  # 1-7, used to unlock level_number+1 on completion (GameProgress)
@export var grants_double_jump: bool = false  # Level 6+ (characters.txt Bestiary by Level) -- re-granted per level rather than persisted, see player.gd's has_double_jump comment

@onready var player: CharacterBody2D = $Player
@onready var player2: CharacterBody2D = get_node_or_null("Player2")
@onready var life_icons: Array = [$HUD/Life1, $HUD/Life2, $HUD/Life3]

const CO_OP_CAMERA_SCENE_SCRIPT := preload("res://scripts/co_op_camera.gd")

var lives := MAX_LIVES
var bean_tokens_collected := 0
var bean_total := 0
var bean_count_label: Label
var level_complete := false
var level_floor_y := 592.0  # overwritten by _setup_level_bounds() from the level's real ground pieces
var ingredient_checklist_icons: Array = []
var ability_hud_slot: TextureRect = null

func _ready() -> void:
	player.player_hit.connect(_on_player_hit)
	if grants_double_jump:
		player.grant_double_jump()
	if player2:
		# FB6 (2P co-op): shared 3-life pool per the confirmed design -- both
		# players' hits drain the same _on_player_hit counter/HUD rather than
		# each tracking their own. Player2 (Cheeto) shares Cornchip's full
		# moveset, so it gets the same per-level ability grants too.
		player2.player_hit.connect(_on_player_hit)
		if grants_double_jump:
			player2.grant_double_jump()
		_setup_coop_camera()
	bean_total = get_tree().get_nodes_in_group("bean_token").size()
	for token in get_tree().get_nodes_in_group("bean_token"):
		token.collected.connect(_on_bean_token_collected)
	for pickup in get_tree().get_nodes_in_group("life_pickup"):
		pickup.collected.connect(_on_life_pickup_collected)
	_setup_level_bounds()
	_setup_bean_hud()
	_setup_ingredient_checklist()
	$HUD.add_child(TOUCH_CONTROLS_SCENE.instantiate())

func _setup_bean_hud() -> void:
	if bean_total <= 0:
		return
	var hud: CanvasLayer = $HUD
	var icon := TextureRect.new()
	icon.texture = BEAN_ICON_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.offset_left = 20.0
	icon.offset_top = 64.0
	icon.offset_right = 56.0
	icon.offset_bottom = 100.0
	hud.add_child(icon)

	bean_count_label = Label.new()
	bean_count_label.offset_left = 62.0
	bean_count_label.offset_top = 64.0
	bean_count_label.offset_right = 200.0
	bean_count_label.offset_bottom = 100.0
	bean_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bean_count_label.add_theme_font_size_override("font_size", 28)
	bean_count_label.add_theme_color_override("font_color", Color.WHITE)
	bean_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	bean_count_label.add_theme_constant_override("outline_size", 4)
	bean_count_label.text = "0/%d" % bean_total
	hud.add_child(bean_count_label)

# FB26: "when you collect the airfryer it should fly up to the top right and
# a logo for the ability will appear." Lazily created (not every level has
# an ability pickup) and invisible until something actually flies into it --
# any future pickup-granted ability (currently just the Air Fryer's spin
# dash) can reuse this same slot via get_ability_hud_slot() rather than each
# needing its own HUD wiring.
func get_ability_hud_slot(texture: Texture2D) -> TextureRect:
	if ability_hud_slot == null:
		var hud: CanvasLayer = $HUD
		ability_hud_slot = TextureRect.new()
		ability_hud_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ability_hud_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ability_hud_slot.offset_left = 20.0
		ability_hud_slot.offset_top = 108.0
		ability_hud_slot.offset_right = 56.0
		ability_hud_slot.offset_bottom = 144.0
		ability_hud_slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
		hud.add_child(ability_hud_slot)
	ability_hud_slot.texture = texture
	return ability_hud_slot

# FB25: "the ingredient should fly into a shopping basket... something that
# can persist to show what ingredients you have and what you need" -- a row
# of the 6 boss-drop ingredient icons, dimmed until that level's ingredient
# has actually been collected (GameProgress.is_ingredient_collected, derived
# from level-unlock progress). Anchored to the top-right corner (anchor 1.0)
# rather than a hardcoded viewport width, mirroring the top-left life/bean
# HUD but independent of it.
const INGREDIENT_ICON_SIZE := 32.0
const INGREDIENT_ICON_GAP := 4.0
const INGREDIENT_DIMMED_COLOR := Color(0.35, 0.35, 0.35, 0.6)

func _setup_ingredient_checklist() -> void:
	var hud: CanvasLayer = $HUD
	var paths: Array = GameProgress.INGREDIENT_TEXTURE_PATHS
	var slot_width := INGREDIENT_ICON_SIZE + INGREDIENT_ICON_GAP
	var total_width := paths.size() * slot_width
	for i in paths.size():
		var icon := TextureRect.new()
		icon.texture = load(paths[i])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon.anchor_left = 1.0
		icon.anchor_right = 1.0
		var x_start: float = -20.0 - total_width + i * slot_width
		icon.offset_left = x_start
		icon.offset_right = x_start + INGREDIENT_ICON_SIZE
		icon.offset_top = 20.0
		icon.offset_bottom = 20.0 + INGREDIENT_ICON_SIZE
		icon.modulate = Color.WHITE if GameProgress.is_ingredient_collected(i + 1) else INGREDIENT_DIMMED_COLOR
		hud.add_child(icon)
		ingredient_checklist_icons.append(icon)

# Flies a copy of the just-collected ingredient's own sprite from where it
# was picked up in the world to its slot in the checklist above, then lights
# the slot up right as it arrives -- the "fanfare" + "fly into a basket"
# from the raw feedback, in one motion.
func _fly_ingredient_to_hud(ingredient: Node) -> void:
	if level_number <= 0 or level_number > ingredient_checklist_icons.size():
		return
	var target_icon: TextureRect = ingredient_checklist_icons[level_number - 1]
	var icon_sprite: Node = ingredient.get_node_or_null("Sprite")
	if icon_sprite == null:
		return
	var start_screen_pos: Vector2 = get_viewport().get_canvas_transform() * ingredient.global_position
	var target_screen_pos: Vector2 = target_icon.global_position + target_icon.size / 2.0

	var flying := TextureRect.new()
	flying.texture = icon_sprite.texture
	flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flying.size = Vector2(INGREDIENT_ICON_SIZE, INGREDIENT_ICON_SIZE) * 1.5
	flying.pivot_offset = flying.size / 2.0
	flying.position = start_screen_pos - flying.size / 2.0
	$HUD.add_child(flying)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flying, "position", target_screen_pos - flying.size / 2.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(flying, "size", Vector2(INGREDIENT_ICON_SIZE, INGREDIENT_ICON_SIZE), 0.7)
	tween.chain().tween_callback(func():
		target_icon.modulate = Color.WHITE
		flying.queue_free()
	)

# FB29: the player used to be able to walk clean off either end of the
# level. Fixed with physical boundary walls derived from the level's own
# ground pieces, so there's nothing to hand-author per scene.
#
# A Camera2D.limit_left/right/bottom clamp was tried first (also meant to
# cap the pit-fall camera dip), but caused a real regression: this project's
# Camera2D uses a non-default `offset` (Vector2(150, -225), see Player.tscn),
# and Godot's limit clamping interacts with that offset in a way that shifts
# the resting camera position by a large, seemingly non-linear amount on
# BOTH axes even during ordinary standing play, not just at the edges --
# caught via a real rendered screenshot showing the player pushed off the
# top of the screen at the level's own spawn point. Reverted; the walls
# alone (physical, no camera involvement) fully cover "can't walk off the
# level," which is the actual reported problem -- verified via a headless
# screenshot showing normal framing restored.
# FB6 (2P co-op): Player.tscn's own Camera2D is a direct child hardcoded to
# follow just that one CharacterBody2D (see FB29/FB30) -- can't track two
# independent players. When Player2 is present, its camera and Player1's own
# camera are both disabled in favor of one level-owned CoOpCamera (see
# scripts/co_op_camera.gd) tracking both players' midpoint with dynamic zoom.
func _setup_coop_camera() -> void:
	var p1_camera: Camera2D = player.get_node_or_null("Camera2D")
	if p1_camera:
		p1_camera.enabled = false
	var p2_camera: Camera2D = player2.get_node_or_null("Camera2D")
	if p2_camera:
		p2_camera.enabled = false

	var coop_camera := Camera2D.new()
	coop_camera.set_script(CO_OP_CAMERA_SCENE_SCRIPT)
	coop_camera.target_a = player
	coop_camera.target_b = player2
	coop_camera.position_smoothing_enabled = false  # co_op_camera.gd already lerps position itself
	add_child(coop_camera)
	coop_camera.enabled = true

func _setup_level_bounds() -> void:
	var min_left := INF
	var max_right := -INF
	var max_floor_y := -INF
	for child in get_children():
		if not (child is StaticBody2D and child.name.begins_with("Ground")):
			continue
		for sub in child.get_children():
			if sub is CollisionShape2D and sub.shape is RectangleShape2D:
				var shape: RectangleShape2D = sub.shape
				var center_x: float = child.position.x + sub.position.x
				var center_y: float = child.position.y + sub.position.y
				min_left = min(min_left, center_x - shape.size.x / 2.0)
				max_right = max(max_right, center_x + shape.size.x / 2.0)
				max_floor_y = max(max_floor_y, center_y - shape.size.y / 2.0)
	if min_left == INF:
		return

	level_floor_y = max_floor_y

	_add_boundary_wall(min_left - BOUNDARY_MARGIN, "BoundaryWallLeft")
	_add_boundary_wall(max_right + BOUNDARY_MARGIN, "BoundaryWallRight")

func _add_boundary_wall(x: float, wall_name: String) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, BOUNDARY_WALL_HEIGHT)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(x, 0.0)
	add_child(wall)

func _on_player_hit() -> void:
	if level_complete:
		return
	lives -= 1
	if lives >= 0 and lives < life_icons.size():
		life_icons[lives].visible = false
	if lives == 1:
		_spawn_sky_life_drop()
	if lives <= 0:
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()

func _spawn_sky_life_drop() -> void:
	var pickup: Area2D = SKY_LIFE_DROP_SCENE.instantiate()
	pickup.collected.connect(_on_life_pickup_collected)
	# Deferred as one unit (add_child + position + tween): this can run from
	# inside an enemy's own Area2D body_entered callback (touch ->
	# hit_by_obstacle -> _on_player_hit -> here), and Godot's physics server
	# rejects adding a new collision shape while still flushing that query
	# -- caught via headless test ("Can't change this state while flushing
	# queries"). Splitting add_child from the position/tween setup risked a
	# timing mismatch, so the whole thing waits together.
	_finish_sky_life_drop.call_deferred(pickup)

func _finish_sky_life_drop(pickup: Area2D) -> void:
	add_child(pickup)
	var target_y := level_floor_y - 20.0
	pickup.position = Vector2(player.global_position.x, target_y - SKY_LIFE_DROP_HEIGHT_ABOVE)
	var tween := create_tween()
	tween.tween_property(pickup, "position:y", target_y, SKY_LIFE_DROP_FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_bean_token_collected() -> void:
	bean_tokens_collected += 1
	GameProgress.add_beans(1)
	if bean_count_label:
		bean_count_label.text = "%d/%d" % [bean_tokens_collected, bean_total]

# Extra-life pickup (feature.md backlog, direct user request): capped at
# MAX_LIVES so the icon-only HUD never needs a 4th slot or a number. Reveals
# the icon this exact life level corresponds to, mirroring how
# _on_player_hit hides icons by index.
func _on_life_pickup_collected() -> void:
	if lives >= MAX_LIVES:
		return
	if lives < life_icons.size():
		life_icons[lives].visible = true
	lives += 1

func register_level_ingredient(ingredient: Node) -> void:
	ingredient.collected.connect(_on_level_ingredient_collected.bind(ingredient))

func _on_level_ingredient_collected(ingredient: Node = null) -> void:
	if level_complete:
		return
	level_complete = true
	AudioManager.play("level_complete")
	if ingredient:
		_fly_ingredient_to_hud(ingredient)
	if level_number > 0:
		GameProgress.unlock_level(level_number + 1)
		GameProgress.last_played_level = level_number
	await get_tree().create_timer(LEVEL_COMPLETE_DELAY).timeout
	get_tree().change_scene_to_file(WORLD_MAP_PATH)
