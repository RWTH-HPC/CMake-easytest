# This file is part of CMake-easytest.
#
# Copyright (c) 2017 RWTH Aachen University, Federal Republic of Germany
#
# See the LICENSE file in the package base directory for details
#
# Written by Alexander Haase, alexander.haase@rwth-aachen.de
#

include(easytest)

find_package(OpenMP REQUIRED)


set(sort "sort -n")

easy_add_test(PREFIX OpenMP_thread_num SOURCES openmp.c)
