extends Area2D

# Generic collectible pickup: a purely visual celebration on touch -- no
# text, per the no-reading-required design pillar. Used by Ingredient.tscn
# (the level's boss-dropped ingredient) and reused as-is by BeanToken.tscn
# (the scattered collectible currency, see additions.txt -- beans, not
# lettuce, are the main token; lettuce stays an ingredient only).
signal collected

# Level 7 finale delivery ritual (Phase 4, confirmed 2026-07-20): set true
# only on Level7.tscn's 6 wrap_delivery instances. Instead of instantly
# collecting on touch, the item is picked up and follows the player
# (player.gd's start_carrying()) until actually delivered to Wrap -- see
# deliver() below, called by wrap.gd. Reusing this shared script via a flag
# (rather than a dedicated scene per delivery item) keeps every delivery
# item's existing unique visual (Sprite/Blob children) untouched.
@export var carry_to_wrap: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if carry_to_wrap:
		if not body.has_method("start_carrying") or not body.start_carrying(self):
			return
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		return
	set_deferred("monitoring", false)
	collected.emit()
	_play_collect_tween()

func _play_collect_tween() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

# Called by WrapBoss once this specific carried item is actually delivered
# (jumped onto Wrap while carrying it) -- the carry_to_wrap equivalent of the
# instant on-touch collect above.
func deliver() -> void:
	collected.emit()
	_play_collect_tween()
