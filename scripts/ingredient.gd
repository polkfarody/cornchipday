extends Area2D

# Generic collectible pickup: a purely visual celebration on touch -- no
# text, per the no-reading-required design pillar. Used by Ingredient.tscn
# (the level's boss-dropped ingredient) and reused as-is by BeanToken.tscn
# (the scattered collectible currency, see additions.txt -- beans, not
# lettuce, are the main token; lettuce stays an ingredient only).
signal collected

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	set_deferred("monitoring", false)
	collected.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
