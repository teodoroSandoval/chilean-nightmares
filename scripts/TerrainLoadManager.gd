@tool
extends Terrain3D
class_name TerrainLoadManager

## Node whose children mark where each terrain tile should be placed (e.g. the
## imported reference meshes under "References" in Gameplay.tscn).
@export var reference_terrains_base: Node3D

## Folder containing "<tile_name><heightmap_file_suffix>" 16-bit raw heightmaps.
@export var terrain_level_letter: String = "A"
@export var raw_heightmap_folder_path: String = "res://terrains/Level %s/Heightmaps"
@export var heightmap_file_suffix: String = "_height.raw"

## Folder containing "<tile_name><texture_file_suffix>" satellite/color textures.
@export var terrain_texture_folder_path: String = "res://terrains/Level %s/Textures"
@export var terrain_texture_file_suffix: String = ".png"

## Applied to the normalized (0-1) raw heightmap samples on import.
@export var height_scale: float = 150.0
@export var height_offset: float = 0.0
@export var max_operations: int = 10
@export var color_pallette: Array[Color] = []
@export var terrain_layer_index: Array[int] = []
@export var completed_nodes: Array[Node3D] = []

@export_tool_button("Clear Terrains") var clear_terrains_action: Callable = clear_terrains
@export_tool_button("Verify Terrains Existence") var verify_terrains_existence_action: Callable = verify_terrains_existence
@export_tool_button("Refresh Terrains Heightmap") var refresh_terrains_heightmap_action: Callable = refresh_terrains_heightmap
@export_tool_button("Refresh Terrains Texture") var refresh_terrains_texture_action: Callable = refresh_terrains_texture
@export_tool_button("Verify Terrains Data Saved") var verify_terrains_data_is_saved_to_disk_action: Callable = verify_terrains_data_is_saved_to_disk

func clear_terrains() -> void:
	# if reference_terrains_base == null:
	# 	push_error("Reference terrains base is not assigned.")
	# 	return
	# assets.clear_textures()
	# for region in data.get_regions_all():
	# 	data.remove_regionl(region)
	
	# data.height_maps.clear()
	# data.force_update()
	# data.update_maps(Terrain3DRegion.TYPE_HEIGHT);
	pass

## Reports, for every reference tile, whether a Terrain3D region already exists at its position.
## Regions are not created here: Terrain3DRegion.new() has empty maps, and add_region()
## crashes on those. Use "Refresh Terrains Heightmap"/"Refresh Terrains Texture" to create
## missing regions, since import_images() initializes them safely.

func verify_terrains_existence() -> void:
	if reference_terrains_base == null:
		push_error("Reference terrains base is not assigned.")
		return

	var all_terrains_exist := true
	for reference_terrain in reference_terrains_base.get_children():
		if not reference_terrain is Node3D:
			continue

		var world_position: Vector3 = get_rounded_terrain_position(reference_terrain.global_position)

		if data.has_regionp(world_position):
			print("Terrain region for '%s' exists at %s." % [reference_terrain.name, world_position])
		else:
			# all_terrains_exist = false
			data.add_region_blankp(world_position)
			print("adding base region")
			# push_warning("Terrain region for '%s' was not found at %s. Run 'Refresh Terrains Heightmap' to create it." % [reference_terrain.name, world_position])

	if all_terrains_exist:
		print("All reference terrains have a matching region.")

## Snaps a reference tile's world position to the region grid.
func get_rounded_terrain_position(world_position_center: Vector3) -> Vector3:
	var tile_size: float = get_region_size() * get_vertex_spacing()
	return Vector3(
		int(roundf((world_position_center.x - (tile_size * 0.5)) / tile_size)) * tile_size,
		0,
		int(roundf((world_position_center.z - (tile_size * 0.5)) / tile_size)) * tile_size
	)


## Loads each tile's raw 16-bit heightmap and imports it into the matching region.
func refresh_terrains_heightmap() -> void:
	if reference_terrains_base == null:
		push_error("Reference terrains base is not assigned.")
		return

	# TODO: clear terrain first
	# clear_entire_terrain()

	var operations_count: int = 0

	for reference_terrain in reference_terrains_base.get_children():
		if not reference_terrain is Node3D:
			continue
		# if reference_terrain.name != "EXPORT_GOOGLE_SAT_WM_010":
		# 	continue

		var tile_name: String = reference_terrain.name
		tile_name = tile_name.replace("EXPORT_GOOGLE_SAT_WM_", "EXPORT_GOOGLE_SAT_WM.")
		var raw_heightmap_folder_path_final: String = (raw_heightmap_folder_path % terrain_level_letter)
		var raw_path: String = raw_heightmap_folder_path_final.path_join(tile_name + heightmap_file_suffix)

		if not FileAccess.file_exists(raw_path):
			push_warning("Heightmap file not found for terrain '%s': %s" % [tile_name, raw_path])
			continue

		var height_image: Image = load_raw_heightmap(raw_path)
		if height_image == null:
			push_error("Failed to load heightmap for terrain '%s' from '%s'." % [tile_name, raw_path])
			continue

		var world_position_center: Vector3 = get_rounded_terrain_position(reference_terrain.global_position)
		data.import_images([height_image, null, null], world_position_center, height_offset, height_scale)
		
		operations_count += 1
		if operations_count >= max_operations:
			print("Reached maximum number of operations (%d)." % max_operations)
			break
		# var currentRegion: Terrain3DRegion = data.get_regionp(world_position_center)
		# if currentRegion != null:
			# print(currentRegion.vertex_spacing)
			# currentRegion.vertex_spacing = get_vertex_spacing()
			# currentRegion.set_map(Terrain3DRegion.TYPE_HEIGHT, height_image)
			# data.set_control_scale(global_position, get_vertex_spacing())
			# print(get_vertex_spacing())
			# data.add_region_blankp(world_position_center)

			# print(currentRegion)
			# data.set_control_scale(world_position_center, get_vertex_spacing())
			# data.set_control_scale(world_position_center, get_vertex_spacing())
		# 	print("Applied heightmap for terrain '%s'." % tile_name)
		# else:
		# 	print("Missing region for terrain '%s'." % tile_name)
	data.update_maps() 

func clear_entire_terrain() -> void:
	# Completely purges all regions and resets the data structure
	# data.get_regions().clear()
	print("Terrain fully cleared!")

## Reads a 16-bit raw heightmap file and returns a normalized (0-1) single-channel Image.
func load_raw_heightmap(raw_path: String) -> Image:
	var file := FileAccess.open(raw_path, FileAccess.READ)
	if file == null:
		return null

	var raw_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	# raw files are all 1025x1025 16-bit heightmaps. we need to conver to 1024x1024

	if raw_bytes.size() % 2 != 0:
		push_error("Heightmap file '%s' does not contain 16-bit samples." % raw_path)
		return null

	# var sample_count: int = raw_bytes.size() / 2
	var sample_resolution: int = 1025

	var final_resolution: int = 1024
	var image := Image.create_empty(final_resolution, final_resolution, false, Image.FORMAT_RF)
	var byte_index := 0
	# print("Loading raw heightmap from path: %s" % raw_path)
	# print(raw_bytes[0])
	for y in sample_resolution:
		for x in sample_resolution:
			if x == 512 or y == 512:
				byte_index += 2
				continue
			var sample: int = raw_bytes[byte_index] | (raw_bytes[byte_index + 1] << 8)
			var newX = x
			var newY = y
			if x > 512:
				newX = x - 1
			if y > 512:
				newY = y - 1

			image.set_pixel(newX, final_resolution - 1 - newY, Color(sample / 65535.0, 0.0, 0.0, 1.0))
			byte_index += 2
	return image


## Loads each tile's satellite/color texture and imports it into the matching region.
func refresh_terrains_texture() -> void:
# func _refresh_terrains_texture() -> void:
	if reference_terrains_base == null:
		push_error("Reference terrains base is not assigned.")
		return
	if color_pallette.is_empty() or color_pallette.size() != terrain_layer_index.size():
		push_error("Color palette and terrain layer index arrays must contain the same non-zero number of entries.")
		return
	var operations_count: int = 0
	for reference_terrain in reference_terrains_base.get_children():
		if not reference_terrain is Node3D:
			continue
		# if reference_terrain.name != "EXPORT_GOOGLE_SAT_WM_010": # test just with 1 terrain
		# 	continue
		if completed_nodes.has(reference_terrain):
			continue

		var tile_name: String = reference_terrain.name
		tile_name = tile_name.replace("EXPORT_GOOGLE_SAT_WM_", "EXPORT_GOOGLE_SAT_WM.")

		var terrain_texture_folder_path_final: String = (terrain_texture_folder_path % terrain_level_letter)
		var texture_path: String = terrain_texture_folder_path_final.path_join(tile_name + terrain_texture_file_suffix)

		if not FileAccess.file_exists(texture_path):
			push_warning("Texture file not found for terrain '%s': %s" % [tile_name, texture_path])
			continue

		var texture_image: Image = Image.load_from_file(texture_path)
		if texture_image == null:
			push_error("Could not load texture image at '%s'." % texture_path)
			continue
		
		var world_position_center: Vector3 = get_rounded_terrain_position(reference_terrain.global_position)
		var control_resolution: int = get_region_size()
		texture_image.resize(control_resolution, control_resolution, Image.INTERPOLATE_NEAREST)
		var texel_spacing: float = get_vertex_spacing()
		var currentRegion: Terrain3DRegion = data.get_regionp(world_position_center)
		if currentRegion != null:
			var control_texture: Image = currentRegion.get_map(Terrain3DRegion.TYPE_CONTROL)
			var control_raw_data: PackedByteArray = control_texture.get_data()
			# control_texture.create(control_resolution, control_resolution, false, Image.FORMAT_RGBA8)

			for y in range(control_resolution):
				for x in range(control_resolution):
					var original_color: Color = texture_image.get_pixel(x, y)
					var closest_color_index: int = 0
					var min_distance: float = distance_to_color(original_color, color_pallette[0])
					for palette_index in range(0, color_pallette.size()):
						var distance: float = distance_to_color(original_color, color_pallette[palette_index])
						if distance < min_distance:
							min_distance = distance
							closest_color_index = palette_index
					var byte_0_index: int = (y * control_resolution + x) * 4
					var byte_1_index: int = byte_0_index + 1
					var byte_2_index: int = byte_0_index + 2
					var byte_3_index: int = byte_0_index + 3

					var base_texture_id = terrain_layer_index[closest_color_index] # 5 bits, 0-31
					var overlay_texture_id = 3 # 5 bits, 0-31
					var texture_blend = 0 # 8 bits, 0-255
					var UV_angle = 0 # 4 bits, 0-15 
					var UV_scale = 0 # 3 bits, 0-7
					var hole = 0 # 1 bit, 0-1
					var navigation = 0 # 1 bit, 0-1
					var autoshader = 0 # 1 bit, 0-1

					
					control_raw_data[byte_0_index] = (UV_scale & 0x7) << 7
					control_raw_data[byte_0_index] |= (hole & 0x1) << 2
					control_raw_data[byte_0_index] |= (navigation & 0x1) << 1
					control_raw_data[byte_0_index] |= (autoshader & 0x1)

					control_raw_data[byte_1_index] = (texture_blend & 0xFF) << 6
					control_raw_data[byte_1_index] |= (UV_angle & 0xF) << 2
					control_raw_data[byte_1_index] |= (UV_scale & 0x7) >> 1

					control_raw_data[byte_2_index] = (overlay_texture_id & 0x1F) << 6
					control_raw_data[byte_2_index] |= (texture_blend & 0xFF) >> 2

					control_raw_data[byte_3_index] = (base_texture_id & 0x1F) << 3
					control_raw_data[byte_3_index] |= (overlay_texture_id & 0x1F) >> 2

			control_texture.set_data(control_resolution, control_resolution, false, Image.FORMAT_RF, control_raw_data)
			# control_texture
					# var world_pixel_position := world_position_center + Vector3(x * texel_spacing, 0, y * texel_spacing)
					# data.set_control_base_id(world_pixel_position, terrain_layer_index[closest_color_index])
			# currentRegion.set_map(Terrain3DRegion.TYPE_CONTROL, control_texture)
			data.import_images([currentRegion.get_map(Terrain3DRegion.TYPE_HEIGHT), control_texture, null], world_position_center)
		
			data.update_maps()
			if data_directory.is_empty():
				push_error("Data directory is not assigned; control map for terrain '%s' was not saved." % tile_name)
			else:
				data.save_directory(data_directory)
		else:
			push_warning("Missing region for terrain '%s'; control map was not applied." % tile_name)

		print("Applied control map for terrain '%s'." % tile_name)
		# var test_save_path: String = "res://test_quantized_texture.png"
		# quantized_image.save_png(test_save_path)

		# var world_position: Vector3 = get_rounded_terrain_position(reference_terrain.global_position)
		# data.import_images([null, null, texture.get_image()], world_position, 0.0, 0.0)
		# print("Applied texture for terrain '%s'." % tile_name)
		await get_tree().create_timer(1.0).timeout

		completed_nodes.append(reference_terrain)
		operations_count += 1
		if operations_count >= max_operations:
			print("Reached maximum number of operations (%d)." % max_operations)
			return
	
func get_codified_base_color(pixel_raw: int, control_resolution: int, base_texture_id: int) -> int:
	# var codified_color: Color = control_data
	# var codified_color: Color = Color(0, 0, 0, 0)
	# # Bit 32-28, 5 bits, 0-31
	# codified_color.a = (base_texture_id & 0x1F) << 8
	# codified_color.r = (base_texture_id & 0x1F) << 8
	# codified_color.g = base_texture_id
	# codified_color.r = 2
	# codified_color.a = base_texture_id << 8
	# codified_color.a = base_texture_id
	# return (base_texture_id & 0x1F) <<27
	# return base_texture_id
	return 0




func quantize_texture(image: Image, _color_pallette: Array[Color]) -> Image:
	var quantized_image: Image = image.duplicate()
	# quantized_image
	for y in range(quantized_image.get_height()):
		for x in range(quantized_image.get_width()):
			var original_color: Color = quantized_image.get_pixel(x, y)
			var closest_color: Color = _color_pallette[0]
			var min_distance: float = distance_to_color(original_color, closest_color)
			for color in _color_pallette:
				var distance: float = distance_to_color(original_color, color)
				if distance < min_distance:
					min_distance = distance
					closest_color = color
			quantized_image.set_pixel(x, y, closest_color)
	# quantized_image.unlock()
	return quantized_image
func distance_to_color(color1: Color, color2: Color) -> float:
	return sqrt(pow(color1.r - color2.r, 2) + pow(color1.g - color2.g, 2) + pow(color1.b - color2.b, 2) + pow(color1.a - color2.a, 2))
## Saves any unsaved region data back to the terrain's data directory.
func verify_terrains_data_is_saved_to_disk() -> void:
	if data_directory.is_empty():
		push_error("Data directory is not assigned.")
		return

	data.save_directory(data_directory)
	print("Terrain data saved to '%s'." % data_directory)
func sample_height_at_position(world_position: Vector3) -> Variant:
	var world_position_center: Vector3 = get_rounded_terrain_position(world_position)
	var currentRegion: Terrain3DRegion = data.get_regionp(world_position_center)
	if currentRegion != null:
		var height: float = data.get_height(world_position)
		return height
	else:
		push_warning("No terrain region found at position %s." % world_position_center)
		return null