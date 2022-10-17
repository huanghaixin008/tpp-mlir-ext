// Loop conversion
// RUN: tpp-opt %s -map-linalg-to-tpp -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map"  -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize -convert-linalg-to-tpp -convert-tpp-to-loops -arith-expand -convert-vector-to-scf -convert-scf-to-cf -convert-vector-to-llvm -convert-func-to-llvm -convert-memref-to-llvm -canonicalize -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN: -shared-libs=%llvmlirdir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

// XSMM conversion
// RUN: tpp-opt %s -map-linalg-to-tpp -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map"  -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize -convert-linalg-to-tpp -convert-tpp-to-xsmm -convert-xsmm-to-func -arith-expand -convert-vector-to-scf -convert-scf-to-cf -convert-vector-to-llvm -convert-func-to-llvm -convert-memref-to-llvm -canonicalize -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN: -shared-libs=%llvmlirdir/libmlir_c_runner_utils%shlibext,%standalonelibdir/libtpp_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

// Loop conversion
// RUN: tpp-opt %s -map-linalg-to-tpp -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map"  -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize -convert-linalg-to-tpp="tile-sizes=8,8" -convert-tpp-to-loops -arith-expand -convert-vector-to-scf -convert-scf-to-cf -convert-vector-to-llvm -convert-func-to-llvm -convert-memref-to-llvm -canonicalize -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN: -shared-libs=%llvmlirdir/libmlir_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

// XSMM conversion
// RUN: tpp-opt %s -map-linalg-to-tpp -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map"  -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize -convert-linalg-to-tpp="tile-sizes=8,8" -convert-tpp-to-xsmm -loop-invariant-code-motion -convert-xsmm-to-func -arith-expand -convert-vector-to-scf -convert-scf-to-cf -convert-vector-to-llvm -convert-func-to-llvm -convert-memref-to-llvm -canonicalize -reconcile-unrealized-casts | \
// RUN: mlir-cpu-runner \
// RUN:  -e entry -entry-point-result=void  \
// RUN: -shared-libs=%llvmlirdir/libmlir_c_runner_utils%shlibext,%standalonelibdir/libtpp_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

#map0 = affine_map<(d0, d1) -> (d0, d1)>

module {

  func.func @bigrelu(%B: tensor<32x16xf32>) -> tensor<32x16xf32> attributes {llvm.emit_c_interface} {
    %O = linalg.generic { indexing_maps = [#map0],
                        iterator_types = ["parallel", "parallel"] }
     outs(%B: tensor<32x16xf32>) {
        ^bb0(%b: f32):
          %0 = mathx.relu %b : f32
          linalg.yield %0: f32
      } -> tensor<32x16xf32>
    return %O: tensor<32x16xf32>
  }


  func.func @entry() {
    %c0 = arith.constant 0 : index
    %d1 = arith.constant -1.0 : f32

    %da = arith.constant dense<[
            
    [ 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1, 13.1, 14.1, 15.1, 16.1 ],
    [ 1.2, 2.2, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 9.2, 10.2, 11.2, 12.2, 13.2, 14.2, 15.2, 16.2 ],
    [ 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3, 8.3, 9.3, 10.3, 11.3, 12.3, 13.3, 14.3, 15.3, 16.3 ],
    [ 1.4, 2.4, 3.4, 4.4, 5.4, 6.4, 7.4, 8.4, 9.4, 10.4, 11.4, 12.4, 13.4, 14.4, 15.4, 16.4 ],
    [ 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5, 16.5 ],
    [ 1.6, 2.6, 3.6, 4.6, 5.6, 6.6, 7.6, 8.6, 9.6, 10.6, 11.6, 12.6, 13.6, 14.6, 15.6, 16.6 ],
    [ 1.7, 2.7, 3.7, 4.7, 5.7, 6.7, 7.7, 8.7, 9.7, 10.7, 11.7, 12.7, 13.7, 14.7, 15.7, 16.7 ],
    [ 1.8, 2.8, 3.8, 4.8, 5.8, 6.8, 7.8, 8.8, 9.8, 10.8, 11.8, 12.8, 13.8, 14.8, 15.8, 16.8 ],
    [ 1.9, 2.9, 3.9, 4.9, 5.9, 6.9, 7.9, 8.9, 9.9, 10.9, 11.9, 12.9, 13.9, 14.9, 15.9, 16.9 ],
    [ 1.10, 2.10, 3.10, 4.10, 5.10, 6.10, 7.10, 8.10, 9.10, 10.10, 11.10, 12.10, 13.10, 14.10, 15.10, 16.10 ],
    [ 1.11, 2.11, 3.11, 4.11, 5.11, 6.11, 7.11, 8.11, 9.11, 10.11, 11.11, 12.11, 13.11, 14.11, 15.11, 16.11 ],
    [ 1.12, 2.12, 3.12, 4.12, 5.12, 6.12, 7.12, 8.12, 9.12, 10.12, 11.12, 12.12, 13.12, 14.12, 15.12, 16.12 ],
    [ 1.13, 2.13, 3.13, 4.13, 5.13, 6.13, 7.13, 8.13, 9.13, 10.13, 11.13, 12.13, 13.13, 14.13, 15.13, 16.13 ],
    [ 1.14, 2.14, 3.14, 4.14, 5.14, 6.14, 7.14, 8.14, 9.14, 10.14, 11.14, 12.14, 13.14, 14.14, 15.14, 16.14 ],
    [ 1.15, 2.15, 3.15, 4.15, 5.15, 6.15, 7.15, 8.15, 9.15, 10.15, 11.15, 12.15, 13.15, 14.15, 15.15, 16.15 ],
    [ 1.16, 2.16, 3.16, 4.16, 5.16, 6.16, 7.16, 8.16, 9.16, 10.16, 11.16, 12.16, 13.16, 14.16, 15.16, 16.16 ],
    [ 1.17, 2.17, 3.17, 4.17, 5.17, 6.17, 7.17, 8.17, 9.17, 10.17, 11.17, 12.17, 13.17, 14.17, 15.17, 16.17 ],
    [ 1.18, 2.18, 3.18, 4.18, -5.18, -6.18, 7.18, 8.18, 9.18, 10.18, 11.18, 12.18, 13.18, 14.18, 15.18, 16.18 ],
    [ 1.19, 2.19, 3.19, 4.19, -5.19, -6.19, 7.19, 8.19, 9.19, 10.19, 11.19, 12.19, 13.19, 14.19, 15.19, 16.19 ],
    [ 1.20, 2.20, 3.20, 4.20, 5.20, 6.20, 7.20, 8.20, 9.20, 10.20, 11.20, 12.20, 13.20, 14.20, 15.20, 16.20 ],
    [ 1.21, 2.21, 3.21, 4.21, 5.21, 6.21, 7.21, 8.21, 9.21, 10.21, 11.21, 12.21, 13.21, 14.21, 15.21, 16.21 ],
    [ 1.22, 2.22, 3.22, 4.22, 5.22, 6.22, 7.22, 8.22, 9.22, 10.22, 11.22, 12.22, 13.22, 14.22, 15.22, 16.22 ],
    [ 1.23, 2.23, 3.23, 4.23, 5.23, 6.23, 7.23, 8.23, 9.23, 10.23, 11.23, 12.23, 13.23, 14.23, 15.23, 16.23 ],
    [ 1.24, 2.24, 3.24, 4.24, 5.24, 6.24, 7.24, 8.24, 9.24, 10.24, 11.24, 12.24, 13.24, 14.24, 15.24, 16.24 ],
    [ 1.25, 2.25, 3.25, 4.25, 5.25, 6.25, 7.25, 8.25, 9.25, 10.25, 11.25, 12.25, 13.25, 14.25, 15.25, 16.25 ],
    [ 1.26, 2.26, 3.26, 4.26, 5.26, 6.26, 7.26, 8.26, 9.26, 10.26, 11.26, 12.26, 13.26, 14.26, 15.26, 16.26 ],
    [ 1.27, 2.27, 3.27, 4.27, 5.27, 6.27, 7.27, 8.27, 9.27, 10.27, 11.27, 12.27, 13.27, 14.27, 15.27, 16.27 ],
    [ 1.28, 2.28, 3.28, 4.28, 5.28, 6.28, 7.28, 8.28, 9.28, 10.28, 11.28, 12.28, 13.28, 14.28, 15.28, 16.28 ],
    [ 1.29, 2.29, 3.29, 4.29, 5.29, 6.29, 7.29, 8.29, 9.29, 10.29, 11.29, 12.29, 13.29, 14.29, 15.29, 16.29 ],
    [ 1.30, 2.30, 3.30, 4.30, 5.30, 6.30, 7.30, 8.30, 9.30, 10.30, 11.30, 12.30, 13.30, 14.30, 15.30, 16.30 ],
    [ 1.31, 2.31, 3.31, 4.31, 5.31, 6.31, 7.31, 8.31, 9.31, 10.31, 11.31, 12.31, 13.31, 14.31, 15.31, 16.31 ],
    [ 1.32, 2.32, 3.32, 4.32, 5.32, 6.32, 7.32, 8.32, 9.32, 10.32, 11.32, 12.32, 13.32, 14.32, 15.32, 16.32 ]

    ]> : tensor<32x16xf32>

    %0 = call @bigrelu(%da) : (tensor<32x16xf32>) -> tensor<32x16xf32>
    %v0 = vector.transfer_read %0[%c0, %c0], %d1 : tensor<32x16xf32>, vector<32x16xf32>

    // 
    // CHECK:     ( ( 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1, 13.1, 14.1, 15.1, 16.1 ), 
    // CHECK-SAME:  ( 1.2, 2.2, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 9.2, 10.2, 11.2, 12.2, 13.2, 14.2, 15.2, 16.2 ), 
    // CHECK-SAME:  ( 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3, 8.3, 9.3, 10.3, 11.3, 12.3, 13.3, 14.3, 15.3, 16.3 ), 
    // CHECK-SAME:  ( 1.4, 2.4, 3.4, 4.4, 5.4, 6.4, 7.4, 8.4, 9.4, 10.4, 11.4, 12.4, 13.4, 14.4, 15.4, 16.4 ), 
    // CHECK-SAME:  ( 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5, 16.5 ), 
    // CHECK-SAME:  ( 1.6, 2.6, 3.6, 4.6, 5.6, 6.6, 7.6, 8.6, 9.6, 10.6, 11.6, 12.6, 13.6, 14.6, 15.6, 16.6 ), 
    // CHECK-SAME:  ( 1.7, 2.7, 3.7, 4.7, 5.7, 6.7, 7.7, 8.7, 9.7, 10.7, 11.7, 12.7, 13.7, 14.7, 15.7, 16.7 ), 
    // CHECK-SAME:  ( 1.8, 2.8, 3.8, 4.8, 5.8, 6.8, 7.8, 8.8, 9.8, 10.8, 11.8, 12.8, 13.8, 14.8, 15.8, 16.8 ), 
    // CHECK-SAME:  ( 1.9, 2.9, 3.9, 4.9, 5.9, 6.9, 7.9, 8.9, 9.9, 10.9, 11.9, 12.9, 13.9, 14.9, 15.9, 16.9 ), 
    // CHECK-SAME:  ( 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1, 13.1, 14.1, 15.1, 16.1 ), 
    // CHECK-SAME:  ( 1.11, 2.11, 3.11, 4.11, 5.11, 6.11, 7.11, 8.11, 9.11, 10.11, 11.11, 12.11, 13.11, 14.11, 15.11, 16.11 ), 
    // CHECK-SAME:  ( 1.12, 2.12, 3.12, 4.12, 5.12, 6.12, 7.12, 8.12, 9.12, 10.12, 11.12, 12.12, 13.12, 14.12, 15.12, 16.12 ), 
    // CHECK-SAME:  ( 1.13, 2.13, 3.13, 4.13, 5.13, 6.13, 7.13, 8.13, 9.13, 10.13, 11.13, 12.13, 13.13, 14.13, 15.13, 16.13 ), 
    // CHECK-SAME:  ( 1.14, 2.14, 3.14, 4.14, 5.14, 6.14, 7.14, 8.14, 9.14, 10.14, 11.14, 12.14, 13.14, 14.14, 15.14, 16.14 ), 
    // CHECK-SAME:  ( 1.15, 2.15, 3.15, 4.15, 5.15, 6.15, 7.15, 8.15, 9.15, 10.15, 11.15, 12.15, 13.15, 14.15, 15.15, 16.15 ), 
    // CHECK-SAME:  ( 1.16, 2.16, 3.16, 4.16, 5.16, 6.16, 7.16, 8.16, 9.16, 10.16, 11.16, 12.16, 13.16, 14.16, 15.16, 16.16 ), 
    // CHECK-SAME:  ( 1.17, 2.17, 3.17, 4.17, 5.17, 6.17, 7.17, 8.17, 9.17, 10.17, 11.17, 12.17, 13.17, 14.17, 15.17, 16.17 ), 
    // CHECK-SAME:  ( 1.18, 2.18, 3.18, 4.18, 0, 0, 7.18, 8.18, 9.18, 10.18, 11.18, 12.18, 13.18, 14.18, 15.18, 16.18 ), 
    // CHECK-SAME:  ( 1.19, 2.19, 3.19, 4.19, 0, 0, 7.19, 8.19, 9.19, 10.19, 11.19, 12.19, 13.19, 14.19, 15.19, 16.19 ), 
    // CHECK-SAME:  ( 1.2, 2.2, 3.2, 4.2, 5.2, 6.2, 7.2, 8.2, 9.2, 10.2, 11.2, 12.2, 13.2, 14.2, 15.2, 16.2 ), 
    // CHECK-SAME:  ( 1.21, 2.21, 3.21, 4.21, 5.21, 6.21, 7.21, 8.21, 9.21, 10.21, 11.21, 12.21, 13.21, 14.21, 15.21, 16.21 ), 
    // CHECK-SAME:  ( 1.22, 2.22, 3.22, 4.22, 5.22, 6.22, 7.22, 8.22, 9.22, 10.22, 11.22, 12.22, 13.22, 14.22, 15.22, 16.22 ), 
    // CHECK-SAME:  ( 1.23, 2.23, 3.23, 4.23, 5.23, 6.23, 7.23, 8.23, 9.23, 10.23, 11.23, 12.23, 13.23, 14.23, 15.23, 16.23 ), 
    // CHECK-SAME:  ( 1.24, 2.24, 3.24, 4.24, 5.24, 6.24, 7.24, 8.24, 9.24, 10.24, 11.24, 12.24, 13.24, 14.24, 15.24, 16.24 ), 
    // CHECK-SAME:  ( 1.25, 2.25, 3.25, 4.25, 5.25, 6.25, 7.25, 8.25, 9.25, 10.25, 11.25, 12.25, 13.25, 14.25, 15.25, 16.25 ), 
    // CHECK-SAME:  ( 1.26, 2.26, 3.26, 4.26, 5.26, 6.26, 7.26, 8.26, 9.26, 10.26, 11.26, 12.26, 13.26, 14.26, 15.26, 16.26 ), 
    // CHECK-SAME:  ( 1.27, 2.27, 3.27, 4.27, 5.27, 6.27, 7.27, 8.27, 9.27, 10.27, 11.27, 12.27, 13.27, 14.27, 15.27, 16.27 ), 
    // CHECK-SAME:  ( 1.28, 2.28, 3.28, 4.28, 5.28, 6.28, 7.28, 8.28, 9.28, 10.28, 11.28, 12.28, 13.28, 14.28, 15.28, 16.28 ), 
    // CHECK-SAME:  ( 1.29, 2.29, 3.29, 4.29, 5.29, 6.29, 7.29, 8.29, 9.29, 10.29, 11.29, 12.29, 13.29, 14.29, 15.29, 16.29 ), 
    // CHECK-SAME:  ( 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3, 8.3, 9.3, 10.3, 11.3, 12.3, 13.3, 14.3, 15.3, 16.3 ), 
    // CHECK-SAME:  ( 1.31, 2.31, 3.31, 4.31, 5.31, 6.31, 7.31, 8.31, 9.31, 10.31, 11.31, 12.31, 13.31, 14.31, 15.31, 16.31 ), 
    // CHECK-SAME:  ( 1.32, 2.32, 3.32, 4.32, 5.32, 6.32, 7.32, 8.32, 9.32, 10.32, 11.32, 12.32, 13.32, 14.32, 15.32, 16.32 ) )
    //

    vector.print %v0 : vector<32x16xf32>

    return
  }
}
