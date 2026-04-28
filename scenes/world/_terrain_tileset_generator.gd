## Genera ImageTexture con tiles de terreno (16x16 cada uno)
## Usa ruido para dar variación entre tiles del mismo tipo

extends Node2D


static func create_terrain_atlas() -> Image:
	# 5 tiles de 16x16 en fila horizontal: 80x16
	var img = Image.create(80, 16, false, Image.FORMAT_RGBA8)

	var colors = {
		# GRASS (tile 0, x: 0-15)
		0: Color(0.3, 0.7, 0.3),
		# WATER (tile 1, x: 16-31)
		1: Color(0.2, 0.4, 0.8),
		# MOUNTAIN (tile 2, x: 32-47)
		2: Color(0.5, 0.5, 0.5),
		# SAND (tile 3, x: 48-63)
		3: Color(0.9, 0.8, 0.5),
		# FOREST (tile 4, x: 64-79)
		4: Color(0.2, 0.5, 0.2),
	}

	var noise = FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.5

	for tile_idx in range(5):
		var base_color: Color = colors[tile_idx]
		var tile_origin_x: int = tile_idx * 16

		for px in range(16):
			for py in range(16):
				var nx: float = noise.get_noise_2d(px + tile_idx * 100, py) * 0.1
				var c = base_color.darkened(nx)

				# Forest: añadir pequeños puntos más oscuros como árboles
				if tile_idx == 4:
					if noise.get_noise_2d(px * 2, py * 2) > 0.3:
						c = Color(0.1, 0.35, 0.1)

				# Mountain: textura más rugosa
				if tile_idx == 2:
					var ridge = abs(noise.get_noise_2d(px * 3, py * 3))
					c = Color(0.4 + ridge * 0.2, 0.4 + ridge * 0.2, 0.35 + ridge * 0.15)

				img.set_pixel(tile_origin_x + px, py, c)

	return img


static func create_atlas_texture(img: Image) -> AtlasTexture:
	var tex = ImageTexture.create_from_image(img)
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	return atlas


static func get_tile_rect(tile_index: int) -> Rect2:
	return Rect2(tile_index * 16, 0, 16, 16)
