extends RefCounted


static func load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		config.clear()
		if config.load(path + ".bak") != OK:
			config.clear()
	return config


static func write_config(config: ConfigFile, path: String, rotate_backup := true) -> Error:
	var temp := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var error := config.save(temp)
	if error != OK:
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)
		return error
	var backup := path + ".bak"
	if not rotate_backup:
		error = DirAccess.rename_absolute(temp, path)
		if error != OK:
			DirAccess.remove_absolute(temp)
		elif FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		return error
	var backed_up := FileAccess.file_exists(path)
	if backed_up and FileAccess.file_exists(backup):
		error = DirAccess.remove_absolute(backup)
	if backed_up and error == OK:
		error = DirAccess.rename_absolute(path, backup)
	if error == OK:
		error = DirAccess.rename_absolute(temp, path)
	if error == OK:
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
	else:
		if backed_up and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup, path)
		DirAccess.remove_absolute(temp)
	return error
