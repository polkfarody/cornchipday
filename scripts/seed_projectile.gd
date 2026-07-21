extends Area2D

# FB11: Tomato power-up's fired seed. Same lifetime/queue_free pattern as
# boss_projectile.gd but hits enemies instead of the player -- any body with
# a take_ranged_hit() method (boss.gd) takes the hit; queue_free()s on any
# solid contact either way, same as boss_projectile.gd, so it doesn't fly
# through walls forever.

const LIFETIME := 2.5

var velocity_x: float = 0.0
var time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_direction(vx: float) -> void:
	velocity_x = vx

func _physics_process(delta: float) -> void:
	position.x += velocity_x * delta
	time_alive += delta
	if time_alive > LIFETIME:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_ranged_hit"):
		body.take_ranged_hit()
	queue_free()
