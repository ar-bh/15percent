## Path utilities for converting between practice and solution file locations.
##
## This is a simple helper module that tracks the two folder used for practices
## in course projects: one for practices (where students work) and one for
## solutions.
const Utils := preload("../gdquest_sparkly_bag/sparkly_bag_utils.gd")

const RES := "res://"
const PRACTICES_PATH := "res://practices"
const SOLUTIONS_PATH := "res://addons/gdpractice/practice_solutions"


static func to_solution(path: String) -> String:
	return path.replace(PRACTICES_PATH, SOLUTIONS_PATH)


static func to_practice(path: String) -> String:
	return path.replace(SOLUTIONS_PATH, PRACTICES_PATH)


static func get_dir_name(path: String, relative_to := SOLUTIONS_PATH) -> String:
	var result := path.replace(relative_to, "")
	result = "" if result == path else result.lstrip(Utils.SEP).get_slice(Utils.SEP, 0)
	return result
