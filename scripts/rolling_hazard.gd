extends Area2D

# Level 7 new content (Phase 4, "timing/chase" flavor, confirmed
# 2026-07-20): a non-combat chase hazard -- no attack pattern, just a steady
# rightward push faster than the player's own run speed (220), so standing
# still or backtracking risks getting caught. A normal hit on contact
# (1 life via hit_by_obstacle), the same consequence as any other hazard --
# no new fail-state paradigm. Reactivated and reset to its start position by
# ChaseTrigger every time the player enters the corridor (see
# chase_trigger.gd), so a respawn after getting caught still finds a real
# chase waiting rather than a hazard that already used itself up.

@export var speed: float = 260.0
@export var travel_limit: float = 500.0

var is_active := false
var start_x: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	start_x = position.x

func activate() -> void:
	position.x = start_x
	is_active = true

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	position.x += speed * delta
	if position.x - start_x > travel_limit:
		is_active = false

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit_by_obstacle"):
		body.hit_by_obstacle()
