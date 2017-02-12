# This file is part of CMake-easytest.
#
# Copyright (c) 2017 RWTH Aachen University, Federal Republic of Germany
#
# See the LICENSE file in the package base directory for details
#
# Written by Alexander Haase, alexander.haase@rwth-aachen.de
#

# The following keys will be searched in the tests main source file. Tests may
# use additional keywords, but won't get extracted by default so hooks have to
# be used to get their values.
#
set(EASYLIST_COMMON_KEYS
	COMPILE_FLAGS    # Flags for compiling the target.
	COMPILE_INCLUDES # Directories to include for compiling target.
	LINK             # Libraries to link on target.
	LINKER_FLAGS     # Flags for linking the target.

	RUN         # How to run the test.
	ENVIRONMENT # Environment variables for running the test.
	PASS        # PASS_EXPRESSION for test target.
	FAIL        # FAIL_EXPRESSION for test target.
)


# Default compile hook.
#
# This hook adds a new executable target for test configuration CONFIG. It may
# be replaced to call a custom build script.
#
# Parameters:
#   TARGET Binary target name.
#   CONFIG Test configuration.
#
#   Additional arguments represent the source files for the executable to build.
#
macro (easytest_hook_compile TARGET CONFIG)
	add_executable(${TARGET} ${ARGN})
endmacro ()


# Default post-compile hook.
#
# This hook sets additional parameters for the binary target depending on the
# previously defined configuration in the main source file.
#
# Parameters:
#   TARGET Binary target name.
#   CONFIG Test configuration.
#
#   Additional arguments represent the source files for the executable to build.
#
macro (easytest_hook_post_compile TARGET CONFIG)
	target_include_directories(${TARGET} PRIVATE ${EASYTEST_COMPILE_INCLUDES})
	target_compile_options(${TARGET} PRIVATE ${EASYTEST_COMPILE_FLAGS})
	target_link_libraries(${TARGET} ${EASYTEST_LINK})
endmacro ()


# Default test hook.
#
# This hook adds a new test target for test configuration CONFIG. It may be used
# to define custom test invocations.
#
# Parameters:
#   TARGET Test target name.
#   BINARY Binary target name.
#   CONFIG Test configuration.
#
#   Additional arguments represent the source files for the executable to build.
#
macro (easytest_hook_test TARGET BINARY CONFIG)
	add_test(${TARGET} ${BINARY})
endmacro ()


# Default post-test hook.
#
# This hook sets the attributes for test TARGET. It may be used to set
# additional arguments for the test.
#
# Parameters:
#   TARGET Test target name.
#   CONFIG Test configuration.
#
#   Additional arguments represent the source files for the executable to build.
#
macro (easytest_hook_post_test TARGET CONFIG)
	set_tests_properties(${TARGET} PROPERTIES PASS_REGULAR_EXPRESSION
	                     "${EASYTEST_PASS}")
	set_tests_properties(${TARGET} PROPERTIES FAIL_REGULAR_EXPRESSION
	                     "${EASYTEST_FAIL}")
	set_tests_properties(${TARGET} PROPERTIES ENVIRONMENT
	                     "${EASYTEST_ENVIRONMENT}")
endmacro ()



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
function (easytest_get_key KEY DEST FILE)
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

		# substitute variables set in key value.
		string(REGEX MATCHALL "%[^% ]*" VAR_MATCHES "${BUFFER}")
		foreach (MATCH ${VAR_MATCHES})
			string(REPLACE "%" "" VARNAME "${MATCH}")
			string(REPLACE "${MATCH}" "${${VARNAME}}" BUFFER "${BUFFER}")
		endforeach ()

		# Store the found matches in DEST (in parent scope).
		set(${DEST} "${BUFFER}" PARENT_SCOPE)
	endif ()
endfunction ()


# Add a new test configuration.
#
# This function will add a new testcase for a source file with a given
# configuration. Extra sources may be set as additional parameters, but only the
# first source file will be evaluated for keys.
#
# Parameters:
#   PREFIX      Test prefix.
#   CONFIG      Test configuration.
#   MAIN_SOURCE Main source file.
#
#   Additional parameters will be used as additional source files for
#   compilation, but will not be evaluated.
#
function (easytest_add_test_config PREFIX CONFIG MAIN_SOURCE)
	# Get individual config keys from main source file. Individual keys will
	# override the global test key values.
	foreach (KEY ${EASYLIST_COMMON_KEYS})
		easytest_get_key(${KEY}-${CONFIG} EASYTEST_${KEY} ${MAIN_SOURCE})
	endforeach ()

	# Set the name of the targets to be used for test and binary.
	set(EASYTEST_TEST_TARGET "${PREFIX}-${CONFIG}")
	set(EASYTEST_BIN_TARGET "testbin-${EASYTEST_TEST_TARGET}")

	# Call the hooks for compile and test creation.
	easytest_hook_compile(${EASYTEST_BIN_TARGET} ${CONFIG} ${MAIN_SOURCE}
	                      ${ARGN})
	easytest_hook_post_compile(${EASYTEST_BIN_TARGET} ${CONFIG} ${MAIN_SOURCE})
	easytest_hook_test(${EASYTEST_TEST_TARGET} ${EASYTEST_BIN_TARGET} ${CONFIG}
	                   ${MAIN_SOURCE})
	easytest_hook_post_test(${EASYTEST_TEST_TARGET} ${CONFIG} ${MAIN_SOURCE})
endfunction ()


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

		# If still no configs could be found, use the default configuration with
		# no label.
		else ()
			set(EASYTEST_CONFIGS "CHECK")
		endif ()
	endif ()


	# Search for main configuration keys in main source file. The found values
	# may be overridden by individual config keys.
	list(GET EASYTEST_SOURCES 0 MAIN_SOURCE)
	foreach (KEY ${EASYLIST_COMMON_KEYS})
		easytest_get_key(${KEY} EASYTEST_${KEY} ${MAIN_SOURCE})
	endforeach ()


	# Add a new test for each configuration.
	foreach (CONFIG ${EASYTEST_CONFIGS})
		easytest_add_test_config(${EASYTEST_PREFIX} ${CONFIG}
		                         ${EASYTEST_SOURCES})
	endforeach ()
endfunction ()
