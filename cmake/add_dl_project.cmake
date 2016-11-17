# https://github.com/ajneu/global_mock

cmake_minimum_required(VERSION 2.8.2)

include(CMakeParseArguments)

set(DIR_OF_add_dl_project ${CMAKE_CURRENT_LIST_DIR})

function(add_dl_project)
 set(EXTERN_DIR "${CMAKE_BINARY_DIR}/external_proj") ## has to match with variable in add_dl_project.CMakeLists.cmake.in

 # Set up named macro arguments
 set(options        EXCLUDE_FROM_ALL)
 set(oneValueArgs   PROJ URL URL_HASH GIT_REPOSITORY GIT_TAG)
 set(multiValueArgs INCLUDE_DIRS PATCH_COMMAND)
 cmake_parse_arguments(DL_ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

 # Create and build a separate CMake project to carry out the download.
 # If we've already previously done these steps, they will not cause
 # anything to be updated, so extra rebuilds of the project won't occur.
 configure_file(${DIR_OF_add_dl_project}/add_dl_project.CMakeLists.cmake.in ${EXTERN_DIR}/${DL_ARGS_PROJ}-download/CMakeLists.txt)
 execute_process(COMMAND ${CMAKE_COMMAND} -G "${CMAKE_GENERATOR}" .
                 WORKING_DIRECTORY ${EXTERN_DIR}/${DL_ARGS_PROJ}-download
 )
 execute_process(COMMAND ${CMAKE_COMMAND} --build .
                 WORKING_DIRECTORY ${EXTERN_DIR}/${DL_ARGS_PROJ}-download
 )

 # Now add the downloaded source directory to the build as normal.
 # The EXCLUDE_FROM_ALL option is useful if you only want to build
 # the downloaded project if something in the main build needs it.
 if(DL_ARGS_EXCLUDE_FROM_ALL)
  set(EXCLUDE_FROM_ALL "EXCLUDE_FROM_ALL")
 else()
  unset(EXCLUDE_FROM_ALL)
 endif()

 # Prevent GoogleTest from overriding our compiler/linker options
 # when building with Visual Studio
 set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

 # add sub-dirs
 add_subdirectory(${EXTERN_DIR}/${DL_ARGS_PROJ}-src
                  ${EXTERN_DIR}/${DL_ARGS_PROJ}-build
                  ${EXCLUDE_FROM_ALL}
 )

 # include directories
 foreach(loop_inc_var ${DL_ARGS_INCLUDE_DIRS})
  #target_include_directories(gtest INTERFACE "${CMAKE_BINARY_DIR}/${DL_ARGS_PROJ}-src/${loop_inc_var}")
  include_directories("${EXTERN_DIR}/${DL_ARGS_PROJ}-src/${loop_inc_var}")
 endforeach()
endfunction()
