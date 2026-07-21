extends Area2D

# FB33: L2 climbing bonus section. Toggles the player's climb-grab
# availability on enter/exit -- see player.gd's set_in_climb_zone() for the
# actual grab/release rules (must press up/down to actually grab, not just
# overlap the zone).
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_in_climb_zone"):
		body.set_in_climb_zone(true)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_in_climb_zone"):
		body.set_in_climb_zone(false)
