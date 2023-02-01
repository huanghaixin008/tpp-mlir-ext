// RUN: tpp-opt %s -default-tpp-passes -split-input-file | FileCheck %s

// CHECK: func.func @add(
// CHECK-SAME:  %[[ARG0:.+]]: memref<3x3xf32>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<3x3xf32>
func.func @add(%arg0: memref<3x3xf32>, %arg1: memref<3x3xf32>) {
  // CHECK: call @xsmm_binary_dispatch
  // CHECK: %[[cast0:.*]] = memref.cast %[[ARG0]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG1]]
  // CHECK: call @xsmm_binary_invoke({{.*}}%[[cast0]], %[[cast1]]
  tpp.add ins(%arg0: memref<3x3xf32>, %arg1: memref<3x3xf32>) out(%arg1: memref<3x3xf32>)

  return
}

// -----

#map = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func.func @add_mapping(
func.func @add_mapping(%arg0: memref<1x10x10xf32>, %arg1: memref<1x10x10xf32>) {
  // CHECK: memref.subview
  // CHECK-NOT: scf.parallel
  // CHECK: call @xsmm_binary_dispatch
  // CHECK: %[[cast:.*]] = memref.cast
  // CHECK: %[[cast1:.*]] = memref.cast
  // CHECK: call @xsmm_binary_invoke({{.*}}%[[cast]], %[[cast1]]
  %subview = memref.subview %arg0[0, 0, 0] [1, 10, 10] [1, 1, 1] : memref<1x10x10xf32> to memref<10x10xf32>
  %subview_0 = memref.subview %arg1[0, 0, 0] [1, 10, 10] [1, 1, 1] : memref<1x10x10xf32> to memref<10x10xf32>
  tpp.add ins(%subview : memref<10x10xf32>, %subview_0 : memref<10x10xf32>) out(%subview_0 : memref<10x10xf32>)

  return
}

// -----

#map = affine_map<(d0, d1)[s0] -> (d0 * 10 + d1 + s0)>

// CHECK-LABEL: @add_mapping_parallel
func.func @add_mapping_parallel(%arg0: memref<10x10x10xf32>, %arg1: memref<10x10x10xf32>) {
  // CHECK: call @xsmm_binary_dispatch
  // CHECK: scf.parallel
  // CHECK:   %[[cast:.*]] = memref.cast
  // CHECK:   %[[cast1:.*]] = memref.cast
  // CHECK:   call @xsmm_binary_invoke({{.*}}%[[cast]], %[[cast1]]
  %c0 = arith.constant 0 : index
  %c10 = arith.constant 10 : index
  %c1 = arith.constant 1 : index
  scf.parallel (%arg2) = (%c0) to (%c10) step (%c1) {
    %subview = memref.subview %arg0[%arg2, 0, 0] [1, 10, 10] [1, 1, 1] : memref<10x10x10xf32> to memref<10x10xf32, #map>
    %subview_0 = memref.subview %arg1[%arg2, 0, 0] [1, 10, 10] [1, 1, 1] : memref<10x10x10xf32> to memref<10x10xf32, #map>
    tpp.add ins(%subview : memref<10x10xf32, #map>, %subview_0 : memref<10x10xf32, #map>) out(%subview_0 : memref<10x10xf32, #map>)
    scf.yield
  }

  return
}

// -----

// CHECK: func.func @identity(
// CHECK-SAME:  %[[ARG0:.+]]: memref<3x3xf32>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<1x1xf32>
func.func @identity(%arg0: memref<3x3xf32>, %arg1: memref<1x1xf32>) {
  // CHECK: call @xsmm_unary_dispatch
  // CHECK: %[[cast0:.*]] = memref.cast %[[ARG1]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG0]]
  // CHECK: call @xsmm_unary_invoke({{.*}}%[[cast0]], %[[cast1]]
  tpp.identity ins(%arg1: memref<1x1xf32>) out(%arg0: memref<3x3xf32>)

  return
}

// -----

#map = affine_map<(d0, d1)[s0] -> (d0 * 64 + d1 + s0)>

// CHECK-LABEL: @identity_mapping
func.func @identity_mapping(%arg0: memref<64xf32>) -> memref<12x56x56x64xf32> {
  // CHECK: call @xsmm_unary_dispatch
  // CHECK: scf.parallel
  // CHECK:   %[[cast:.*]] = memref.cast
  // CHECK:   %[[cast1:.*]] = memref.cast
  // CHECK:   call @xsmm_unary_invoke({{.*}}%[[cast]], %[[cast1]]
  %c0 = arith.constant 0 : index
  %c12 = arith.constant 12 : index
  %c1 = arith.constant 1 : index
  %c56 = arith.constant 56 : index
  %alloc = memref.alloc() {alignment = 128 : i64} : memref<12x56x56x64xf32>
  scf.parallel (%arg1, %arg2) = (%c0, %c0) to (%c12, %c56) step (%c1, %c1) {
    %subview = memref.subview %alloc[%arg1, %arg2, 0, 0] [1, 1, 56, 64] [1, 1, 1, 1] : memref<12x56x56x64xf32> to memref<56x64xf32, #map>
    tpp.identity ins(%arg0 : memref<64xf32>) out(%subview : memref<56x64xf32, #map>)
    scf.yield
  }

  return %alloc : memref<12x56x56x64xf32>
}

// -----

// CHECK: func.func @relu(
// CHECK-SAME:  %[[ARG0:.+]]: memref<3x3xf32>
func.func @relu(%arg0: memref<3x3xf32>) {
  // CHECK: call @xsmm_unary_dispatch
  // CHECK: %[[cast0:.*]] = memref.cast %[[ARG0]]
  // CHECK: call @xsmm_unary_invoke_inline({{.*}}%[[cast0]]
  tpp.relu ins(%arg0: memref<3x3xf32>) out(%arg0: memref<3x3xf32>)

  return
}

// -----

#map = affine_map<(d0, d1)[s0] -> (d0 * 32 + d1 + s0)>

// CHECK-LABEL: @relu_3d(
// CHECK-SAME: %[[arg:.*]]: memref<64x32x32xf32>) {
func.func @relu_3d(%arg0: memref<64x32x32xf32>) -> memref<64x32x32xf32> {
  // CHECK: call @xsmm_unary_dispatch
  // CHECK: scf.parallel
  // CHECK:   %[[cast:.*]] = memref.cast
  // CHECK:   call @xsmm_unary_invoke_inline({{.*}}%[[cast]]
  %c0 = arith.constant 0 : index
  %c64 = arith.constant 64 : index
  %c1 = arith.constant 1 : index
  scf.parallel (%arg1) = (%c0) to (%c64) step (%c1) {
    %subview = memref.subview %arg0[%arg1, 0, 0] [1, 32, 32] [1, 1, 1] : memref<64x32x32xf32> to memref<32x32xf32, #map>
    tpp.relu ins(%subview : memref<32x32xf32, #map>) out(%subview : memref<32x32xf32, #map>)
    scf.yield
  }

  return %arg0 : memref<64x32x32xf32>
}

// -----

// CHECK: func.func @brgemm(
// CHECK-SAME:  %[[ARG0:.+]]: memref<2x3x4xf32>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<2x4x3xf32>,
// CHECK-SAME:  %[[ARG2:.+]]: memref<3x3xf32>
func.func @brgemm(%arg0: memref<2x3x4xf32>, %arg1: memref<2x4x3xf32>, %arg2: memref<3x3xf32>) {
  // CHECK: call @xsmm_brgemm_dispatch
  // CHECK: %[[cast:.*]] = memref.cast %[[ARG0]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG1]]
  // CHECK: %[[cast2:.*]] = memref.cast %[[ARG2]]
  // CHECK: call @xsmm_brgemm_invoke({{.*}}%[[cast]], %[[cast1]], %[[cast2]]
  tpp.brgemm ins(%arg0: memref<2x3x4xf32>, %arg1: memref<2x4x3xf32>) out(%arg2: memref<3x3xf32>)

  return
}

// -----

// CHECK-LABEL: func.func @brgemm_bf16
// CHECK-SAME:  %[[ARG0:.+]]: memref<64x4x4xbf16>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<64x2x4x2xbf16>,
// CHECK-SAME:  %[[ARG2:.+]]: memref<4x4xbf16>
func.func @brgemm_bf16(%arg0: memref<64x4x4xbf16>, %arg1: memref<64x2x4x2xbf16>,
                              %arg2: memref<4x4xbf16>) {
  // CHECK: call @xsmm_brgemm_dispatch
  // CHECK: %[[cast:.*]] = memref.cast %[[ARG0]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG1]]
  // CHECK: %[[cast2:.*]] = memref.cast %[[ARG2]]
  // CHECK: call @xsmm_brgemm_invoke({{.*}}%[[cast]], %[[cast1]], %[[cast2]]
  tpp.vnni_brgemm ins(%arg0: memref<64x4x4xbf16>, %arg1: memref<64x2x4x2xbf16>) out(%arg2: memref<4x4xbf16>)

  return
}

// -----

// CHECK: func.func @matmul(
// CHECK-SAME:  %[[ARG0:.+]]: memref<4x8xf32>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<8x4xf32>,
// CHECK-SAME:  %[[ARG2:.+]]: memref<4x4xf32>)
func.func @matmul(%A: memref<4x8xf32>,
          %B: memref<8x4xf32>, %C: memref<4x4xf32>) {
  // CHECK: call @xsmm_matmul_dispatch
  // CHECK: %[[cast0:.*]] = memref.cast %[[ARG0]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG1]]
  // CHECK: %[[cast2:.*]] = memref.cast %[[ARG2]]
  // CHECK: call @xsmm_matmul_invoke({{.*}}%[[cast0]], %[[cast1]], %[[cast2]]
  tpp.matmul ins(%A : memref<4x8xf32>, %B : memref<8x4xf32>) out(%C : memref<4x4xf32>)

  return
}

// -----

// CHECK-LABEL: func.func @matmul_bf16
// CHECK-SAME:  %[[ARG0:.+]]: memref<6x10xbf16>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<5x6x2xbf16>,
// CHECK-SAME:  %[[ARG2:.+]]: memref<6x6xbf16>
func.func @matmul_bf16(%arg0: memref<6x10xbf16>, %arg1: memref<5x6x2xbf16>,
                            %arg2: memref<6x6xbf16>) {
  // CHECK: call @xsmm_matmul_dispatch
  // CHECK: %[[cast:.*]] = memref.cast %[[ARG0]]
  // CHECK: %[[cast1:.*]] = memref.cast %[[ARG1]]
  // CHECK: %[[cast2:.*]] = memref.cast %[[ARG2]]
  // CHECK: call @xsmm_matmul_invoke({{.*}}%[[cast]], %[[cast1]], %[[cast2]]
  tpp.vnni_matmul ins(%arg0: memref<6x10xbf16>, %arg1: memref<5x6x2xbf16>) out(%arg2: memref<6x6xbf16>)

  return
}

// -----

// CHECK-LABEL: func.func @blocked_matmul(
// CHECK-SAME: %[[ARG0:.+]]: memref<4x16x32x32xf32>,
// CHECK-SAME: %[[ARG1:.+]]: memref<8x16x32x32xf32>,
// CHECK-SAME: %[[ARG2:.+]]: memref<4x8x32x32xf32>)
func.func @blocked_matmul(%arg0: memref<4x16x32x32xf32>, %arg1: memref<8x16x32x32xf32>, %arg2: memref<4x8x32x32xf32>) {
  // CHECK: call @xsmm_brgemm_dispatch
  // CHECK: scf.parallel
  // CHECK:   %[[cast:.*]] = memref.cast
  // CHECK:   %[[cast1:.*]] = memref.cast
  // CHECK:   %[[cast2:.*]] = memref.cast
  // CHECK:   call @xsmm_brgemm_invoke({{.*}}%[[cast]], %[[cast1]], %[[cast2]]
  %c0 = arith.constant 0 : index
  %c4 = arith.constant 4 : index
  %c1 = arith.constant 1 : index
  %c8 = arith.constant 8 : index
  scf.parallel (%arg3, %arg4) = (%c0, %c0) to (%c4, %c8) step (%c1, %c1) {
    %subview = memref.subview %arg0[%arg3, 0, 0, 0] [1, 16, 32, 32] [1, 1, 1, 1] : memref<4x16x32x32xf32> to memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>
    %subview_0 = memref.subview %arg1[%arg4, 0, 0, 0] [1, 16, 32, 32] [1, 1, 1, 1] : memref<8x16x32x32xf32> to memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>
    %subview_1 = memref.subview %arg2[%arg3, %arg4, 0, 0] [1, 1, 32, 32] [1, 1, 1, 1] : memref<4x8x32x32xf32> to memref<32x32xf32, strided<[32, 1], offset: ?>>
    tpp.brgemm ins(%subview : memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>, %subview_0 : memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>) out(%subview_1 : memref<32x32xf32, strided<[32, 1], offset: ?>>)
    scf.yield
  }

  return
}

// -----

// Conv2D weights
memref.global "private" constant @__constant_2048x512xf32 : memref<2048x512xf32> = dense<0.00332225906> {alignment = 128 : i64}

// CHECK-LABEL: @conv2d_1x1(
// CHECK-SAME: %[[arg:.*]]: memref<1x7x7x2048xf32>) -> memref<1x7x7x512xf32> {
func.func @conv2d_1x1(%arg0: memref<1x7x7x2048xf32>) -> memref<1x7x7x512xf32> {
  %cst = arith.constant 0.000000e+00 : f32
  %c7 = arith.constant 7 : index
  %c1 = arith.constant 1 : index
  %c0 = arith.constant 0 : index
  %0 = memref.get_global @__constant_2048x512xf32 : memref<2048x512xf32>

  // 1x1 Conv2D
  // CHECK: call @xsmm_matmul_dispatch
  // CHECK: scf.for
  // CHECK:   %[[cast:.*]] = memref.cast
  // CHECK:   %[[cast1:.*]] = memref.cast
  // CHECK:   %[[cast2:.*]] = memref.cast
  // CHECK:   call @xsmm_matmul_invoke({{.*}}%[[cast]], %[[cast1]], %[[cast2]]
  %alloc = memref.alloc() {alignment = 128 : i64} : memref<1x7x7x512xf32>
  linalg.fill ins(%cst : f32) outs(%alloc : memref<1x7x7x512xf32>)
  scf.for %arg1 = %c0 to %c7 step %c1 {
    %subview = memref.subview %arg0[0, %arg1, 0, 0] [1, 1, 7, 2048] [1, 1, 1, 1] : memref<1x7x7x2048xf32> to memref<7x2048xf32, strided<[2048, 1], offset: ?>>
    %subview_0 = memref.subview %alloc[0, %arg1, 0, 0] [1, 1, 7, 512] [1, 1, 1, 1] : memref<1x7x7x512xf32> to memref<7x512xf32, strided<[512, 1], offset: ?>>
    tpp.matmul ins(%subview : memref<7x2048xf32, strided<[2048, 1], offset: ?>>, %0 : memref<2048x512xf32>) out(%subview_0 : memref<7x512xf32, strided<[512, 1], offset: ?>>)
  }

  // CHECK: return {{.*}} : memref<1x7x7x512xf32>
  return %alloc : memref<1x7x7x512xf32>
}

// -----

#map = affine_map<(d0, d1) -> (d1)>
#map1 = affine_map<(d0, d1) -> (d0, d1)>
#map2 = affine_map<(d0, d1, d2) -> (d0, d2)>
#map3 = affine_map<(d0, d1, d2) -> (d2, d1)>
#map4 = affine_map<(d0, d1, d2) -> (d0, d1)>

// CHECK: func.func @mlp(
// CHECK-SAME:  %[[ARG0:.+]]: memref<128x256xf32>,
// CHECK-SAME:  %[[ARG1:.+]]: memref<256x512xf32>,
// CHECK-SAME:  %[[ARG2:.+]]: memref<512xf32>,
// CHECK-SAME:  %[[ARG3:.+]]: memref<128x512xf32>)
module @predict_function  {
  func.func @mlp(%arg0: memref<128x256xf32>, %arg1: memref<256x512xf32>,
    %arg2: memref<512xf32>,  %arg3: memref<128x512xf32>) {

    // Identity
    // CHECK: call @xsmm_unary_dispatch
    // CHECK: %[[cast:.*]] = memref.cast %[[ARG2]]
    // CHECK: %[[cast0:.*]] = memref.cast %[[ARG3]]
    // CHECK: call @xsmm_unary_invoke({{.*}}%[[cast]], %[[cast0]]
    tpp.identity ins(%arg2 : memref<512xf32>) out(%arg3 : memref<128x512xf32>)

    // Matmul
    // CHECK: call @xsmm_matmul_dispatch
    // CHECK: %[[cast1:.*]] = memref.cast %[[ARG0]]
    // CHECK: %[[cast2:.*]] = memref.cast %[[ARG1]]
    // CHECK: call @xsmm_matmul_invoke({{.*}}%[[cast1]], %[[cast2]], %[[cast0]]
    tpp.matmul ins(%arg0 : memref<128x256xf32>, %arg1 : memref<256x512xf32>) out(%arg3 : memref<128x512xf32>)

    // Relu
    // CHECK: call @xsmm_unary_dispatch
    // CHECK: call @xsmm_unary_invoke_inline({{.*}}%[[cast0]], %[[cast0]]
    tpp.relu ins(%arg3 : memref<128x512xf32>) out(%arg3 : memref<128x512xf32>)

    return
  }
}
