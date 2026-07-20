extends Area2D

# Pairs with rolling_hazard.gd: activates (and resets) the hazard whenever
# the player enters this corridor. Deliberately not one-shot -- walking back
# in after a respawn should always find a fresh chase, not an already-spent
# hazard sitting wherever it stopped last time.

@export var hazard_path: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var hazard := get_node_or_null(hazard_path)
	if hazard and hazard.has_method("activate"):
		hazard.activate()
