extends Node3D

@export var mesh: MeshInstance3D

@export var animacions: Dictionary

@export var frame_count := 4
@export var fps := 8.0

var animacio_actual := ""
var frame := 0
