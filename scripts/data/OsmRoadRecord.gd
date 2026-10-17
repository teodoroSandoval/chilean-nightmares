extends Resource
class_name OsmRoadRecord

@export var id: int
@export var name = ""
@export var official_name = ""
@export var alternate_name = ""
@export var highway_type = HighwayType.NONE
@export var surface_type = SurfaceType.NONE
@export var building_type = ""
@export var waterway_type = ""
@export var leisure_type = ""
@export var railway_type = ""
@export var landuse_type = ""
@export var natural_type = ""
@export var amenity_type = ""
@export var barrier_type = ""
@export var boundary_type = ""
@export var man_made_type = ""
@export var one_way = false
@export var lanes = 1
@export var lit = false
@export var node_ids: Array[int] = []
@export var tags: Dictionary[String, String] = {}
@export var is_area = false
@export var is_highway = false
@export var is_building = false
@export var is_waterway = false
@export var is_railway = false
@export var is_landuse = false
@export var is_natural = false
@export var is_amenity = false
@export var is_leisure = false
@export var is_barrier = false
@export var is_boundary = false
@export var is_man_made = false

enum HighwayType {
    NONE = 0, SECONDARY = 1 << 0, TERTIARY = 1 << 1, TRUNK_LINK = 1 << 2,
    PATH = 1 << 3, RESIDENTIAL = 1 << 4, UNCLASSIFIED = 1 << 5, TRUNK = 1 << 6,
    SERVICE = 1 << 7, FOOTWAY = 1 << 8, PEDESTRIAN = 1 << 9, LIVING_STREET = 1 << 10,
    TRACK = 1 << 11, SECONDARY_LINK = 1 << 12, STEPS = 1 << 13, ALL = (1 << 14) - 1,
}
enum SurfaceType {
    NONE = 0, ASPHALT = 1 << 0, COMPACTED = 1 << 1, UNPAVED = 1 << 2,
    GROUND = 1 << 3, DIRT = 1 << 4, PAVING_STONES = 1 << 5, PAVED = 1 << 6,
    GRAVEL = 1 << 7, ARTIFICIAL_TURF = 1 << 8, SAND = 1 << 9, CONCRETE = 1 << 10,
    METAL = 1 << 11, US = 1 << 12, ALL = (1 << 13) - 1,
}