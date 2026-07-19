extends Area2D

# The "mild salsa" Wrap throws at Cornchip (game-brief.txt). Falls straight
# down across the player's path; on contact it stuns rather than harms.
const FALL_SPEED := 260.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.y += FALL_SPEED * delta
	if position.y > 900:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit_by_obstacle"):
		body.hit_by_obstacle()
	queue_free()
