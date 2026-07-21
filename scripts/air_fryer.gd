extends Area2D

# Air Fryer collectible (feature.md FB10): grants Cornchip the spin-dash
# ability for the rest of the level once picked up.
#
# FB26: on pickup, flies up to a persistent HUD slot (level_base.gd's
# get_ability_hud_slot()) instead of just fading out in place -- "it should
# fly up to the top right and a logo for the ability will appear," so the
# player has a lasting on-screen reminder the ability is active.
const FLY_ICON_SIZE := Vector2(48.0, 48.0)
const SLOT_ICON_SIZE := Vector2(36.0, 36.0)
const FLY_DURATION := 0.6

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("grant_spin_dash"):
		body.grant_spin_dash()
	set_deferred("monitoring", false)
	_fly_to_hud()

func _fly_to_hud() -> void:
	var level := get_tree().current_scene
	if not level.has_method("get_ability_hud_slot"):
		queue_free()
		return
	var slot: TextureRect = level.get_ability_hud_slot(sprite.texture)
	var start_screen_pos: Vector2 = get_viewport().get_canvas_transform() * global_position
	var target_screen_pos: Vector2 = slot.global_position + slot.size / 2.0

	var flying := TextureRect.new()
	flying.texture = sprite.texture
	flying.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flying.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flying.size = FLY_ICON_SIZE
	flying.pivot_offset = flying.size / 2.0
	flying.position = start_screen_pos - flying.size / 2.0
	level.get_node("HUD").add_child(flying)

	# Bound to `flying` (not self) since self is freed right below -- a tween
	# created on a node is stopped early if that node leaves the tree before
	# the tween finishes (caught via headless test: the slot never lit up).
	var tween := flying.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flying, "position", target_screen_pos - SLOT_ICON_SIZE / 2.0, FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(flying, "size", SLOT_ICON_SIZE, FLY_DURATION)
	tween.chain().tween_callback(func():
		slot.modulate = Color.WHITE
		flying.queue_free()
	)
	queue_free()
