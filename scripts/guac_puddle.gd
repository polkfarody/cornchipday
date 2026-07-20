extends Area2D

# Avocado's dance-jump attack (characters.txt Bestiary by Level, Level 3):
# a terrain hazard dropped at his feet rather than a projectile aimed at the
# player. Sits in place and stuns on touch, same as any obstacle, then
# queues itself free after a lifetime so puddles from a long fight don't
# keep accumulating on the arena floor forever.
const LIFETIME := 4.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit_by_obstacle"):
		body.hit_by_obstacle()
