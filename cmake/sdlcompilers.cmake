macro(SDL_DetectCompiler)
  set(USE_CLANG FALSE)
  set(USE_GCC FALSE)
  set(USE_INTELCC FALSE)
  set(USE_QCC FALSE)
  set(USE_TCC FALSE)
  if(CMAKE_C_COMPILER_ID MATCHES "Clang|IntelLLVM")
    set(USE_CLANG TRUE)
    # Visual Studio 2019 v16.2 added support for Clang/LLVM.
    # Check if a Visual Studio project is being generated with the Clang toolset.
    if(MSVC)
      set(MSVC_CLANG TRUE)
    endif()
  elseif(CMAKE_COMPILER_IS_GNUCC)
    set(USE_GCC TRUE)
  elseif(CMAKE_C_COMPILER_ID MATCHES "^Intel$")
    set(USE_INTELCC TRUE)
  elseif(CMAKE_C_COMPILER_ID MATCHES "QCC")
    set(USE_QCC TRUE)
  elseif(CMAKE_C_COMPILER_ID MATCHES "TinyCC")
    set(USE_TCC TRUE)
  endif()
endmacro()

function(sdl_target_compile_option_all_languages TARGET OPTION)
  target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:${OPTION}>")
  if(CMAKE_OBJC_COMPILER)
    target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:OBJC>:${OPTION}>")
  endif()
endfunction()

function(sdl_target_compile_option_all_languages_enable TARGET OPTION)
  cached_check_c_compiler_flag(-W${OPTION} HAVE_COMPILER_OPTION_${OPTION})
  if(HAVE_COMPILER_OPTION_${OPTION})
    sdl_target_compile_option_all_languages(${TARGET} "-W${OPTION}")
  endif()
endfunction()

function(sdl_target_compile_option_all_languages_disable TARGET OPTION)
  cached_check_c_compiler_flag(-W${OPTION} HAVE_COMPILER_OPTION_${OPTION})
  if(HAVE_COMPILER_OPTION_${OPTION})
    target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:-Wno-${OPTION}>")
    if(CMAKE_OBJC_COMPILER)
      target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:OBJC>:-Wno-${OPTION}>")
    endif()
  endif()
endfunction()

function(sdl_target_compile_option_all_languages_disable_c TARGET OPTION)
  cached_check_c_compiler_flag(-W${OPTION} HAVE_COMPILER_OPTION_${OPTION})
  if(HAVE_COMPILER_OPTION_${OPTION})
    target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C>:-Wno-${OPTION}>")
    if(CMAKE_OBJC_COMPILER)
      target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:OBJC>:-Wno-${OPTION}>")
    endif()
  endif()
endfunction()

function(sdl_target_compile_option_all_languages_noerror TARGET OPTION)
  cached_check_c_compiler_flag(-W${OPTION} HAVE_COMPILER_OPTION_${OPTION})
  if(HAVE_COMPILER_OPTION_${OPTION})
    target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:-Wno-error=${OPTION}>")
    if(CMAKE_OBJC_COMPILER)
      target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:OBJC>:-Wno-error=${OPTION}>")
    endif()
  endif()
endfunction()

function(sdl_target_compile_option_all_languages_disable_msvc TARGET OPTION)
  target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:/wd${OPTION}>")
endfunction()

macro(cached_check_c_compiler_flag _arg _var)
  if(NOT DEFINED "${_var}")
    check_c_compiler_flag("${_arg}" "${_var}" ${ARGN})
  endif()
endmacro()

function(SDL_AddCommonCompilerFlags TARGET)
  option(SDL_WERROR "Enable -Werror" OFF)
  option(SDL_WPEDANTIC "Enable pedantic compile options - deactivates SDL_WERROR" OFF)
  if(SDL_WPEDANTIC AND SDL_WERROR)
    message(WARNING "SDL_WPEDANTIC deactivates SDL_WERROR")
    set(SDL_WERROR OFF CACHE BOOL "Enable -Werror" FORCE)
  endif()

  get_property(TARGET_TYPE TARGET "${TARGET}" PROPERTY TYPE)
  if(MSVC)
    cmake_push_check_state()
    cached_check_c_compiler_flag("/W3" COMPILER_SUPPORTS_W3)
    if(COMPILER_SUPPORTS_W3)
      target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:/W3>")
    endif()
    cmake_pop_check_state()
  endif()

  if(USE_GCC OR USE_CLANG OR USE_INTELCC OR USE_QCC OR USE_TCC)
    if(MINGW)
      # See if GCC's -gdwarf-4 is supported
      # See https://gcc.gnu.org/bugzilla/show_bug.cgi?id=101377 for why this is needed on Windows
      cmake_push_check_state()
      cached_check_c_compiler_flag("-gdwarf-4" HAVE_GDWARF_4)
      if(HAVE_GDWARF_4)
        target_compile_options(${TARGET} PRIVATE "$<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:-gdwarf-4>")
      endif()
      cmake_pop_check_state()
    endif()

    # Check for -Wall first, so later things can override pieces of it.
    # Note: clang-cl treats -Wall as -Weverything (which is very loud),
    #       /W3 as -Wall, and /W4 as -Wall -Wextra.  So: /W3 is enough.
    cached_check_c_compiler_flag(-Wall HAVE_GCC_WALL)
    if(MSVC_CLANG)
      target_compile_options(${TARGET} PRIVATE "/W3")
    elseif(HAVE_GCC_WALL)
      sdl_target_compile_option_all_languages(${TARGET} "-Wall")
      if(HAIKU)
        sdl_target_compile_option_all_languages(${TARGET} "-Wno-multichar")
      endif()
    endif()

    cached_check_c_compiler_flag(-Wundef HAVE_GCC_WUNDEF)
    if(HAVE_GCC_WUNDEF)
      sdl_target_compile_option_all_languages(${TARGET} "-Wundef")
    endif()

    cached_check_c_compiler_flag(-Wfloat-conversion HAVE_GCC_WFLOAT_CONVERSION)
    if(HAVE_GCC_WFLOAT_CONVERSION)
      sdl_target_compile_option_all_languages(${TARGET} "-Wfloat-conversion")
    endif()

    cached_check_c_compiler_flag(-fno-strict-aliasing HAVE_GCC_NO_STRICT_ALIASING)
    if(HAVE_GCC_NO_STRICT_ALIASING)
      sdl_target_compile_option_all_languages(${TARGET} "-fno-strict-aliasing")
    endif()

    cached_check_c_compiler_flag(-Wdocumentation HAVE_GCC_WDOCUMENTATION)
    if(HAVE_GCC_WDOCUMENTATION)
      if(SDL_WERROR)
        cached_check_c_compiler_flag(-Werror=documentation HAVE_GCC_WERROR_DOCUMENTATION)
        if(HAVE_GCC_WERROR_DOCUMENTATION)
          sdl_target_compile_option_all_languages(${TARGET} "-Werror=documentation")
        endif()
      endif()
      sdl_target_compile_option_all_languages(${TARGET} "-Wdocumentation")
    endif()

    cached_check_c_compiler_flag(-Wdocumentation-unknown-command HAVE_GCC_WDOCUMENTATION_UNKNOWN_COMMAND)
    if(HAVE_GCC_WDOCUMENTATION_UNKNOWN_COMMAND)
      if(SDL_WERROR)
        cached_check_c_compiler_flag(-Werror=documentation-unknown-command HAVE_GCC_WERROR_DOCUMENTATION_UNKNOWN_COMMAND)
        if(HAVE_GCC_WERROR_DOCUMENTATION_UNKNOWN_COMMAND)
          sdl_target_compile_option_all_languages(${TARGET} "-Werror=documentation-unknown-command")
        endif()
      endif()
      sdl_target_compile_option_all_languages(${TARGET} "-Wdocumentation-unknown-command")
    endif()

    cached_check_c_compiler_flag(-fcomment-block-commands=threadsafety HAVE_GCC_COMMENT_BLOCK_COMMANDS)
    if(HAVE_GCC_COMMENT_BLOCK_COMMANDS)
      sdl_target_compile_option_all_languages(${TARGET} "-fcomment-block-commands=threadsafety")
    else()
      cached_check_c_compiler_flag(/clang:-fcomment-block-commands=threadsafety HAVE_CLANG_COMMENT_BLOCK_COMMANDS)
      if(HAVE_CLANG_COMMENT_BLOCK_COMMANDS)
        sdl_target_compile_option_all_languages(${TARGET} "/clang:-fcomment-block-commands=threadsafety")
      endif()
    endif()

    cached_check_c_compiler_flag(-Wshadow HAVE_GCC_WSHADOW)
    if(HAVE_GCC_WSHADOW)
      sdl_target_compile_option_all_languages(${TARGET} "-Wshadow")
    endif()

    cached_check_c_compiler_flag(-Wunused-local-typedefs HAVE_GCC_WUNUSED_LOCAL_TYPEDEFS)
    if(HAVE_GCC_WUNUSED_LOCAL_TYPEDEFS)
      sdl_target_compile_option_all_languages(${TARGET} "-Wno-unused-local-typedefs")
    endif()

    cached_check_c_compiler_flag(-Wimplicit-fallthrough HAVE_GCC_WIMPLICIT_FALLTHROUGH)
    if(HAVE_GCC_WIMPLICIT_FALLTHROUGH)
      sdl_target_compile_option_all_languages(${TARGET} "-Wimplicit-fallthrough")
    endif()
  endif()

  if(SDL_WERROR)
    if(MSVC)
      cached_check_c_compiler_flag(/WX HAVE_WX)
      if(HAVE_WX)
        target_compile_options(${TARGET} PRIVATE "$<$<COMPILE_LANGUAGE:C,CXX>:/WX>")
      endif()
    elseif(USE_GCC OR USE_CLANG OR USE_INTELCC OR USE_QNX)
      cached_check_c_compiler_flag(-Werror HAVE_WERROR)
      if(HAVE_WERROR)
        sdl_target_compile_option_all_languages(${TARGET} "-Werror")
      endif()

      if(TARGET_TYPE STREQUAL "SHARED_LIBRARY")
        check_linker_flag(C "-Wl,--no-undefined-version" LINKER_SUPPORTS_NO_UNDEFINED_VERSION)
        if(LINKER_SUPPORTS_NO_UNDEFINED_VERSION)
          target_link_options(${TARGET} PRIVATE "-Wl,--no-undefined-version")
        endif()
      endif()
    endif()

    if(NOT (APPLE OR MSVC))
      if(SDL_WERROR)
        get_property(target_type TARGET ${TARGET} PROPERTY TYPE)
        if(target_type MATCHES "SHARED_LIBRARY|MODULE_LIBRARY")
          check_linker_flag(C "-Wl,-fatal-warnings" LINKER_SUPPORTS_WL_FATAL_WARNINGS)
          if(LINKER_SUPPORTS_WL_FATAL_WARNINGS)
            target_link_options(${TARGET} PRIVATE "-Wl,-fatal-warnings")
          endif()
        endif()
      endif()
    endif()
  endif()

  if(SDL_WPEDANTIC)
    if(USE_GCC OR USE_CLANG OR USE_INTELCC OR USE_QCC OR USE_TCC)
      sdl_target_compile_option_all_languages_enable(${TARGET} extra)
      sdl_target_compile_option_all_languages_enable(${TARGET} pedantic)
      sdl_target_compile_option_all_languages_enable(${TARGET} everything)

      if(HAVE_COMPILER_OPTION_pedantic)
        set(SDL_PEDANTIC 1)
      endif()

      sdl_target_compile_option_all_languages_disable_c(${TARGET} missing-variable-declarations)
      sdl_target_compile_option_all_languages_disable_c(${TARGET} declaration-after-statement)
      sdl_target_compile_option_all_languages_disable_c(${TARGET} bad-function-cast)
      sdl_target_compile_option_all_languages_disable(${TARGET} padded)
      sdl_target_compile_option_all_languages_disable(${TARGET} sign-compare)
      sdl_target_compile_option_all_languages_disable(${TARGET} sign-conversion)
      sdl_target_compile_option_all_languages_disable(${TARGET} double-promotion)
      sdl_target_compile_option_all_languages_disable(${TARGET} switch-default)
      sdl_target_compile_option_all_languages_disable(${TARGET} switch-enum)
      sdl_target_compile_option_all_languages_disable(${TARGET} format-nonliteral)
      sdl_target_compile_option_all_languages_disable(${TARGET} float-equal)
      sdl_target_compile_option_all_languages_disable(${TARGET} cast-align)
      sdl_target_compile_option_all_languages_disable(${TARGET} cast-qual)
      sdl_target_compile_option_all_languages_disable(${TARGET} alloca)
      sdl_target_compile_option_all_languages_disable(${TARGET} unused-macros)
      sdl_target_compile_option_all_languages_disable(${TARGET} unused-parameter)
      sdl_target_compile_option_all_languages_disable(${TARGET} unused-variable)
      sdl_target_compile_option_all_languages_disable(${TARGET} unused-function)
      sdl_target_compile_option_all_languages_disable(${TARGET} unused-but-set-variable)
      sdl_target_compile_option_all_languages_disable(${TARGET} missing-field-initializers)
      sdl_target_compile_option_all_languages_disable(${TARGET} vla)
      sdl_target_compile_option_all_languages_disable(${TARGET} type-limits)
      sdl_target_compile_option_all_languages_disable(${TARGET} unguarded-availability-new)
      sdl_target_compile_option_all_languages_disable(${TARGET} nonportable-system-include-path)
      sdl_target_compile_option_all_languages_disable(${TARGET} overflow)

      # Clang
      sdl_target_compile_option_all_languages_disable_c(${TARGET} jump-misses-init)
      sdl_target_compile_option_all_languages_disable_c(${TARGET} c++-compat)
      sdl_target_compile_option_all_languages_disable_c(${TARGET} missing-prototypes)
      sdl_target_compile_option_all_languages_disable_c(${TARGET} strict-prototypes)
      sdl_target_compile_option_all_languages_disable(${TARGET} assign-enum)
      sdl_target_compile_option_all_languages_disable(${TARGET} cast-function-type)
      sdl_target_compile_option_all_languages_disable(${TARGET} cast-function-type-strict)
      sdl_target_compile_option_all_languages_disable(${TARGET} implicit-int-float-conversion)
      sdl_target_compile_option_all_languages_disable(${TARGET} implicit-int-conversion)
      sdl_target_compile_option_all_languages_disable(${TARGET} implicit-int-enum-cast)
      sdl_target_compile_option_all_languages_disable(${TARGET} implicit-void-ptr-cast)
      sdl_target_compile_option_all_languages_disable(${TARGET} atomic-implicit-seq-cst)
      sdl_target_compile_option_all_languages_disable(${TARGET} covered-switch-default)
      sdl_target_compile_option_all_languages_disable(${TARGET} comma)
      sdl_target_compile_option_all_languages_disable(${TARGET} disabled-macro-expansion)
      sdl_target_compile_option_all_languages_disable(${TARGET} variadic-macros)
      sdl_target_compile_option_all_languages_disable(${TARGET} c99-extensions)
      sdl_target_compile_option_all_languages_disable(${TARGET} pre-c11-compat)
      sdl_target_compile_option_all_languages_disable(${TARGET} c23-extensions)
      sdl_target_compile_option_all_languages_disable(${TARGET} c++-keyword)
      sdl_target_compile_option_all_languages_disable(${TARGET} reserved-macro-identifier)
      sdl_target_compile_option_all_languages_disable(${TARGET} reserved-identifier)
      sdl_target_compile_option_all_languages_disable(${TARGET} unsafe-buffer-usage)
      sdl_target_compile_option_all_languages_disable(${TARGET} tautological-value-range-compare)
      sdl_target_compile_option_all_languages_disable(${TARGET} nrvo)
      sdl_target_compile_option_all_languages_disable(${TARGET} format)
      sdl_target_compile_option_all_languages_disable(${TARGET} format-non-iso)
      sdl_target_compile_option_all_languages_disable(${TARGET} format-pedantic)
      sdl_target_compile_option_all_languages_disable(${TARGET} constant-conversion)
      sdl_target_compile_option_all_languages_disable(${TARGET} string-conversion)
      sdl_target_compile_option_all_languages_disable(${TARGET} overlength-strings)
      sdl_target_compile_option_all_languages_disable(${TARGET} shift-sign-overflow)
      sdl_target_compile_option_all_languages_disable(${TARGET} long-long)
      sdl_target_compile_option_all_languages_disable(${TARGET} c++98-compat-pedantic)
      sdl_target_compile_option_all_languages_disable(${TARGET} unreachable-code-return)
      sdl_target_compile_option_all_languages_disable(${TARGET} unreachable-code-break)
      sdl_target_compile_option_all_languages_disable(${TARGET} flexible-array-extensions)
      sdl_target_compile_option_all_languages_disable(${TARGET} shadow-header)
      sdl_target_compile_option_all_languages_disable(${TARGET} tentative-definition-compat)
      sdl_target_compile_option_all_languages_disable(${TARGET} default-const-init-var)
      sdl_target_compile_option_all_languages_disable(${TARGET} extra-semi)
      sdl_target_compile_option_all_languages_disable(${TARGET} extra-semi-stmt)
      sdl_target_compile_option_all_languages_disable(${TARGET} newline-eof)
      # MinGW Clang
      sdl_target_compile_option_all_languages_disable(${TARGET} used-but-marked-unused)
      sdl_target_compile_option_all_languages_disable(${TARGET} four-char-constants)
      sdl_target_compile_option_all_languages_disable(${TARGET} gnu-zero-variadic-macro-arguments)
    endif()

    if(MSVC OR MSVC_CLANG)
      set(SDL_PEDANTIC 1)

      sdl_target_compile_option_all_languages(${TARGET} /Wall)
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4018) # token signed/unsigned mismatch
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4061) # enum value not handled in switch
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4100) # unused-parameter
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4125) # octal escape sequence
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4127) # conditional expression is constant
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4132) # const object should be initialized
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4152) # cast-function-type - non-standard extension
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4191) # cast-function-type - unsafe conversion
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4201) # anonymous structs /union
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4242) # implicit-conversion - opposite sign
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4244) # implicit-conversion - same sign
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4245) # implicit-conversion - init
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4255) # no-prototype
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4310) # cast truncates constant value
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4365) # implicit-conversion - argument
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4388) # sign-compare
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4389) # sign/unsigned mismatch
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4464) # relative include paths
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4514) # unreferenced inline function has been removed
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4548) # empty expression
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4668) # undef
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4701) # uninitialized local variable used
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4702) # unreachable code
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4710) # function not inlined
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4711) # function automatically inlined
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4746) # volatile
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4820) # padding
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 4917) # GUID can only be associated with class, interface or namespace (Windows headers)
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 5039) # exception handling - undefined behavior
      sdl_target_compile_option_all_languages_disable_msvc(${TARGET} 5045) # spectre
    endif()
  endif()

  if(USE_CLANG)
    cached_check_c_compiler_flag("-fcolor-diagnostics" COMPILER_SUPPORTS_FCOLOR_DIAGNOSTICS)
    if(COMPILER_SUPPORTS_FCOLOR_DIAGNOSTICS)
      sdl_target_compile_option_all_languages(${TARGET} "-fcolor-diagnostics")
    endif()
  else()
    cached_check_c_compiler_flag("-fdiagnostics-color=always" COMPILER_SUPPORTS_FDIAGNOSTICS_COLOR_ALWAYS)
    if(COMPILER_SUPPORTS_FDIAGNOSTICS_COLOR_ALWAYS)
      sdl_target_compile_option_all_languages(${TARGET} "-fdiagnostics-color=always")
    endif()
  endif()

  if(USE_TCC)
      sdl_target_compile_option_all_languages(${TARGET} "-DSTBI_NO_SIMD")
  endif()
endfunction()

function(check_x86_source_compiles BODY VAR)
  if(ARGN)
    message(FATAL_ERROR "Unknown arguments: ${ARGN}")
  endif()
  if(APPLE_MULTIARCH AND (SDL_CPU_X86 OR SDL_CPU_X64))
    set(test_conditional 1)
  else()
    set(test_conditional 0)
  endif()
  check_c_source_compiles("
    #if ${test_conditional}
    # if defined(__i386__) || defined(__x86_64__)
    #  define test_enabled 1
    # else
    #  define test_enabled 0 /* feign success in Apple multi-arch configs */
    # endif
    #else                    /* test normally */
    # define test_enabled 1
    #endif
    #if test_enabled
    ${BODY}
    #else
    int main(int argc, char *argv[]) {
      (void)argc;
      (void)argv;
      return 0;
    }
    #endif" ${VAR})
endfunction()

function(check_arm_source_compiles BODY VAR)
  if(ARGN)
    message(FATAL_ERROR "Unknown arguments: ${ARGN}")
  endif()
  if(APPLE_MULTIARCH AND (SDL_CPU_ARM32 OR SDL_CPU_ARM64))
    set(test_conditional 1)
  else()
    set(test_conditional 0)
  endif()
  check_c_source_compiles("
    #if ${test_conditional}
    # if defined(__arm__) || defined(__aarch64__)
    #  define test_enabled 1
    # else
    #  define test_enabled 0 /* feign success in Apple multi-arch configs */
    # endif
    #else                    /* test normally */
    # define test_enabled 1
    #endif
    #if test_enabled
    ${BODY}
    #else
    int main(int argc, char *argv[]) {
      (void)argc;
      (void)argv;
      return 0;
    }
    #endif" ${VAR})
endfunction()
