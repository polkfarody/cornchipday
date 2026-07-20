extends Area2D

# Iron Skillet's arena floor (characters.txt Bestiary by Level, Level 6): an
# escalation of Level 5's IceZone -- instead of a constant movement change,
# this cycles between safe and hot on its own timer, hurting any player
# standing on the ground inside it during the hot phase ("can't stand
# still"). A brief warning flash before the hot phase gives a fair reaction
# window rather than an instant unavoidable hit, matching the game's
# gentle-stakes design philosophy.

@export var safe_duration: float = 4.0
@export var warning_duration: float = 0.8
@export var hot_duration: float = 2.0

@onready var visual: ColorRect = $Visual

var is_hot := false
var already_hit_this_cycle := false
var bodies_inside: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_cycle()

func _on_body_entered(body: Node) -> void:
	bodies_inside.append(body)

func _on_body_exited(body: Node) -> void:
	bodies_inside.erase(body)

func _cycle() -> void:
	is_hot = false
	already_hit_this_cycle = false
	visual.color = Color(1, 0.2, 0, 0)
	await get_tree().create_timer(safe_duration).timeout
	visual.color = Color(1, 0.5, 0, 0.35)
	await get_tree().create_timer(warning_duration).timeout
	is_hot = true
	visual.color = Color(1, 0.15, 0, 0.55)
	await get_tree().create_timer(hot_duration).timeout
	_cycle()

func _physics_process(_delta: float) -> void:
	if not is_hot or already_hit_this_cycle:
		return
	for body in bodies_inside:
		if is_instance_valid(body) and body.has_method("hit_by_obstacle") and body.is_on_floor():
			already_hit_this_cycle = true
			body.hit_by_obstacle()
			break
