@tool
extends Node3D
class_name TerrainMeshTools

## Folder containing "<tile_name><heightmap_file_suffix>" 16-bit raw heightmaps.
@export var material: Material = null
@export var terrain_level_letter: String = "A"
## Folder containing "<tile_name><texture_file_suffix>" satellite/color textures.
@export var terrain_texture_folder_path: String = "res://terrains/Level %s/Textures"
@export var terrain_texture_file_suffix: String = ".png"

@export_tool_button("Refresh Terrains Texture") var refresh_terrains_texture_action: Callable = refresh_terrains_texture

## Loads each tile's satellite/color texture and imports it into the matching region.
func refresh_terrains_texture() -> void:
	for reference_terrain in get_children():
		if not reference_terrain is Node3D:
			continue

		var tile_name: String = reference_terrain.name
		tile_name = tile_name.replace("EXPORT_GOOGLE_SAT_WM_", "EXPORT_GOOGLE_SAT_WM.")

		var terrain_texture_folder_path_final: String = (terrain_texture_folder_path % terrain_level_letter)
		var texture_path: String = terrain_texture_folder_path_final.path_join(tile_name + terrain_texture_file_suffix)

		if not FileAccess.file_exists(texture_path):
			push_warning("Texture file not found for terrain '%s': %s" % [tile_name, texture_path])
			continue

		var texture: Texture2D = load(texture_path)
		if texture == null:
			push_error("Could not load texture asset at '%s'." % texture_path)
			continue
		# surface_material_override/0
		# reference_terrain.surface_material_override = material

		var unique_material = material.duplicate()
		unique_material.albedo_texture = texture
		reference_terrain.set_surface_override_material(0, unique_material)

func sample_height_at_position(world_position: Vector3) -> Variant:
	var currentRegion: MeshInstance3D = get_region_mesh(world_position)
	if currentRegion != null and currentRegion.visible:
		var height: float = get_height_from_mesh(currentRegion, world_position)
		return height
	else:
		push_warning("No terrain region found at position %s." % world_position)
		return null
func get_region_mesh(world_position: Vector3) -> MeshInstance3D:
	for child_terrain in get_children():
		var local_aabb: AABB = child_terrain.get_aabb()
		var local_position: Vector3 = child_terrain.to_local(world_position)
		local_position.y = local_aabb.position.y + local_aabb.size.y / 2.0
		if local_aabb.has_point(local_position):
			return child_terrain
	return null
func get_height_from_mesh(region: MeshInstance3D, world_position: Vector3) -> float:
	# var local_position: Vector3 = region.to_local(world_position)
	# TODO: iterate all tiangles in the mesh and find the one that contains the local_position,
	# then calculate the vertically intersecting point.
	# then convert to world space and return the height.
	var mesh: Mesh = region.mesh
	if not mesh:
		return 0.0

	# 1. Convertir la posición global a coordenadas locales de la malla
	var local_pos = region.global_transform.affine_inverse() * Vector3(world_position.x, 0.0, world_position.z)
	
	# Definir un rayo virtual vertical descendente en el espacio local
	# (Empezamos muy arriba y apuntamos hacia abajo)
	var ray_origin = Vector3(local_pos.x, 10000.0, local_pos.z)
	var ray_direction = Vector3.DOWN

	# 2. Utilizar MeshDataTool para extraer los datos de la superficie
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0) # Asume la superficie 0

	var closest_y: float = 0.0
	var found_intersection: bool = false

	# 3. Iterar por cada triángulo (cara) de la malla
	for face_idx in mdt.get_face_count():
		# Obtener los índices de los 3 vértices del triángulo
		var v0_idx = mdt.get_face_vertex(face_idx, 0)
		var v1_idx = mdt.get_face_vertex(face_idx, 1)
		var v2_idx = mdt.get_face_vertex(face_idx, 2)

		# Obtener las posiciones vectoriales 3D de los vértices
		var v0 = mdt.get_vertex(v0_idx)
		var v1 = mdt.get_vertex(v1_idx)
		var v2 = mdt.get_vertex(v2_idx)

		# 4. Comprobar matemáticamente si nuestro rayo vertical cruza este triángulo
		var intersection = Geometry3D.ray_intersects_triangle(ray_origin, ray_direction, v0, v1, v2)
		
		# Si devuelve un Vector3, significa que el punto (X, Z) cae dentro de este triángulo
		if intersection != null:
			closest_y = intersection.y
			found_intersection = true
			break # Encontramos el triángulo exacto, podemos salir del bucle

	# 5. Si hubo intersección, transformar el punto resultante de vuelta al espacio global
	if found_intersection:
		var global_intersection = region.global_transform * Vector3(local_pos.x, closest_y, local_pos.z)
		return global_intersection.y
	return 0.0 # Retorna 0.0 si el punto (X,Z) está fuera de los límites de la malla