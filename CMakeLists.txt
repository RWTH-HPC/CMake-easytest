# This file is part of CMake-easytest.
#
# Copyright (c) 2017 RWTH Aachen University, Federal Republic of Germany
#
# See the LICENSE file in the package base directory for details
#
# Written by Alexander Haase, alexander.haase@rwth-aachen.de
#

cmake_minimum_required(VERSION 3.13.4...3.27.4)

project(easytest C)

set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

enable_testing()
add_subdirectory(tests)
