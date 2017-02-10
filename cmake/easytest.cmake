# This file is part of CMake-easytest.
#
# Copyright (c) 2017 RWTH Aachen University, Federal Republic of Germany
#
# See the LICENSE file in the package base directory for details
#
# Written by Alexander Haase, alexander.haase@rwth-aachen.de
#

# Get a keyword from FILE.
#
# This function will be used to get a key from FILE. Each line prefixed with the
# keyword will be matched and the value appended to DEST. Multiple matches will
# be appended as individual list elements.
#
# Parameters:
#   KEY  The key to be searched.
#   DEST Where to store matches.
#   FILE Where to search.
#
function(easytest_get_key KEY DEST FILE)
	# Search for KEY in FILE and get all lines with KEY.
	file(STRINGS ${FILE} TMP REGEX "${KEY}:")
	if (TMP)
		# Iterate over all found matches and extract the key value. Found values
		# will be appended to the buffer. Each value will be stripped from
		# leading and trailing whitespace.
		set(BUFFER "")
		foreach(LINE ${TMP})
			string(REGEX REPLACE ".*${KEY}:(.*)$" "\\1" LINE "${LINE}")
			string(STRIP "${LINE}" LINE)
			list(APPEND BUFFER "${LINE}")
		endforeach()

		# Store the found matches in DEST (in parent scope).
		set(${DEST} "${BUFFER}" PARENT_SCOPE)
	endif ()
endfunction()


# Add a new test file.
#
# This function will add new testcases for a source file.
#
# Parameters:
#   PREFIX  Prefix for tests defined by the source file. (required)
#   SOURCES Source files for test. Only the first file will be evaluated for
#           keys, but additional files may follow for compilation. (required)
#   CONFIGS Configs to run. (optional)
#
function (easy_add_test)
	# Evaluate the
	set(oneValueArgs PREFIX)
	set(multiValueArgs SOURCES CONFIGS)
	cmake_parse_arguments(EASYTEST "" "${oneValueArgs}" "${multiValueArgs}"
	                      ${ARGN})

	# Check if required variables have been set.
	foreach (VAR PREFIX SOURCES)
		if (NOT EASYTEST_${VAR})
			message(FATAL_ERROR "${VAR} not set.")
		endif ()
	endforeach ()


	# If no configs defined as parameter, search in first source file for
	# CONFIGS keyword and use these configs.
	if (NOT EASYTEST_CONFIGS)
		easytest_get_key("CONFIGS" BUFFER ${EASYTEST_SOURCES})
		if (BUFFER)
			foreach (LINE ${BUFFER})
				string(REPLACE " " ";" LINE "${LINE}")
				list(APPEND EASYTEST_CONFIGS ${LINE})
			endforeach ()
		endif ()

		# If still no configs could be found, use the default configuration with
		# no label.
	endif ()


	message("PREFIX: ${EASYTEST_PREFIX}")
	message("SOURCES: ${EASYTEST_SOURCES}")
	message("CONFIGS: ${EASYTEST_CONFIGS}")
endfunction ()
