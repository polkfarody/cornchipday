extends Area2D

# Sour Cream Sam's arena floor (characters.txt Bestiary by Level, Level 5):
# a plain region trigger, not a hazard -- toggles the player's is_on_ice
# state on entry/exit rather than costing a life or stunning. Reusable for
# any future "arena floor changes movement" boss (e.g. Level 6's heating
# floor) by just placing another instance over that arena.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_on_ice"):
		body.set_on_ice(true)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_on_ice"):
		body.set_on_ice(false)
