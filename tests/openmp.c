/* This file is part of CMake-easytest.
 *
 * Copyright (c) 2017 RWTH Aachen University, Federal Republic of Germany
 *
 * See the LICENSE file in the package base directory for details
 *
 * Written by Alexander Haase, alexander.haase@rwth-aachen.de
 */

#include <stdio.h>

#include <omp.h>


int main()
{
#pragma omp parallel
  {
    printf("%d of %d\n", omp_get_thread_num() + 1, omp_get_num_threads());
  }

  return 0;
}


/* CMake-easytest configuration.
 *
 * CONFIGS: sort env
 *
 * COMPILE_FLAGS: @OpenMP_C_FLAGS@
 * LINK: @OpenMP_C_FLAGS@
 *
 *
 * ENVIRONMENT-sort: OMP_NUM_THREADS=4
 * RUN-sort: @BINARY@ | @sort@
 * PASS-sort: 1.*2.*3.*4
 *
 * ENVIRONMENT-env: OMP_NUM_THREADS=1
 * FAIL-env: 2
 */
