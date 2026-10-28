class_name GameOverPanel
extends RefCounted
## The end of a game (win, loss or draw), over the table: the result and what to do next.
## `actions` holds the callables {home, restart, new_game}. The × closes it to look at the final
## position; the game menu still has "Reiniciar partida" and "Nova partida". Returns the panel's
## layer (free it to close).

static func open(parent: Node, title: String, reason: String, actions: Dictionary) -> CanvasLayer:
	var m := UiTheme.modal(parent, 5, 880)
	var layer: CanvasLayer = m.layer
	var box: VBoxContainer = m.box
	var close := func() -> void: layer.queue_free()

	var head := HBoxContainer.new()
	box.add_child(head)
	var heading := UiTheme.label(title, "Title")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var x := UiTheme.button("×", "GhostButton", 56, 84)
	x.custom_minimum_size.x = 84
	x.pressed.connect(close)
	head.add_child(x)
	if reason != "":
		box.add_child(UiTheme.label(reason.to_upper(), "Caption"))

	for item: Array in [["Reiniciar partida", "PrimaryButton", actions.restart],
			["Nova partida", "", actions.new_game], ["Menu inicial", "GhostButton", actions.home]]:
		var b := UiTheme.button(item[0], item[1], 42, 108)
		var action: Callable = item[2]
		b.pressed.connect(func() -> void:
			close.call()
			action.call())
		box.add_child(b)
	return layer
