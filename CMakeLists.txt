########################################################################
# CMake build script
#

########################################################################
# Minimum version
#
cmake_minimum_required(VERSION 3.2)

########################################################################
# Remove cache
#
EXEC_PROGRAM(rm ARGS -rf "${CMAKE_BINARY_DIR}/CMakeCache.txt")

message(STATUS "Remove ${CMAKE_BINARY_DIR}/CMakeCache.txt")

########################################################################
# Options
#

# BUILD_SHARED_LIBS is a standard CMake variable, but we declare it here to
# make it prominent in the GUI.
option(BUILD_SHARED_LIBS "Build shared libraries (DLLs)." OFF)
option(option_enable_user_project_name "Using user defined project naem" OFF)
option(option_enable_user_include_directories "Using user defined include directories." OFF)
option(option_enable_user_source_directories "Using user defined source directories." OFF)
option(option_enable_user_library_directories "Using user defined library directories." OFF)
option(option_enable_user_test_directories "Using user defined test directories." OFF)
option(option_enable_user_output_directory "Using user defined output directory." OFF)
option(option_enable_build_library "Build project as library" ON)
option(option_enable_build_tests "Build all tests." OFF)

########################################################################
# Helpers
#
# Define helper functions and macros
include(cmake/internal_utils.cmake)

set(cbuild_project_name "Project" CACHE STRING "Enter the project name")
set(cbuild_include_dirs "inc" CACHE STRING "Enter the include directories")
set(cbuild_source_dirs "src" CACHE STRING "Enter the source directories")
set(cbuild_library_dirs "lib" CACHE STRING "Enter the library directories")
set(cbuild_test_dirs "test" CACHE STRING "Enter the test directories")
set(cbuild_output_dir "bin" CACHE STRING "Enter the output directory(one)")

########################################################################
# Name of the project
#
if(NOT option_enable_user_project_name)
 cbuild_get_prject_name(cbuild_project_name)
 message(STATUS "change cbuild_project_name = ${cbuild_project_name}")
endif()

project(${cbuild_project_name} C CXX)
message(STATUS "  PROJECT_NAME = " ${PROJECT_NAME})

########################################################################
# Download google test and google mock libraries
#
if(option_enable_build_tests)
 if(NOT cbuild_source_list)
  cbuild_download_gtest_and_gmock(ON)
 else()
  cbuild_download_gtest_and_gmock(OFF)
 endif()
endif()

########################################################################
# Setting compiler and linker
#
# Defines user_predef().
include(cmake/user_predef.cmake OPTIONAL)

if (COMMAND cbuild_config_user_predef)
 cbuild_config_user_predef()
endif()

cbuild_config_compiler_and_linker()

########################################################################
# Include directories
#

# Include header paths
if(option_enable_user_include_directories)
 foreach(inc_dir ${cbuild_include_dirs})
  include_directories(${CMAKE_SOURCE_DIR}/${inc_dir})
  message(STATUS "include header path = ${CMAKE_SOURCE_DIR}/${inc_dir}")
 endforeach()
else()
 include_directories(${CMAKE_SOURCE_DIR}/inc)
 message(STATUS "include header path = ${CMAKE_SOURCE_DIR}/inc")
endif()

# Include source paths and get source files
set(cbuild_source_list "")
if(option_enable_user_source_directories)
 foreach(src_dir ${cbuild_source_dirs})
  include_directories(${CMAKE_SOURCE_DIR}/${src_dir})
  message(STATUS "include source path = ${CMAKE_SOURCE_DIR}/${src_dir}")
  set(src_file "")
  aux_source_directory(${CMAKE_SOURCE_DIR}/${src_dir} src_file)
  message(STATUS "add source file = ${src_file}")
  list(APPEND cbuild_source_list ${src_file})
 endforeach()
else()
 include_directories(${CMAKE_SOURCE_DIR}/src)
 message(STATUS "include source path = ${CMAKE_SOURCE_DIR}/src")
 set(src_file "")
 aux_source_directory(${CMAKE_SOURCE_DIR}/src src_file)
 message(STATUS "add source file = ${src_file}")
 list(APPEND cbuild_source_list ${src_file})
endif()

# Get library files
set(cbuild_library_list "")
if(option_enable_user_library_directories)
 foreach(lib_dir ${cbuild_library_dirs})
  set(lib_file "")
  aux_source_directory(${CMAKE_SOURCE_DIR}/${lib_dir} lib_file)
  message(STATUS "add library file = ${lib_file}")
  list(APPEND cbuild_library_list ${lib_file})
 endforeach()
else()
 set(lib_file "")
 aux_source_directory(${CMAKE_SOURCE_DIR}/lib lib_file)
 message(STATUS "add library file = ${lib_file}")
 list(APPEND cbuild_library_list ${lib_file})
endif()

# Include test paths and get test files
set(cbuild_test_list "")
if(option_enable_build_tests)
 if(option_enable_user_test_directories)
  foreach(test_dir ${cbuild_test_dirs})
   include_directories(${CMAKE_SOURCE_DIR}/${test_dir})
   message(STATUS "include test path = ${CMAKE_SOURCE_DIR}/${test_dir}")
   set(test_file "")
   aux_source_directory(${CMAKE_SOURCE_DIR}/${test_dir} test_file)
   message(STATUS "add test file = ${test_file}")
   list(APPEND cbuild_test_list ${test_file})
  endforeach()
 else()
  include_directories(${CMAKE_SOURCE_DIR}/test)
  message(STATUS "include test path = ${CMAKE_SOURCE_DIR}/test")
  set(test_file "")
  aux_source_directory(${CMAKE_SOURCE_DIR}/test test_file)
  message(STATUS "add test file = ${test_file}")
  list(APPEND cbuild_test_list ${test_file})
 endif()
endif()

########################################################################
# Build project
#
if(cbuild_source_list)
 if(option_enable_build_library)
  # build library
  cbuild_library(
   NAME          ${PROJECT_NAME}
   COMPILE_FLAGS "-DMODULE_API_EXPORTS=1 ${cbuild_cxx_strict}"
   EXTERNAL_LIBS ${cbuild_library_list}
   SOURCE_FILES  ${cbuild_source_list}
  )
 else()
  # build executable
  cbuild_executable(
   NAME          ${PROJECT_NAME}
   EXTERNAL_LIBS ${cbuild_library_list}
   SOURCE_FILES  ${cbuild_source_list}
  )
 endif()

 # Build test
 if(option_enable_build_tests)
  # enable testing
  enable_testing()

  # set test taget external libraries list
  if(option_enable_build_library)
   set(cbuild_test_library_list gtest_main ${PROJECT_NAME} ${cbuild_library_list})
  else()
   set(cbuild_test_library_list gtest ${cbuild_library_list})
  endif()

  # add tests
  foreach(test_src ${cbuild_test_list})
   # get test case's name
   get_filename_component(test_name ${test_src} NAME_WE)

   if(option_enable_build_library)
    # add test with project library
    cbuild_test(
     NAME              ${test_name}
     EXTERNAL_LIBS     ${cbuild_test_library_list}
     SOURCE_FILES      ${test_src}
     WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
    )
   else()
    # add test with project source files
    cbuild_test(
     NAME              ${test_name}
     EXTERNAL_LIBS     ${cbuild_test_library_list}
     SOURCE_FILES      ${test_src} ${cbuild_source_list}
     WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
    )
   endif()
  endforeach()
 endif()
else()
 message(STATUS "Empty source files, enable options to test googletest/googlemock")
endif()





