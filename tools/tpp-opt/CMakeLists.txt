set(CMAKE_COMPILE_WARNING_AS_ERROR ON)

get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)
get_property(conversion_libs GLOBAL PROPERTY MLIR_CONVERSION_LIBS)
get_property(extension_libs GLOBAL PROPERTY MLIR_EXTENSION_LIBS)

if(USE_OneDNN)
  set(ONEDNN_LIBS "tpp_dnnl_runner_utils")
endif()

if(DEFINED EXT_PATH)
  set(MLIR_CUSTOM_EXTENSION_LIBS MLIRMicrokernel MLIRMicrokernelTransforms)
endif()

set(LIBS
        ${dialect_libs}
        ${conversion_libs}
        ${extension_libs}
        MLIRToLLVMIRTranslationRegistration
        MLIROptLib
        TPPPipeline
        TPPRunner
        TPPTransforms
        tpp_xsmm_runner_utils
        ${ONEDNN_LIBS}
        TPPTestLib
        ${MLIR_CUSTOM_EXTENSION_LIBS}
        )
add_llvm_executable(tpp-opt tpp-opt.cpp)

llvm_update_compile_flags(tpp-opt)
target_link_libraries(tpp-opt PRIVATE ${LIBS})
install(TARGETS tpp-opt RUNTIME DESTINATION bin)
