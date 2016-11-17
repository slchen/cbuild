########################################################################
# Get project name
#
macro(cbuild_get_prject_name name)
 get_filename_component(regex ${CMAKE_SOURCE_DIR} NAME)
 string(REGEX REPLACE "[^a-zA-Z0-9.-]" "_" regex ${regex})
 set(${name} ${regex})
endmacro()

########################################################################
# Download gteset and gmock.
#
include(cmake/add_dl_project.cmake)

macro(cbuild_download_gtest_and_gmock exclude)
 if(exclude)
  add_dl_project(
   PROJ           gtest_gmock
   GIT_REPOSITORY https://github.com/google/googletest.git
   GIT_TAG        master # Git branch name
   EXCLUDE_FROM_ALL
   INCLUDE_DIRS   googlemock/include googletest/include
  )
 else()
  add_dl_project(
   PROJ           gtest_gmock
   GIT_REPOSITORY https://github.com/google/googletest.git
   GIT_TAG        master # Git branch name
   INCLUDE_DIRS   googlemock/include googletest/include
  )
 endif()
endmacro()

########################################################################
# Configure compiler and linker
#
# Fix default compiler setting
macro(cbuild_set_default_compiler_settings)
 # For MSVC, CMake sets certain flags to defaults we want to override.
 # This replacement code is taken from sample in the CMake Wiki at
 # http://www.cmake.org/Wiki/CMake_FAQ#Dynamic_Replace.
 foreach(flag_var
  CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
  CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
  if (NOT BUILD_SHARED_LIBS)
    # When project is built as a shared library, it should also use
    # shared runtime libraries.  Otherwise, it may end up with multiple
    # copies of runtime library data in different modules, resulting in
    # hard-to-find crashes. When it is built as a static library, it is
    # preferable to use CRT as static libraries, as we don't have to rely
    # on CRT DLLs being available. CMake always defaults to using shared
    # CRT libraries, so we override that default here.
    if (${flag_var} MATCHES "/MD")
     string(REGEX REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endif()
  endif()
  # We prefer more strict warning checking for building Google Test.
  # Replaces /W3 with /W4 in defaults.
  string(REPLACE "/W3" "/W4" ${flag_var} "${${flag_var}}")
 endforeach()
endmacro()

macro(cbuild_config_compiler_and_linker)
 cbuild_set_default_compiler_settings()
 set(cbuild_cxx_base_flags "-GS -W4 -WX -wd4251 -wd4275 -nologo -J -Zi")
 if(MSVC)
  if(MSVC_VERSION LESS 1400)  # 1400 is Visual Studio 2005
   # Suppress spurious warnings MSVC 7.1 sometimes issues.
   # Forcing value to bool.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4800")
   # Copy constructor and assignment operator could not be generated.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4511 -wd4512")
   # Compatibility warnings not applicable to Google Test.
   # Resolved overload was found by argument-dependent lookup.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4675")
  endif()
  if(MSVC_VERSION LESS 1500)  # 1500 is Visual Studio 2008
   # Conditional expression is constant.
   # When compiling with /W4, we get several instances of C4127
   # (Conditional expression is constant). In our code, we disable that
   # warning on a case-by-case basis. However, on Visual Studio 2005,
   # the warning fires on std::list. Therefore on that compiler and earlier,
   # we disable the warning project-wide.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4127")
  endif()
  if (NOT (MSVC_VERSION LESS 1700))  # 1700 is Visual Studio 2012.
   # Suppress "unreachable code" warning on VS 2012 and later.
   # http://stackoverflow.com/questions/3232669 explains the issue.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4702")
  endif()
  if(NOT (MSVC_VERSION GREATER 1900))  # 1900 is Visual Studio 2015
   # BigObj required for tests.
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -bigobj")
   # Suppress " warning C4819: The file contains a character that cannot be 
   # represented in the current code page (950). Save the file in Unicode 
   # format to prevent data loss"
   set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -wd4819")
  endif()
  set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -D_UNICODE -DUNICODE -DWIN32 -D_WIN32")
  set(cbuild_cxx_base_flags "${cbuild_cxx_base_flags} -DSTRICT -DWIN32_LEAN_AND_MEAN")
  set(cbuild_cxx_exception_flags "-EHsc -D_HAS_EXCEPTIONS=1")
  set(cbuild_cxx_no_exception_flags "-D_HAS_EXCEPTIONS=0")
  set(cbuild_cxx_no_rtti_flags "-GR-")
 elseif(CMAKE_COMPILER_IS_GNUCXX)
  set(cbuild_cxx_base_flags "-Wall -Wshadow")
  set(cbuild_cxx_exception_flags "-fexceptions")
  set(cbuild_cxx_no_exception_flags "-fno-exceptions")
  # Until version 4.3.2, GCC doesn't define a macro to indicate
  # whether RTTI is enabled.  Therefore we define GTEST_HAS_RTTI
  # explicitly.
  set(cbuild_cxx_no_rtti_flags "-fno-rtti -DGTEST_HAS_RTTI=0")
  set(cbuild_cxx_strict_flags
    "-Wextra -Wno-unused-parameter -Wno-missing-field-initializers")
 endif()
 set(cbuild_cxx_exception
  "${CMAKE_CXX_FLAGS}  ${cbuild_cxx_base_flags} ${cbuild_cxx_exception_flags}")
 set(cbuild_cxx_no_exception
  "${CMAKE_CXX_FLAGS} ${cbuild_cxx_base_flags} ${cbuild_cxx_no_exception_flags}")
 set(cbuild_cxx_default "${cbuild_cxx_exception}")
 set(cbuild_cxx_no_rtti "${cbuild_cxx_default} ${cbuild_cxx_no_rtti_flags}")
 set(cbuild_cxx_strict "${cbuild_cxx_default} ${cbuild_cxx_strict_flags}")
endmacro()

########################################################################
# Helper functions for creating build targets.
#
# Build library
function(cbuild_library)
 message(STATUS "===================== cbuild_library() =======================")

 # parse arguments
 set(options "")
 set(oneValueArgs NAME COMPILE_FLAGS)
 set(multiValueArgs EXTERNAL_LIBS SOURCE_FILES)
 cmake_parse_arguments(cbuild_library "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

 message(STATUS "NAME: ${cbuild_library_NAME}")
 message(STATUS "TYPE: ${cbuild_library_TYPE}")
 message(STATUS "COMPILE_FLAGS: ${cbuild_library_COMPILE_FLAGS}")
 message(STATUS "EXTERNAL_LIBS: ${cbuild_library_EXTERNAL_LIBS}")
 message(STATUS "SOURCE_FILES: ${cbuild_library_SOURCE_FILES}")

 # add library
 if(cbuild_library_TYPE)
  add_library(${cbuild_library_NAME} ${cbuild_library_TYPE} ${cbuild_library_SOURCE_FILES})
 else()
  add_library(${cbuild_library_NAME} ${cbuild_library_SOURCE_FILES})
 endif()
 message(STATUS "add library: ${cbuild_library_NAME}")

 # set compile flags
 if(cbuild_library_COMPILE_FLAGS)
  set_target_properties(${cbuild_library_NAME} PROPERTIES COMPILE_FLAGS "${cbuild_library_COMPILE_FLAGS}")
  message(STATUS "set PROPERTIES COMPILE_FLAGS: ${cbuild_library_COMPILE_FLAGS}")
 else()
  set_target_properties(${cbuild_library_NAME} PROPERTIES COMPILE_FLAGS "${cbuild_cxx_strict}")
  message(STATUS "set PROPERTIES COMPILE_FLAGS: ${cbuild_cxx_strict}")
 endif()

 # link external libraries
 foreach(lib ${cbuild_library_EXTERNAL_LIBS})
  target_link_libraries(${cbuild_library_NAME} ${lib})
  message(STATUS "link: ${lib}")
 endforeach()
endfunction()

# Build excutable
function(cbuild_executable)
 message(STATUS "===================== cbuild_executable() =======================")

 # parse arguments
 set(options "")
 set(oneValueArgs NAME COMPILE_FLAGS)
 set(multiValueArgs EXTERNAL_LIBS SOURCE_FILES DEPENDENCIES)
 cmake_parse_arguments(cbuild_executable "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

 message(STATUS "NAME: ${cbuild_executable_NAME}")
 message(STATUS "COMPILE_FLAGS: ${cbuild_executable_COMPILE_FLAGS}")
 message(STATUS "EXTERNAL_LIBS: ${cbuild_executable_EXTERNAL_LIBS}")
 message(STATUS "SOURCE_FILES: ${cbuild_executable_SOURCE_FILES}")
 message(STATUS "DEPENDENCIES: ${cbuild_executable_DEPENDENCIES}")

 # add executable
 add_executable(${cbuild_executable_NAME} ${cbuild_executable_SOURCE_FILES})
 message(STATUS "add executable: ${cbuild_executable_NAME}")

 # set compile flags
 if (cbuild_executable_COMPILE_FLAGS)
  set_target_properties(${cbuild_executable_NAME} PROPERTIES COMPILE_FLAGS "${cbuild_executable_COMPILE_FLAGS}")
  message(STATUS "set PROPERTIES COMPILE_FLAGS: ${cbuild_executable_COMPILE_FLAGS}")
 else()
  set_target_properties(${cbuild_executable_NAME} PROPERTIES COMPILE_FLAGS "${cbuild_cxx_default}")
  message(STATUS "set PROPERTIES COMPILE_FLAGS: ${cbuild_cxx_default}")
 endif()

 # link libraries
 foreach(lib "${cbuild_executable_EXTERNAL_LIBS}")
  target_link_libraries(${cbuild_executable_NAME} ${lib})
  message(STATUS "link: ${lib}")
 endforeach()
endfunction()

# Build test
function(cbuild_test)
 message(STATUS "===================== cbuild_test() =======================")

 # parse arguments
 set(options "")
 set(oneValueArgs NAME COMPILE_FLAGS WORKING_DIRECTORY)
 set(multiValueArgs EXTERNAL_LIBS SOURCE_FILES)
 cmake_parse_arguments(cbuild_test "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

 cbuild_executable(
  NAME          ${cbuild_test_NAME}
  COMPILE_FLAGS ${cbuild_test_COMPILE_FLAGS}
  EXTERNAL_LIBS ${cbuild_test_EXTERNAL_LIBS}
  SOURCE_FILES  ${cbuild_test_SOURCE_FILES}
 )

 add_test(
  NAME              ${cbuild_test_NAME}
  COMMAND           ${cbuild_test_NAME}
  WORKING_DIRECTORY ${cbuild_test_WORKING_DIRECTORY}
 )
 message(STATUS "add test: ${cbuild_test_NAME} in ${cbuild_test_WORKING_DIRECTORY}")
endfunction()

