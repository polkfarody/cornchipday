extends Area2D

# Air Fryer collectible (feature.md FB10): grants Cornchip the spin-dash
# ability for the rest of the level once picked up.
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("grant_spin_dash"):
		body.grant_spin_dash()
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
