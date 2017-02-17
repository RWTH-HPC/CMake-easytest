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
	DEPENDS          # Targets the binary target depends on.
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

	if (EASYTEST_DEPENDS)
		add_dependencies(${TARGET} ${EASYTEST_DEPENDS})
	endif ()
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
	if (EASYTEST_RUN)
		add_test(NAME ${TARGET} COMMAND ${EASYTEST_RUN})
	else ()
		add_test(${TARGET} ${BINARY})
	endif ()
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
			string(REPLACE "\\n" "\n" LINE "${LINE}")
			string(CONFIGURE "${LINE}" LINE @ONLY)
			set(BUFFER "${BUFFER} ${LINE}")
		endforeach()
		string(STRIP "${BUFFER}" BUFFER)

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
	# Set target names.
	set(TEST_TARGET "${PREFIX}")
	if (CONFIG)
		set(TEST_TARGET "${PREFIX}-${CONFIG}")
	endif ()
	set(BINARY_TARGET "testbin-${TEST_TARGET}")


	# Set common variables for this target.
	set(BINARY "$<TARGET_FILE:${BINARY_TARGET}>")


	# Get individual config keys from main source file. Individual keys will
	# override the global test key values.
	if (CONFIG)
		foreach (KEY ${EASYLIST_COMMON_KEYS})
			easytest_get_key(${KEY}-${CONFIG} EASYTEST_${KEY} ${MAIN_SOURCE})
		endforeach ()

	# If there are no individual configurations, reload the RUN key to parse
	# the BINARY variable.
	else ()
		easytest_get_key(RUN EASYTEST_RUN ${MAIN_SOURCE})
	endif ()


	# Postprocess RUN key, as add_test needs a list of arguments, but RUN is a
	# string. To accomplish this and to allow pipes in the command, the whole
	# string will be used as argument for sh.
	if (EASYTEST_RUN)
		set(EASYTEST_RUN sh -c "${EASYTEST_RUN}")
	endif ()

	# Postprocess COMPILE_INCLUDES key, as it must be a list, but
	# COMPILE_INCLUDES may be a space delimited string.
	string(REPLACE " " ";" EASYTEST_COMPILE_INCLUDES
	               "${EASYTEST_COMPILE_INCLUDES}")


	# Call the hooks for compile and test creation.
	if (DEFINED easytest_hook_setup)
		easytest_hook_setup(${TEST_TARGET} ${BINARY_TARGET} "${CONFIG}"
		                    ${MAIN_SOURCE})
	endif ()

	if (NOT EASYTEST_NOBINARY)
		easytest_hook_compile(${BINARY_TARGET} "${CONFIG}" ${MAIN_SOURCE}
		                      ${ARGN})
		easytest_hook_post_compile(${BINARY_TARGET} "${CONFIG}" ${MAIN_SOURCE})
	endif ()

	easytest_hook_test(${TEST_TARGET} ${BINARY_TARGET} "${CONFIG}"
	                   ${MAIN_SOURCE})
	easytest_hook_post_test(${TEST_TARGET} "${CONFIG}" ${MAIN_SOURCE})
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
	# Evaluate the arguments.
	set(options NOBINARY)
	set(oneValueArgs PREFIX)
	set(multiValueArgs SOURCES CONFIGS)
	cmake_parse_arguments(EASYTEST "${options}" "${oneValueArgs}"
	                      "${multiValueArgs}" ${ARGN})

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
			set(EASYTEST_CONFIGS "")
		endif ()
	endif ()


	# Search for main configuration keys in main source file. The found values
	# may be overridden by individual config keys.
	list(GET EASYTEST_SOURCES 0 MAIN_SOURCE)
	foreach (KEY ${EASYLIST_COMMON_KEYS})
		easytest_get_key(${KEY} EASYTEST_${KEY} ${MAIN_SOURCE})
	endforeach ()


	# Add a new test for each configuration.
	if (EASYTEST_CONFIGS)
		foreach (CONFIG ${EASYTEST_CONFIGS})
			easytest_add_test_config(${EASYTEST_PREFIX} ${CONFIG}
			                         ${EASYTEST_SOURCES})
		endforeach ()
	else ()
		easytest_add_test_config(${EASYTEST_PREFIX} "" ${EASYTEST_SOURCES})
	endif ()
endfunction ()
