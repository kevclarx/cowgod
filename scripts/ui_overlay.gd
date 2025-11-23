extends Control
class_name UIOverlay

const Constants = preload("res://scripts/constants.gd")

var game_manager: Node
var population_graph: Control
var info_panel: Panel
var day_label: Label

func _ready():
	setup_ui()

func setup_ui():
	# Population graph
	population_graph = Control.new()
	population_graph.position = Vector2(1520, 0)
	population_graph.size = Vector2(400, 500)
	add_child(population_graph)
	
	# Info panel
	info_panel = Panel.new()
	info_panel.position = Vector2(10, 10)
	info_panel.size = Vector2(300, 150)
	add_child(info_panel)
	
	# Day label
	day_label = Label.new()
	day_label.position = Vector2(20, 20)
	day_label.add_theme_font_size_override("font_size", 24)
	info_panel.add_child(day_label)
	
	# Population labels
	for i in range(Constants.SPECIES_COUNT):
		var label = Label.new()
		label.position = Vector2(20, 50 + i * 25)
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Constants.SPECIES_COLORS[i]
		label.name = "Species" + str(i)
		info_panel.add_child(label)

func _process(_delta):
	if not game_manager:
		return
	
	update_ui()

func update_ui():
	# Update day label
	var days = game_manager.ticks / Constants.TICKS_PER_DAY
	var hour_fraction = fmod(days, 1.0) * 24
	var hour = int(hour_fraction)
	var minute = int(fmod(hour_fraction, 1.0) * 60) + 1
	var hour_piece = str(hour % 12) if hour % 12 != 0 else "12"
	var am_pm = "PM" if hour >= 12 else "AM"
	var hour_string = hour_piece + ":" + ("%02d" % minute) + " " + am_pm
	day_label.text = "Day " + str(int(days) + 1) + " at " + hour_string
	
	# Update population counts
	var populations = game_manager.get_populations()
	for i in range(Constants.SPECIES_COUNT):
		var label = info_panel.get_node_or_null("Species" + str(i))
		if label:
			var species_name = ["Pink Flower", "Ice Flower", "Yellow Cow", "Teal Cow", "Red Predator", "Gray"][i]
			label.text = species_name + ": " + str(populations[i])
	
	# Schedule redraw using queue_redraw via deferred call on this Control
	# (calling queue_redraw() directly caused parser errors earlier)
	self.call_deferred("queue_redraw")

func _draw():
	if not game_manager or game_manager.archive.size() < 2:
		return
	
	# Find range
	var min_val = 999999
	var max_val = -999999
	for record in game_manager.archive:
		for pop in record["populations"]:
			min_val = min(min_val, pop)
			max_val = max(max_val, pop)
	
	if max_val == min_val:
		max_val = min_val + 1
	
	# Draw lines
	var graph_width = 340.0
	var graph_height = 200.0
	var graph_x = 1540.0
	var graph_y = 800.0
	
	for s in range(Constants.SPECIES_COUNT):
		var color = Constants.SPECIES_COLORS[s]
		for i in range(game_manager.archive.size() - 1):
			var x1 = graph_x + i * graph_width / (game_manager.archive.size() - 1)
			var x2 = graph_x + (i + 1) * graph_width / (game_manager.archive.size() - 1)
			
			var val1 = game_manager.archive[i]["populations"][s]
			var val2 = game_manager.archive[i + 1]["populations"][s]
			
			var ratio1 = (val1 - min_val) / (max_val - min_val) if max_val != min_val else 0.5
			var ratio2 = (val2 - min_val) / (max_val - min_val) if max_val != min_val else 0.5
			
			var y1 = graph_y + graph_height - ratio1 * graph_height
			var y2 = graph_y + graph_height - ratio2 * graph_height
			
			draw_line(Vector2(x1, y1), Vector2(x2, y2), color, 2.0)
	
	# Draw daylight indicator
	for i in range(game_manager.archive.size() - 1):
		var x1 = graph_x + i * graph_width / (game_manager.archive.size() - 1)
		var x2 = graph_x + (i + 1) * graph_width / (game_manager.archive.size() - 1)
		
		var dl1 = game_manager.archive[i]["daylight"]
		var dl2 = game_manager.archive[i + 1]["daylight"]
		
		var y1 = graph_y + graph_height + 20 - dl1 * 40
		var y2 = graph_y + graph_height + 20 - dl2 * 40
		
		draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(0.5, 0.5, 0.5), 2.0)
