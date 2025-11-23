extends Node

# Global constants for the food chain simulator

const PLAYER_COUNT = 110
const SIZE = 36  # Map size
const T = 140.0  # Tile size
const COLLISION_DISTANCE = 33.0
const MAX_PER_TILE = 2
const VISION_DISTANCE = T * 7.0
const TICKS_PER_DAY = 4500.0

# Species configuration
const SPECIES_COUNT = 6
const START_SPECIES = [0,0,0,0,0,0,0,1,1,1,1,1,2,2,2,3,3,4]
const SPECIES_COLORS = [
	Color(1.0, 0.4, 1.0),  # Pink flower
	Color(0.0, 1.0, 1.0),  # Ice flower
	Color(1.0, 0.8, 0.0),  # Yellow cow
	Color(0.0, 0.63, 0.63),  # Teal cow
	Color(1.0, 0.0, 0.0),  # Red predator
	Color(0.5, 0.5, 0.5)   # 6th species
]

const SKY_COLOR = Color(0.59, 0.78, 1.0)
const WATER_COLOR = Color(0.16, 0.31, 0.86)

# Priority system
const PRIORITY_NAMES = ["Hunger", "Thirst", "Freaky", "Eepy", "Flee Monsters", "Caretaking"]
const PRIORITY_COLORS = [
	Color(0.59, 0.39, 0.20),
	Color(0.0, 0.0, 1.0),
	Color(1.0, 0.0, 1.0),
	Color(0.5, 1.0, 0.0),
	Color(1.0, 0.0, 0.0),
	Color(1.0, 0.74, 0.47)
]
const PRIORITY_CAPS = [0.0, 0.0, 0.2, 0.6, 0.0, 0.0]

# Priority rates per species
const PRIORITY_RATES = [
	[3.0, 0, 0, 0, 0, 0],  # Pink flower
	[2.3, 0, 0, 0, 0, 0],  # Ice flower
	[13.2, 3.3, 6.0, 0, 0, -90],  # Yellow cow
	[13.0, 3.5, 5.68, 0, 0, -90],  # Teal cow
	[12.5, 5.0, 4.32, 0, 0, -90],  # Red predator
	[9.0, 4, 3.6, 0, 0, -90]  # 6th species
]

# Food chain matrix
const IS_FOOD = [
	[false, false, false, false, false, false],
	[false, false, false, false, false, false],
	[true, false, false, false, false, false],
	[false, true, false, false, false, false],
	[false, false, true, true, false, false],
	[false, false, false, false, true, false]
]

const CALORIES_RATE = [1.35, 1.35, 1.00, 1.00, 0.80, 1.0]
const WATER_CALORIES = 0.40
const SPECIES_SPEED = [0.0, 0.0, 0.5, 0.52, 0.54, 1.00]

# Get species type: -1 = player, 0 = plant, 1 = herbivore, 2 = carnivore
static func get_species_type(species: int) -> int:
	const IS_PLANT = [0, 0, 1, 1, 2, 2]
	if species == -1 or species == -2:
		return -1
	return IS_PLANT[species]
