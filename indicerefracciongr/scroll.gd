extends ScrollContainer

var materials = []
var MaterialScene = preload("res://MatLabel.tscn")
var MaterialTheme = preload("res://Theme.tres")
var material_container : VBoxContainer
@onready var line_edit = %LineEdit

# Constants
var label_height = 30
var normal_size = 3.0
var max_size = 5.5
var min_opacity = 0.3
var max_opacity = 1.0
var spacing = 60  # Space between material labels (separation)
var scroll_offset: float = 0
var target_scroll_offset: float = 0  # Target for lerp-based scroll animation
var scroll_speed: float = 0.3  # Speed of the scrolling animation
var transition_speed: float = 0.1  # Speed of the smooth label transitions
var icon_dict = {
	"building": "res://Icons/brick-wall.png",
	"glass": "res://Icons/window.png",
	"mineral": "res://Icons/crystal.png",
	"liquid": "res://Icons/droplet.png",
	"gas": "res://Icons/fresh-air.png"
}

# Padding for scroll area (top and bottom space)
var top_padding = 500.0
var bottom_padding = 500.0

# Number of empty padding nodes to add at the beginning and end
var n_empty = 1

var material_labels = []

func _ready():
	line_edit.custom_minimum_size = Vector2(240, 60)  # Adjust the size
	add_child(line_edit)
	
	# Load materials from the CSV file
	load_materials_from_csv("res://mat.csv")
	
	# Sort materials by refractive index in ascending order
	materials.sort_custom(_sort_by_refractive_index)

	# Create the VBoxContainer to hold the labels
	material_container = VBoxContainer.new()
	material_container.add_theme_constant_override("separation", spacing)  # Set separation
	add_child(material_container)

	# Calculate min and max refractive indices
	var min_index = materials[0]["refractive_index"]
	var max_index = materials[0]["refractive_index"]

	for material in materials:
		min_index = min(min_index, material["refractive_index"])
		max_index = max(max_index, material["refractive_index"])

	# Create labels for all materials
	for material in materials:
		var label = MaterialScene.instantiate()
		label.text = material["name"]
		label.custom_minimum_size = Vector2(240, float(label_height))
		label.theme = MaterialTheme
		label.scale = Vector2(normal_size, normal_size)
		label.modulate = Color(1, 1, 1, min_opacity)
		material_labels.append(label)
		material_container.add_child(label)
		

		# Get the "Index" node (the label for the refractive index)
		var index_label = label.get_node("Index")
		if index_label:
			index_label.text = "%0.3f" % material["refractive_index"] + "|"
			# Calculate the factor between 0 and 1 based on the refractive index
			var color_factor = (material["refractive_index"] - min_index) / (max_index - min_index)
			# Interpolate between two colors
			var start_color = Color.NAVAJO_WHITE
			var end_color = Color.MAROON
			var interpolated_color = start_color.lerp(end_color, color_factor)
			# Apply the color to the index label
			index_label.modulate = interpolated_color
		# Also add the material type
		for category in material["categories"]:
			if material["categories"][category] == true:
				var new_texture_path = icon_dict[category]
				label.text += " [img={12}]"+new_texture_path+"[/img]"
	# Add padding nodes at the end
	for i in range(n_empty):
		var empty_node = Control.new()
		empty_node.custom_minimum_size = Vector2(0, label_height)
		material_container.add_child(empty_node)

	# Adjust the container size to fit all materials, with added padding
	var total_height = (label_height + spacing) * materials.size() + (n_empty * label_height * 2) + top_padding + bottom_padding
	material_container.custom_minimum_size = Vector2(0, total_height)
	line_edit.text_changed.connect(_on_line_edit_text_changed)


func _sort_by_refractive_index(a, b):
	return a["refractive_index"] < b["refractive_index"]


func _process(delta):
	scroll_offset = lerp(scroll_offset, target_scroll_offset, scroll_speed)
	# Update the vertical scroll position of the ScrollContainer
	scroll_vertical = scroll_offset
	# Center of the scroll area
	var center_y = size.y / 2 + scroll_offset
	# Loop through all material labels
	for i in range(material_labels.size()):
		var label = material_labels[i]
		# Calculate the distance of the label's center from the scroll center
		var label_center = (i * (label_height + spacing)) + (label_height / 2) + spacing / 2 + top_padding + (n_empty * label_height)
		var distance_from_center = abs((label_center - scroll_offset) - size.y / 2)
		# Calculate target size and opacity factors
		var target_size_factor = 1.0 - clamp(distance_from_center / (size.y / 2), 0.0, 1.0) * 1.4
		var target_opacity_factor = lerp(min_opacity, max_opacity, target_size_factor)
		# Smoothly interpolate the current size and opacity toward the target values
		label.scale = label.scale.lerp(Vector2(lerp(normal_size, max_size, target_size_factor),
			lerp(normal_size, max_size, target_size_factor)), transition_speed)
		label.modulate = label.modulate.lerp(Color(1, 1, 1, target_opacity_factor), transition_speed)

# Handle input events like touch and mouse wheel
func _input(event):
	if event is InputEventScreenDrag:
		scroll(-event.relative.y)
	elif event is InputEventMouseMotion and event.relative.y != 0 and Input.is_action_pressed("ui_scroll"):
		scroll(-event.relative.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		scroll(-400)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		scroll(400)

func scroll(delta: float):
	target_scroll_offset += delta
	var max_scroll_offset = (material_labels.size() * (label_height + spacing) + top_padding + bottom_padding) - size.y
	target_scroll_offset = clamp(target_scroll_offset, -top_padding, max_scroll_offset * 1.1)


func load_materials_from_csv(file_path: String):
	# Open the CSV file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		# Read the entire file as a string
		var file_content = file.get_as_text()
		# Close the file
		file.close()
		# Split the content into lines (each line is a row in the CSV)
		var lines = file_content.split("\n")
		lines = lines.slice(1)
		# Loop through each line and extract the data
		for line in lines:
			# Skip empty lines (in case there's an extra empty line at the end)
			if line.strip_edges() == "":
				continue
			# Split the line by commas (assuming the CSV uses commas as separators)
			var columns = line.split(",")
			# Ensure we have at least 7 columns: name, refractive index, and five category flags
			if columns.size() >= 7:
				var material_name = columns[0].strip_edges()  # First column is the material name
				var refractive_index = columns[1].strip_edges().to_float()  # Second column is the refractive index
				# Flags for categories (building, glass, mineral, liquid, gas)
				var categories = {
					"building": columns[2].strip_edges() == "X",
					"glass": columns[3].strip_edges() == "X",
					"mineral": columns[4].strip_edges() == "X",
					"liquid": columns[5].strip_edges() == "X",
					"gas": columns[6].strip_edges() == "X"
				}
				# Add material to the list
				materials.append({
					"name": material_name,
					"refractive_index": refractive_index,
					"categories": categories
				})


func _on_line_edit_text_changed(text):
	if line_edit.text.strip_edges().length() > 0:
		# Get the closest material (this is just an example; you could calculate based on the input content)
		var closest_material_index = get_closest_material_index()
			# Scroll to ensure that the closest material is visible
		scroll_to_material(closest_material_index)

func get_closest_material_index() -> int:
	var input_text = line_edit.text.strip_edges()  # Get the input text from the TextEdit
	var input_index = input_text.to_float()  # Convert the input text to a float (the refractive index input)
	# Initialize variables for tracking the closest material
	var closest_index = -1
	var min_distance = INF  # Initialize with a very large value (infinity)
	# Iterate through the materials to find the closest refractive index
	for i in range(materials.size()):
		var material_index = materials[i]["refractive_index"]  # Get the refractive index of the material
		# Calculate the absolute difference between the input refractive index and the current material's index
		var distance = abs(input_index - material_index)
		# If the current distance is smaller than the previous minimum, update closest material
		if distance < min_distance:
			min_distance = distance
			closest_index = i
	return closest_index


# Make material visible
func scroll_to_material(index: int):
	var label = material_labels[index]
	var label_center = (index * (label_height + spacing)) + (label_height / 2) + spacing / 2 + top_padding + (n_empty * label_height)
	# Adjust scroll position to center the label
	target_scroll_offset = label_center - size.y / 2
