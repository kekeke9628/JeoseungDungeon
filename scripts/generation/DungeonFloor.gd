extends Node2D
## Visual root for one dungeon floor. Forwards the grid to the renderer and
## redraws when DungeonState reports ground loot changes.

@onready var renderer: Node2D = $DungeonRenderer

func _ready() -> void:
	DungeonState.changed.connect(_on_state_changed)

func _exit_tree() -> void:
	if DungeonState.changed.is_connected(_on_state_changed):
		DungeonState.changed.disconnect(_on_state_changed)

func render(grid: Dictionary, width: int, height: int) -> void:
	renderer.set_grid(grid, width, height)

func _on_state_changed() -> void:
	renderer.queue_redraw()
