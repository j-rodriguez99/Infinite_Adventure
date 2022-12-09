extends CanvasLayer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().get_root().connect("size_changed", self, "_size_changed")
	_load_foreground()
	
func _load_foreground():
	var size = get_viewport().get_visible_rect().size
	$ColorRect.set_size(size)
	
func _size_changed():
	_load_foreground()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$ColorRect.material.set_shader_param('offset', GameState.player.position)
