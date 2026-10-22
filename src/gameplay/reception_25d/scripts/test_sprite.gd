extends Sprite3D

@export var source_texture: Texture2D


func _ready() -> void:
	# A separate runtime texture avoids Godot's automatic 3D reimport of the 2D asset.
	if source_texture != null:
		var image := source_texture.get_image()
		texture = ImageTexture.create_from_image(image)
		var visible_pixels := image.get_used_rect()
		if visible_pixels.has_area():
			# The parent is the floor anchor. Align the visible bottom, not the PNG edge.
			position.y = (visible_pixels.end.y - image.get_height() * 0.5) * pixel_size * scale.y
