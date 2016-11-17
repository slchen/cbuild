macro(cbuild_config_user_predef)
 # Setup output Directories
 set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${cbuild_output_dir})
 set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${cbuild_output_dir})
 set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${cbuild_output_dir})

 if(option_enable_build_tests)
  if(MSVC)
   if(NOT (MSVC_VERSION GREATER 1900))
    # Suppress " warning C4819: The file contains a character that cannot be 
    # represented in the current code page (950). Save the file in Unicode 
    # format to prevent data loss"
    set(cxx_strict_flags "${cxx_strict_flags} -wd4819")
    # error C2338: <hash_map> is deprecated and will be REMOVED. Please use 
    # <unordered_map>. You can define _SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS 
    # to acknowledge that you have received this warning.
    set(cxx_strict_flags "${cxx_strict_flags} -wd5999")
    # warning C4297: 'CxxExceptionInDestructorTest::~CxxExceptionInDestructorTest': 
    # function assumed not to throw an exception but does note: destructor or 
    # deallocator has a (possibly implicit) non-throwing exception specification
    set(cxx_strict_flags "${cxx_strict_flags} -wd4297")
   endif()
  endif()
 endif()
endmacro()
