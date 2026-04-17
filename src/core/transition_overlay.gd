## Controls the fade-to-black transition overlay.
## Attached to UILayer/TransitionOverlay (ColorRect).
## Source: ADR-0003
class_name TransitionOverlay
extends ColorRect


## Fades to black (alpha 1.0) over the specified duration in seconds.
func fade_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration)
	await tween.finished


## Fades from black to transparent (alpha 0.0) over the specified duration in seconds.
func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
