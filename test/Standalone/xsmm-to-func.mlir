// RUN: standalone-opt %s -convert-xsmm-to-func -split-input-file | FileCheck %s

// CHECK: func.func private @xsmm_matmul_dispatch(i64, i64, i64, i64, i64, i64) -> i64 attributes {llvm.emit_c_interface}
// CHECK: func.func private @xsmm_identity_dispatch(i64, i64, i64, i64, i64, i64) -> i64 attributes {llvm.emit_c_interface}
func.func @dispatch_matmul() {
  %0 = xsmm.unary.dispatch identity [5, 6, 5, 6](bcast_row)
  %1 = xsmm.ternary.dispatch matmul [3, 3, 3, 3, 3, 3]
  return 
}