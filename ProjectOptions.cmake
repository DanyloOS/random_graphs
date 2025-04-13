include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(random_graphs_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(random_graphs_setup_options)
  option(random_graphs_ENABLE_HARDENING "Enable hardening" ON)
  option(random_graphs_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    random_graphs_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    random_graphs_ENABLE_HARDENING
    OFF)

  random_graphs_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR random_graphs_PACKAGING_MAINTAINER_MODE)
    option(random_graphs_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(random_graphs_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(random_graphs_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(random_graphs_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(random_graphs_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(random_graphs_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(random_graphs_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(random_graphs_ENABLE_PCH "Enable precompiled headers" OFF)
    option(random_graphs_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(random_graphs_ENABLE_IPO "Enable IPO/LTO" ON)
    option(random_graphs_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(random_graphs_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(random_graphs_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(random_graphs_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(random_graphs_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(random_graphs_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(random_graphs_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(random_graphs_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(random_graphs_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(random_graphs_ENABLE_PCH "Enable precompiled headers" OFF)
    option(random_graphs_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      random_graphs_ENABLE_IPO
      random_graphs_WARNINGS_AS_ERRORS
      random_graphs_ENABLE_USER_LINKER
      random_graphs_ENABLE_SANITIZER_ADDRESS
      random_graphs_ENABLE_SANITIZER_LEAK
      random_graphs_ENABLE_SANITIZER_UNDEFINED
      random_graphs_ENABLE_SANITIZER_THREAD
      random_graphs_ENABLE_SANITIZER_MEMORY
      random_graphs_ENABLE_UNITY_BUILD
      random_graphs_ENABLE_CLANG_TIDY
      random_graphs_ENABLE_CPPCHECK
      random_graphs_ENABLE_COVERAGE
      random_graphs_ENABLE_PCH
      random_graphs_ENABLE_CACHE)
  endif()

  random_graphs_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (random_graphs_ENABLE_SANITIZER_ADDRESS OR random_graphs_ENABLE_SANITIZER_THREAD OR random_graphs_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(random_graphs_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(random_graphs_global_options)
  if(random_graphs_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    random_graphs_enable_ipo()
  endif()

  random_graphs_supports_sanitizers()

  if(random_graphs_ENABLE_HARDENING AND random_graphs_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR random_graphs_ENABLE_SANITIZER_UNDEFINED
       OR random_graphs_ENABLE_SANITIZER_ADDRESS
       OR random_graphs_ENABLE_SANITIZER_THREAD
       OR random_graphs_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${random_graphs_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${random_graphs_ENABLE_SANITIZER_UNDEFINED}")
    random_graphs_enable_hardening(random_graphs_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(random_graphs_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(random_graphs_warnings INTERFACE)
  add_library(random_graphs_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  random_graphs_set_project_warnings(
    random_graphs_warnings
    ${random_graphs_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(random_graphs_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    random_graphs_configure_linker(random_graphs_options)
  endif()

  include(cmake/Sanitizers.cmake)
  random_graphs_enable_sanitizers(
    random_graphs_options
    ${random_graphs_ENABLE_SANITIZER_ADDRESS}
    ${random_graphs_ENABLE_SANITIZER_LEAK}
    ${random_graphs_ENABLE_SANITIZER_UNDEFINED}
    ${random_graphs_ENABLE_SANITIZER_THREAD}
    ${random_graphs_ENABLE_SANITIZER_MEMORY})

  set_target_properties(random_graphs_options PROPERTIES UNITY_BUILD ${random_graphs_ENABLE_UNITY_BUILD})

  if(random_graphs_ENABLE_PCH)
    target_precompile_headers(
      random_graphs_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(random_graphs_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    random_graphs_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(random_graphs_ENABLE_CLANG_TIDY)
    random_graphs_enable_clang_tidy(random_graphs_options ${random_graphs_WARNINGS_AS_ERRORS})
  endif()

  if(random_graphs_ENABLE_CPPCHECK)
    random_graphs_enable_cppcheck(${random_graphs_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(random_graphs_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    random_graphs_enable_coverage(random_graphs_options)
  endif()

  if(random_graphs_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(random_graphs_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(random_graphs_ENABLE_HARDENING AND NOT random_graphs_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR random_graphs_ENABLE_SANITIZER_UNDEFINED
       OR random_graphs_ENABLE_SANITIZER_ADDRESS
       OR random_graphs_ENABLE_SANITIZER_THREAD
       OR random_graphs_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    random_graphs_enable_hardening(random_graphs_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
