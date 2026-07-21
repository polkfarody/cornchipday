extends Area2D

# FB11: Tomato power-up collectible -- grants Cornchip a temporary ranged
# seed attack. Separate from TomatoIngredient.tscn (Level 4's boss-drop
# ingredient); this is a standalone timed ability pickup.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("grant_tomato_power"):
		body.grant_tomato_power()
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
