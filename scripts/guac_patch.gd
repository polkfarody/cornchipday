extends Area2D

# Level 7 remix segment (Phase 4, "environmental combo" flavor, confirmed
# 2026-07-20): a sticky-footing zone placed right after an ice patch so the
# player has to handle opposite traction extremes back to back -- a
# combination no single level uses on its own. Toggles player.gd's
# is_on_guac the same way ice_zone.gd toggles is_on_ice, rather than costing
# a life like guac_puddle.gd's boss-dropped hazard does.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_on_guac"):
		body.set_on_guac(true)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_on_guac"):
		body.set_on_guac(false)
