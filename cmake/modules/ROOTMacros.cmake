 ################################################################################
 #    Copyright (C) 2014 GSI Helmholtzzentrum fuer Schwerionenforschung GmbH    #
 #                                                                              #
 #              This software is distributed under the terms of the             #
 #              GNU Lesser General Public Licence (LGPL) version 3,             #
 #                  copied verbatim in the file "LICENSE"                       #
 ################################################################################
Function(Format _output input prefix suffix)

# DevNotes - input should be put in quotes or the complete list does not get passed to the function
  set(format)
  foreach(arg ${input})
    set(item ${arg})
    if(prefix)
      string(REGEX MATCH "^${prefix}" pre ${arg})
    endif(prefix)
    if(suffix)
      string(REGEX MATCH "${suffix}$" suf ${arg})
    endif(suffix)
    if(NOT pre)
      set(item "${prefix}${item}")
    endif(NOT pre)
    if(NOT suf)
      set(item "${item}${suffix}")
    endif(NOT suf)
    list(APPEND format ${item})
  endforeach(arg)
  set(${_output} ${format} PARENT_SCOPE)

endfunction(Format)


  ###########################################
  #
  #       Macros for building ROOT dictionary
  #
  ###########################################

Find_Program(ROOT_CINT_EXECUTABLE
  NAMES rootcint
  PATHS ${ROOT_BINDIR}
  NO_DEFAULT_PATH
  )

Macro(ROOT_GENERATE_DICTIONARY)

  # Macro to switch between the old implementation with parameters
  # and the new implementation without parameters.
  # For the new implementation some CMake variables has to be defined
  # before calling the macro.

  If(${ARGC} EQUAL 0)
#    Message("New Version")
    ROOT_GENERATE_DICTIONARY_NEW()
  Else(${ARGC} EQUAL 0)
    If(${ARGC} EQUAL 4)
#      Message("Old Version")
      ROOT_GENERATE_DICTIONARY_OLD("${ARGV0}" "${ARGV1}" "${ARGV2}" "${ARGV3}")
    Else(${ARGC} EQUAL 4)
      Message(FATAL_ERROR "Has to be implemented")
    EndIf(${ARGC} EQUAL 4)
  EndIf(${ARGC} EQUAL 0)

EndMacro(ROOT_GENERATE_DICTIONARY)

Macro(ROOT_GENERATE_DICTIONARY_NEW)

  # All Arguments needed for this new version of the macro are defined
  # in the parent scope, namely in the CMakeLists.txt of the submodule
  set(Int_LINKDEF ${LINKDEF})
  set(Int_DICTIONARY ${DICTIONARY})
  set(Int_LIB ${LIBRARY_NAME})

  set(Int_INC ${INCLUDE_DIRECTORIES} ${SYSTEM_INCLUDE_DIRECTORIES})
  set(Int_HDRS ${HDRS})
  set(Int_DEF ${DEFINITIONS})

  # Convert the values of the variable to a semi-colon separated list
  separate_arguments(Int_INC)
  separate_arguments(Int_HDRS)
  separate_arguments(Int_DEF)

  # Format neccesary arguments
  # Add -I and -D to include directories and definitions
  Format(Int_INC "${Int_INC}" "-I" "")
  Format(Int_DEF "${Int_DEF}" "-D" "")

  #---call rootcint / cling --------------------------------
  set(OUTPUT_FILES ${Int_DICTIONARY})

  If (CMAKE_SYSTEM_NAME MATCHES Linux)
    Set(MY_LD_LIBRARY_PATH ${ROOT_LIBRARY_DIR}:${_intel_lib_dirs}:$ENV{LD_LIBRARY_PATH})
  ElseIf(CMAKE_SYSTEM_NAME MATCHES Darwin)
    Set(MY_LD_LIBRARY_PATH ${ROOT_LIBRARY_DIR}:$ENV{DYLD_LIBRARY_PATH})
  EndIf()

  get_filename_component(script_name ${Int_DICTIONARY} NAME_WE)
  String(REPLACE ";" " " Int_DEF_STR "${Int_DEF}")
  String(REPLACE ";" " " Int_INC_STR "${Int_INC}")
  String(REPLACE ";" " " Int_HDRS_STR "${Int_HDRS}")

  Set(EXTRA_DICT_PARAMETERS "")
  If (ROOT_FOUND_VERSION GREATER 59999)

    Set(Int_ROOTMAPFILE ${LIBRARY_OUTPUT_PATH}/lib${Int_LIB}.rootmap)
    Set(Int_PCMFILE G__${Int_LIB}Dict_rdict.pcm)
    Set(OUTPUT_FILES ${OUTPUT_FILES} ${Int_PCMFILE} ${Int_ROOTMAPFILE})
    Set(EXTRA_DICT_PARAMETERS ${EXTRA_DICT_PARAMETERS}
         -rmf ${Int_ROOTMAPFILE}
        -rml ${Int_LIB}${CMAKE_SHARED_LIBRARY_SUFFIX})
    Set_Source_Files_Properties(${OUTPUT_FILES} PROPERTIES GENERATED TRUE)
    String(REPLACE ";" " " EXTRA_DICT_PARAMETERS_STR "${EXTRA_DICT_PARAMETERS}")

  EndIf()

  # We need some environment variables which are present when running cmake at the
  # time we run make. To pass the variables a script is created containing the
  # correct values for the needed variables

  IF(FAIRROOTPATH)
    Configure_File(${FAIRROOTPATH}/share/fairbase/cmake/scripts/generate_dictionary_root.sh.in
                   ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh
                  )
    #EXEC_PROGRAM(/bin/chmod ARGS "u+x ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh")
    execute_process(COMMAND /bin/chmod u+x ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh OUTPUT_QUIET)

  ELSE(FAIRROOTPATH)
    Configure_File(${PROJECT_SOURCE_DIR}/cmake/scripts/generate_dictionary_root.sh.in
                   ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh
                  )
  ENDIF(FAIRROOTPATH)


  If (ROOT_FOUND_VERSION GREATER 59999)
    Add_Custom_Command(OUTPUT  ${OUTPUT_FILES}
                       COMMAND ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh
                       COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_CURRENT_BINARY_DIR}/${Int_PCMFILE} ${LIBRARY_OUTPUT_PATH}/${Int_PCMFILE}
                       DEPENDS ${Int_HDRS} ${Int_LINKDEF}
                      )
    Install(FILES ${LIBRARY_OUTPUT_PATH}/${Int_PCMFILE} ${Int_ROOTMAPFILE} DESTINATION lib)
  Else()
    Add_Custom_Command(OUTPUT  ${OUTPUT_FILES}
                       COMMAND ${CMAKE_CURRENT_BINARY_DIR}/generate_dictionary_${script_name}.sh
                       DEPENDS ${Int_HDRS} ${Int_LINKDEF}
                      )
  EndIf()

endmacro(ROOT_GENERATE_DICTIONARY_NEW)


MACRO (ROOT_GENERATE_DICTIONARY_OLD INFILES LINKDEF_FILE OUTFILE INCLUDE_DIRS_IN)

  set(INCLUDE_DIRS)

  foreach (_current_FILE ${INCLUDE_DIRS_IN})
    set(INCLUDE_DIRS ${INCLUDE_DIRS} -I${_current_FILE})
  endforeach (_current_FILE ${INCLUDE_DIRS_IN})

#  Message("Definitions: ${DEFINITIONS}")
#  MESSAGE("INFILES: ${INFILES}")
#  MESSAGE("OutFILE: ${OUTFILE}")
#  MESSAGE("LINKDEF_FILE: ${LINKDEF_FILE}")
#  MESSAGE("INCLUDE_DIRS: ${INCLUDE_DIRS}")

  STRING(REGEX REPLACE "^(.*)\\.(.*)$" "\\1.h" bla "${OUTFILE}")
#  MESSAGE("BLA: ${bla}")
  SET (OUTFILES ${OUTFILE} ${bla})


  if (CMAKE_SYSTEM_NAME MATCHES Linux)
    ADD_CUSTOM_COMMAND(OUTPUT ${OUTFILES}
       COMMAND LD_LIBRARY_PATH=${ROOT_LIBRARY_DIR}:${_intel_lib_dirs} ROOTSYS=${ROOTSYS} ${ROOT_CINT_EXECUTABLE}
       ARGS -f ${OUTFILE} -c -DHAVE_CONFIG_H ${INCLUDE_DIRS} ${INFILES} ${LINKDEF_FILE} DEPENDS ${INFILES} ${LINKDEF_FILE})
  else (CMAKE_SYSTEM_NAME MATCHES Linux)
    if (CMAKE_SYSTEM_NAME MATCHES Darwin)
      ADD_CUSTOM_COMMAND(OUTPUT ${OUTFILES}
       COMMAND DYLD_LIBRARY_PATH=${ROOT_LIBRARY_DIR} ROOTSYS=${ROOTSYS} ${ROOT_CINT_EXECUTABLE}
       ARGS -f ${OUTFILE} -c -DHAVE_CONFIG_H ${INCLUDE_DIRS} ${INFILES} ${LINKDEF_FILE} DEPENDS ${INFILES} ${LINKDEF_FILE})
    endif (CMAKE_SYSTEM_NAME MATCHES Darwin)
  endif (CMAKE_SYSTEM_NAME MATCHES Linux)

ENDMACRO (ROOT_GENERATE_DICTIONARY_OLD)

MACRO (GENERATE_ROOT_TEST_SCRIPT SCRIPT_FULL_NAME)

  get_filename_component(path_name ${SCRIPT_FULL_NAME} PATH)
  get_filename_component(file_extension ${SCRIPT_FULL_NAME} EXT)
  get_filename_component(file_name ${SCRIPT_FULL_NAME} NAME_WE)
  set(shell_script_name "${file_name}.sh")

  #MESSAGE("PATH: ${path_name}")
  #MESSAGE("Ext: ${file_extension}")
  #MESSAGE("Name: ${file_name}")
  #MESSAGE("Shell Name: ${shell_script_name}")

  string(REPLACE ${PROJECT_SOURCE_DIR}
         ${PROJECT_BINARY_DIR} new_path ${path_name}
        )

  #MESSAGE("New PATH: ${new_path}")

  file(MAKE_DIRECTORY ${new_path}/data)

  CONVERT_LIST_TO_STRING(${LD_LIBRARY_PATH})
  set(MY_LD_LIBRARY_PATH ${output})

  CONVERT_LIST_TO_STRING(${ROOT_INCLUDE_PATH})
  set(MY_ROOT_INCLUDE_PATH ${output})

  set(my_script_name ${SCRIPT_FULL_NAME})

  Write_Geant4Data_Variables_sh()
  IF(FAIRROOTPATH)
    configure_file(${FAIRROOTPATH}/share/fairbase/cmake/scripts/root_macro.sh.in
                   ${new_path}/${shell_script_name}
                  )
  ELSE(FAIRROOTPATH)
    configure_file(${PROJECT_SOURCE_DIR}/cmake/scripts/root_macro.sh.in
                   ${new_path}/${shell_script_name}
                  )
  ENDIF(FAIRROOTPATH)
  execute_process(COMMAND /bin/chmod u+x ${new_path}/${shell_script_name} OUTPUT_QUIET)

ENDMACRO (GENERATE_ROOT_TEST_SCRIPT)


Macro(ROOT_GENERATE_ROOTMAP)

  # All Arguments needed for this new version of the macro are defined
  # in the parent scope, namely in the CMakeLists.txt of the submodule
  if (DEFINED LINKDEF)
    foreach(l ${LINKDEF})
      If( IS_ABSOLUTE ${l})
        Set(Int_LINKDEF ${Int_LINKDEF} ${l})
      Else( IS_ABSOLUTE ${l})
        Set(Int_LINKDEF ${Int_LINKDEF} ${CMAKE_CURRENT_SOURCE_DIR}/${l})
      EndIf( IS_ABSOLUTE ${l})
    endforeach()

    foreach(d ${DEPENDENCIES})
      get_filename_component(_ext ${d} EXT)
      If(NOT _ext MATCHES a$)
        if(_ext)
          set(Int_DEPENDENCIES ${Int_DEPENDENCIES} ${d})
        else()
          set(Int_DEPENDENCIES ${Int_DEPENDENCIES} lib${d}.so)
        endif()
      Else()
        Message("Found Static library with extension ${_ext}")
      EndIf()
    endforeach()

    set(Int_LIB ${LIBRARY_NAME})
    set(Int_OUTFILE ${LIBRARY_OUTPUT_PATH}/lib${Int_LIB}.rootmap)

    add_custom_command(OUTPUT ${Int_OUTFILE}
                       COMMAND ${RLIBMAP_EXECUTABLE} -o ${Int_OUTFILE} -l ${Int_LIB}
                               -d ${Int_DEPENDENCIES} -c ${Int_LINKDEF}
                       DEPENDS ${Int_LINKDEF} ${RLIBMAP_EXECUTABLE} )
    add_custom_target( lib${Int_LIB}.rootmap ALL DEPENDS  ${Int_OUTFILE})
    set_target_properties(lib${Int_LIB}.rootmap PROPERTIES FOLDER RootMaps )
    #---Install the rootmap file------------------------------------
    #install(FILES ${Int_OUTFILE} DESTINATION lib COMPONENT libraries)
    install(FILES ${Int_OUTFILE} DESTINATION lib)
  endif(DEFINED LINKDEF)
EndMacro(ROOT_GENERATE_ROOTMAP)

Macro(GENERATE_LIBRARY)

  # TODO: remove this backwards-compatibility check when no longer needed
  if(DEFINED FAIRROOT_LIBRARY_PROPERTIES AND NOT DEFINED PROJECT_LIBRARY_PROPERTIES)
    set(PROJECT_LIBRARY_PROPERTIES ${FAIRROOT_LIBRARY_PROPERTIES})
  endif()

  set(Int_LIB ${LIBRARY_NAME})

  Set(HeaderRuleName "${Int_LIB}_HEADER_RULES")
  Set(DictName "G__${Int_LIB}Dict.cxx")

  If(NOT DICTIONARY)
    Set(DICTIONARY ${CMAKE_CURRENT_BINARY_DIR}/${DictName})
  EndIf(NOT DICTIONARY)

  If( IS_ABSOLUTE ${DICTIONARY})
    Set(DICTIONARY ${DICTIONARY})
  Else( IS_ABSOLUTE ${DICTIONARY})
    Set(Int_DICTIONARY ${CMAKE_CURRENT_SOURCE_DIR}/${DICTIONARY})
  EndIf( IS_ABSOLUTE ${DICTIONARY})

  Set(Int_SRCS ${SRCS})

  If(HEADERS)
    Set(HDRS ${HEADERS})
  Else(HEADERS)
    CHANGE_FILE_EXTENSION(*.cxx *.h HDRS "${SRCS}")
  EndIf(HEADERS)

  If(IWYU_FOUND)
    Set(_INCLUDE_DIRS ${INCLUDE_DIRECTORIES} ${SYSTEM_INCLUDE_DIRECTORIES})
    CHECK_HEADERS("${Int_SRCS}" "${_INCLUDE_DIRS}" ${HeaderRuleName})
  EndIf(IWYU_FOUND)

  install(FILES ${HDRS} DESTINATION include)

  If(LINKDEF)
    If( IS_ABSOLUTE ${LINKDEF})
      Set(Int_LINKDEF ${LINKDEF})
    Else( IS_ABSOLUTE ${LINKDEF})
      Set(Int_LINKDEF ${CMAKE_CURRENT_SOURCE_DIR}/${LINKDEF})
    EndIf( IS_ABSOLUTE ${LINKDEF})
    ROOT_GENERATE_DICTIONARY()
    SET(Int_SRCS ${Int_SRCS} ${DICTIONARY})
    SET_SOURCE_FILES_PROPERTIES(${DICTIONARY}
       PROPERTIES COMPILE_FLAGS "-Wno-old-style-cast"
    )
  EndIf(LINKDEF)


  If (ROOT_FOUND_VERSION LESS 59999)
    ROOT_GENERATE_ROOTMAP()
  EndIf()

  set(Int_DEPENDENCIES)
  foreach(d ${DEPENDENCIES})
    get_filename_component(_ext ${d} EXT)
    If(NOT _ext MATCHES a$)
      set(Int_DEPENDENCIES ${Int_DEPENDENCIES} ${d})
    Else()
      Message("Found Static library with extension ${_ext}")
      get_filename_component(_lib ${d} NAME_WE)
      set(Int_DEPENDENCIES ${Int_DEPENDENCIES} ${_lib})
    EndIf()
  endforeach()

  ############### build the library #####################
  If(${CMAKE_GENERATOR} MATCHES Xcode)
    Add_Library(${Int_LIB} SHARED ${Int_SRCS} ${NO_DICT_SRCS} ${HDRS} ${LINKDEF})
  Else()
    Add_Library(${Int_LIB} SHARED ${Int_SRCS} ${NO_DICT_SRCS} ${LINKDEF})
  EndIf()
  target_link_libraries(${Int_LIB} ${Int_DEPENDENCIES})
  set_target_properties(${Int_LIB} PROPERTIES ${PROJECT_LIBRARY_PROPERTIES})

  ############### install the library ###################
  install(TARGETS ${Int_LIB} DESTINATION lib)

  Set(LIBRARY_NAME)
  Set(DICTIONARY)
  Set(LINKDEF)
  Set(SRCS)
  Set(HEADERS)
  Set(NO_DICT_SRCS)
  Set(DEPENDENCIES)

EndMacro(GENERATE_LIBRARY)


Macro(GENERATE_EXECUTABLE)

#  If(IWYU_FOUND)
#    Set(HeaderRuleName "${EXE_NAME}_HEADER_RULES")
#    CHECK_HEADERS("${SRCS}" "${INCLUDE_DIRECTORIES}" ${HeaderRuleName})
#  EndIf(IWYU_FOUND)

  ############### build the library #####################
  Add_Executable(${EXE_NAME} ${SRCS})
  target_link_libraries(${EXE_NAME} ${DEPENDENCIES})

  ############### install the library ###################
  if(DEFINED BIN_DESTINATION)
    install(TARGETS ${EXE_NAME} DESTINATION ${BIN_DESTINATION})
  else(DEFINED BIN_DESTINATION)
    install(TARGETS ${EXE_NAME} DESTINATION bin)
  endif(DEFINED BIN_DESTINATION)

  Set(EXE_NAME)
  Set(SRCS)
  Set(DEPENDENCIES)

EndMacro(GENERATE_EXECUTABLE)
