extends SceneTree
## Lists connected joypads and their SDL mapping status. Run: ./build.sh pads

func _initialize() -> void:
	await process_frame
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		print("  (no controllers detected - plug in the USB pads and try again)")
	for id in pads:
		print("  Pad %d: %s  guid=%s  known=%s" % [id + 1, Input.get_joy_name(id), Input.get_joy_guid(id), Input.is_joy_known(id)])
	quit()
