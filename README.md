# CMake-easytest

[![Travis](https://img.shields.io/travis/RWTH-ELP/CMake-easytest/master.svg?style=flat-square)](https://travis-ci.org/RWTH-ELP/CMake-easytest)
[![](https://img.shields.io/github/issues-raw/RWTH-ELP/CMake-easytest.svg?style=flat-square)](https://github.com/RWTH-ELP/CMake-easytest/issues)
[![BSD (3-clause)](http://img.shields.io/badge/license-3--clause_BSD-blue.svg?style=flat-square)](LICENSE)

CMake module for easy test integration.


## About

This CMake module provides an easy interface for adding tests to your project. Instead of defining each test case in a separate file, building the test binary, defining the test case, etc. you simply add a test file with everything included. Each file contains everything to know about the tests to run, so no additional configuration is required in CMake.

In short, this module is a script for extracting all parameters for `add_executable()` and `add_test()` from a source file. But in combination with different configurations for the same source file, one may define lots of tests in just one source file.

Let's look at a small example: You have a function to calculate the square of a number. If you want to test this function with common CMake functions, you'll need at least one source file calls for `add_executable()` and `add_test()`  for each corner case. With *CMake-easytest* it is as simple as this:

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
* `SOURCES`: *(required)* Source files for the test binary. Only the first file is evaluated for the easytest configuration, additional files will be used for compilation only.
* `CONFIGS`: Set configurations to add test cases for. If not defined, the `CONFIGS` key in the main source file will be used. *It is recommended to use this option only, if not all configurations defined in the main source file should be handled.*

#### Configuration in main source file

The main (first) source file will be evaluated for the test configurations. Each key must be  terminated with a colon. The following keys may be defined to set parameters for creating the tests. Except for `CONFIGS`, each key may be defined global as `KEY`, or for a specific configuration as `KEY-CONFIG`, where the configuration-specific key will overwrite the global value. Each key may be defined multiple times - the values will be stored in an array.

* `CONFIGS`: Space-delimited list of configurations defined in this test file.
* `COMPILE_FLAGS`: Add compile definitions for the test binary, e.g. `-DWITH_ERROR`.
* `COMPILE_INCLUDES`: Add include directories for the test binary, e.g. `../src`.
* `LINK`: Linker-flags for the test binary, e.g. to link against a library.
* `RUN`: How to run the test. If not set, the binary will be called without any arguments.
* `ENVIRONMENT`: Environment variables for running the test.
* `PASS`: Set the tests `PASS_REGULAR_EXPRESSION` attribute.
* `FAIL`: Set the tests `FAIL_REGULAR_EXPRESSION` attribute.

**Note:** It is not recommended to use `PASS` and `FAIL` for complex expressions over multiple lines. Consider to combine this module with tools like [LLVM FileCheck](http://llvm.org/docs/CommandGuide/FileCheck.html).

The key values will be stripped from leading and trailing whitespace. Expressions in the format `%[A-Za-z0-9_-]*` will be substituted by CMake variables with the same name (without the percentage sign). The following common expressions may be used to get test data:

* `%BINARY`: Path to the binary. This is equivalent to `$<TARGET_FILE:testbin-${PREFIX}-${CONFIG}>`. *This expression can only be used in the configuration-specific keys!*

*Additional keys may be defined and evaluated by custom hooks (see below).*

## Hooks

It may be necessary to modify steps of the test definition, e.g. to use a special command for building the test binary. To accomplish this, you may define the following hooks to **override** the internal ones:

* `easytest_hook_compile(TARGET CONFIG MAIN_SOURCE ...)`

  This hook adds a new executable target for test configuration `CONFIG`. It may be replaced to call a custom build script.

  **Parameters:**
  * `TARGET`: Target name to use for binary. This name **must** be used, otherwise other hooks can't find the binary.
  * `CONFIG`: The configuration to build. You may use this to search for custom keys (see below). *You don't need to search for common keys, as these have been searched before. Access them via `EASYTEST_${KEY}`.*
  * `MAIN_SOURCE`: The main source file, where to search for configuration keys and other data.
  * `...`: All additional parameters are source files for building the binary target.

  **Note:** This hook is for compile-tasks only. If you just want to e.g. add custom flags to the target, the next hook will be yours!

* `easytest_hook_post_compile(BINARY_TARGET CONFIG MAIN_SOURCE)`

  This hook will be used to modify the binary test target for your needs, e.g. to add specific compile flags not set in the test file. At the time of writing the intention was to e.g. call other functions for the executable target, to e.g. register code coverage and sanitizers done by external CMake modules.

  **Parameters:**
  * `BINARY_TARGET`: Binary target name.
  * `CONFIG`: The configuration to build. You may use this to search for custom keys (see below). *You don't need to search for common keys, as these have been searched before. Access them via `EASYTEST_${KEY}`.*
  * `MAIN_SOURCE`: The main source file, where to search for configuration keys and other data.

* `easytest_hook_test(TEST_TARGET BINARY_TARGET CONFIG MAIN_SOURCE)`

  This hook adds a new test target for test configuration `CONFIG`. It may be replaced to configure specific test runs.

  **Parameters:**
  * `TEST_TARGET`: Target name to use for test. This name **must** be used, otherwise other hooks can't find the binary.
  * `BINARY_TARGET`: Binary target name.
  * `CONFIG`: The configuration to build. You may use this to search for custom keys (see below). *You don't need to search for common keys, as these have been searched before. Access them via `EASYTEST_${KEY}`.*
  * `MAIN_SOURCE`: The main source file, where to search for configuration keys and other data.

* `easytest_hook_post_test(TEST_TARGET CONFIG MAIN_SOURCE)`

  This hook may be used to configure the test target, e.g. set dependencies.

   **Parameters:**
   * `TEST_TARGET`: Test target name.
   * `CONFIG`: The configuration to build. You may use this to search for custom keys (see below). *You don't need to search for common keys, as these have been searched before. Access them via `EASYTEST_${KEY}`.*
   * `MAIN_SOURCE`: The main source file, where to search for configuration keys and other data.

#### Accessing keys

All common keys can be accessed via `EASYTEST_${KEY}` variables.

For custom keys, you may use `easytest_get_key(KEY DEST MAIN_SOURCE)`. It will search for `KEY` in `MAIN_SOURCE` and stores all matches in `DEST`. Remember to call this function for `KEY` and `KEY-CONFIG`, if the key may be defined global and per configuration.


## Recommendations

* Try to avoid using hooks for everything. E.g. if your tests use OpenMP, don't define the `easytest_hook_post_compile` hook for adding the OpenMP compiler flags, as they can be accessed with the `OpenMP_C_FLAGS` variable. You might consider using something like this:

  ```C
  #include <stdio.h>
  #include <omp.h>

  int main ()
  {
	#pragma omp parallel
	{
		printf("%d of %d\n", omp_get_thread_num() + 1, omp_get_num_threads());
	}
  }

  /* CMake-easytest configuration.
   *
   * COMPILE_FLAGS: %OpenMP_C_FLAGS
   * LINK: %OpenMP_C_FLAGS
   */
  ```

* This also applies to the creation of tests: Instead of defining the `easytest_hook_test` hook to sort the output of the test case above by rank, you might consider to use variables:

  ```CMake
  include(easytest)
  find_package(OpenMP REQUIRED)

  set(sort "sort -n")
  easy_add_test(PREFIX OpenMP_thread_num SOURCES openmp.c)
  ```

  And use them in the test file:
  ```C
  /* CMake-easytest configuration.
   *
   * COMPILE_FLAGS: %OpenMP_C_FLAGS
   * LINK: %OpenMP_C_FLAGS
   *
   * ENVIRONMENT: OMP_NUM_THREADS=4
   * RUN-CHECK: %BINARY | %sort
   * PASS: 1.*2.*3.*4
   */
  ```


## Contribute

Anyone is welcome to contribute. Simply fork this repository, make your changes **in an own branch** and create a pull-request for your change. Please do only one feature per pull-request.

You found a bug? Please fill out an [issue](https://github.com/RWTH-ELP/CMake-easytest/issues) and include all data to reproduce the bug.

#### Contributors

[Alexander Haase](https://github.com/alehaa)


## License

CMake-easytest is released under the 3-clause BSD license. See the [LICENSE](LICENSE) file for more information.

Copyright &copy; 2017 RWTH Aachen University, Federal Republic of Germany.
