# CMake-easytest

[![Travis](https://img.shields.io/travis/RWTH-ELP/CMake-easytest/master.svg?style=flat-square)](https://travis-ci.org/RWTH-ELP/CMake-easytest)
[![](https://img.shields.io/github/issues-raw/RWTH-ELP/CMake-easytest.svg?style=flat-square)](https://github.com/RWTH-ELP/CMake-easytest/issues)
[![BSD (3-clause)](http://img.shields.io/badge/license-3--clause_BSD-blue.svg?style=flat-square)](LICENSE)

CMake module for easy test integration.


## About

This CMake module provides an easy interface for adding tests to your project. Instead of defining each test case in a separate file, building the test binary, defining the test case, etc. you simply add a test file with everything included. Each file contains everything to know about the tests to run, so no additional configuration is required in CMake.

In short, this module is only a script for extracting all parameters for `add_executable()` and `add_test()` from a source file. But in combination with different configurations for the same source file, one may define a lot of tests in just one source file.

Let's take a little example: You have a small function to calculate the square of a number. If you want to test this function with common CMake functions, you'll need at least one source file calls for `add_executable()` and `add_test()`  for each corner case. With *CMake-easytest* it is as simple as this:

```C
#include <stdio.h>
#include "mymath.h"

int main()
{
	printf("%d\n", myquad(MYINT));
}

/* CMake-easytest configuration.
 *
 * CONFIGS: negative zero positive
 *
 *
 * negative-COMPILE: -DMYINT=-2
 * negative-PASS: 4
 *
 * zero-COMPILE: -DMYINT=0
 * zero-PASS: 0
 *
 * positive-COMPILE: -DMYINT=2
 * positive-PASS: 4
 */
```

```CMake
include(easytest)
easy_add_test(PREFIX myquad SOURCES test.c myquad.c)
```


## Include into your project

To use CMake-easytest, simply add this repository as git submodule into your own repository
```Shell
mkdir externals
git submodule add git://github.com/RWTH-ELP/CMake-easytest.git externals/CMake-easytest
```
and adding ```externals/CMake-easytest/cmake``` to your ```CMAKE_MODULE_PATH```
```CMake
set(CMAKE_MODULE_PATH
    "${PROJECT_SOURCE_DIR}/externals/CMake-easytest/cmake"
    ${CMAKE_MODULE_PATH})
```


## Usage

#### Adding a test file

For adding a new test file, simply call `easy_add_test()` with the following parameters:
* `PREFIX`: *(required)* Prefix for tests. Tests will be named `${PREFIX}_${CONFIG}`.
* `SOURCES`: *(required)* Source files of the test. Only the first file is evaluated for the easytest configuration, additional files will be used for compilation only.
* `CONFIGS`: Set configurations to add test cases for. If not defined, the `CONFIGS` key in the main source file will be used. It is recommended to use this option only, if not all configurations defined in the main source file should be handled.

#### Configuration in main source file

The main (first) source file will be evaluated for the test configurations. Each key must be prefixed by a space character and terminates with a colon. The following keys may be defined to define parameters for creating the tests. Except for `CONFIGS`, each key may be defined global as `KEY`, or for a specific configuration as `CONFIG-KEY`, where the configuration-specific key will overwrite the global value. Each key may be defined multiple times - the values will be stored in an array.

* `CONFIGS`: Space-delimited list of configurations defined in this test file.
* `COMPILE`: Add compile definitions for the test binary, e.g. `-DWITH_ERROR`.
* `LINK`: Linker-flags for the test binary, e.g. to link against a library.
* `PASS`: Set the tests `PASS_REGULAR_EXPRESSION` attribute.
* `FAIL`: Set the tests `FAIL_REGULAR_EXPRESSION` attribute.

**Note:** It is not recommended to use `PASS` and `FAIL` for complex expressions over multiple lines. Consider to combine this module with tools like [LLVM FileCheck](http://llvm.org/docs/CommandGuide/FileCheck.html).

The key values will be stripped from leading and trailing whitespace. Expressions in the format `%[^% ]` will be substituted by CMake variables with the same name (without the percentage sign).

*Additional keys may be defined and evaluated by custom hooks (see below).*


## Contribute

Anyone is welcome to contribute. Simply fork this repository, make your changes **in an own branch** and create a pull-request for your change. Please do only one feature per pull-request.

You found a bug? Please fill out an [issue](https://github.com/RWTH-ELP/CMake-easytest/issues) and include all data to reproduce the bug.

#### Contributors

[Alexander Haase](https://github.com/alehaa)


## License

CMake-easytest is released under the 3-clause BSD license. See the [LICENSE](LICENSE) file for more information.

Copyright &copy; 2017 RWTH Aachen University, Federal Republic of Germany.
