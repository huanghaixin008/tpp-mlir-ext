// RUN: tpp-opt %s -constant-fold-pack -canonicalize -split-input-file | FileCheck %s

func.func @splat() ->  tensor<8x2x1x1x32x32xi64> {
  %cst = arith.constant dense<1> : tensor<1x1x64x256xi64>
  %0 = tensor.empty() : tensor<8x2x1x1x32x32xi64>
  %pack = tensor.pack %cst outer_dims_perm = [3, 2, 0, 1] inner_dims_pos = [2, 3] inner_tiles = [32, 32] into %0 : tensor<1x1x64x256xi64> -> tensor<8x2x1x1x32x32xi64>
  return  %pack : tensor<8x2x1x1x32x32xi64>
}

// CHECK-LABEL: func.func @splat
// CHECK: %[[CST:.+]] = arith.constant dense<1> : tensor<8x2x1x1x32x32xi64>
// CHECK-NEXT: return %[[CST]] : tensor<8x2x1x1x32x32xi64>

// -----

func.func @non_splat() -> tensor<2x4x4x2xf32> {
  %cst = arith.constant dense<[[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], 
                               [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0], 
                               [16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0], 
                               [24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0], 
                               [32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0], 
                               [40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0], 
                               [49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0], 
                               [57.0, 58.0, 59.0, 60.0, 61.0, 62.0, 63.0, 64.0]]> : tensor<8x8xf32>
  %0 = tensor.empty() : tensor<2x4x4x2xf32>
  %pack = tensor.pack %cst inner_dims_pos = [0, 1] inner_tiles = [4, 2] into %0 : tensor<8x8xf32> -> tensor<2x4x4x2xf32>
  return %pack : tensor<2x4x4x2xf32>
}

// TODO: Did not find a good way to escape multiples '['
// CHECK-LABEL: func.func @non_splat
// CHECK-NOT: tensor.pack
// CHECK: [0.000000e+00, 1.000000e+00], [8.000000e+00, 9.000000e+00], [1.600000e+01, 1.700000e+01], [2.400000e+01, 2.500000e+01]
// CHECK: [2.000000e+00, 3.000000e+00], [1.000000e+01, 1.100000e+01], [1.800000e+01, 1.900000e+01], [2.600000e+01, 2.700000e+01]
// CHECK: [4.000000e+00, 5.000000e+00], [1.200000e+01, 1.300000e+01], [2.000000e+01, 2.100000e+01], [2.800000e+01, 2.900000e+01]
// CHECK: [6.000000e+00, 7.000000e+00], [1.400000e+01, 1.500000e+01], [2.200000e+01, 2.300000e+01], [3.000000e+01, 3.100000e+01]
// CHECK: [3.200000e+01, 3.300000e+01], [4.000000e+01, 4.100000e+01], [4.900000e+01, 5.000000e+01], [5.700000e+01, 5.800000e+01]
// CHECK: [3.400000e+01, 3.500000e+01], [4.200000e+01, 4.300000e+01], [5.100000e+01, 5.200000e+01], [5.900000e+01, 6.000000e+01]
// CHECK: [3.600000e+01, 3.700000e+01], [4.400000e+01, 4.500000e+01], [5.300000e+01, 5.400000e+01], [6.100000e+01, 6.200000e+01]
// CHECK: [3.800000e+01, 3.900000e+01], [4.600000e+01, 4.700000e+01], [5.500000e+01, 5.600000e+01], [6.300000e+01, 6.400000e+01]

// -----

func.func @non_splat_with_outer() -> tensor<4x2x4x2xf32> {
  %cst = arith.constant dense<[[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                               [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0],
                               [16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0],
                               [24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0],
                               [32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0],
                               [40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0],
                               [49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0],
                               [57.0, 58.0, 59.0, 60.0, 61.0, 62.0, 63.0, 64.0]]> : tensor<8x8xf32>
  %0 = tensor.empty() : tensor<4x2x4x2xf32>
  %pack = tensor.pack %cst outer_dims_perm = [1, 0] inner_dims_pos = [0, 1] inner_tiles = [4, 2] 
    into %0 : tensor<8x8xf32> -> tensor<4x2x4x2xf32>
  return %pack : tensor<4x2x4x2xf32>
}

// CHECK-LABEL: func.func @non_splat_with_outer
// CHECK-NOT: tensor.pack
// CHECK: [0.000000e+00, 1.000000e+00], [8.000000e+00, 9.000000e+00], [1.600000e+01, 1.700000e+01], [2.400000e+01, 2.500000e+01]
// CHECK: [3.200000e+01, 3.300000e+01], [4.000000e+01, 4.100000e+01], [4.900000e+01, 5.000000e+01], [5.700000e+01, 5.800000e+01]
// CHECK: [2.000000e+00, 3.000000e+00], [1.000000e+01, 1.100000e+01], [1.800000e+01, 1.900000e+01], [2.600000e+01, 2.700000e+01]
// CHECK: [3.400000e+01, 3.500000e+01], [4.200000e+01, 4.300000e+01], [5.100000e+01, 5.200000e+01], [5.900000e+01, 6.000000e+01]
// CHECK: [4.000000e+00, 5.000000e+00], [1.200000e+01, 1.300000e+01], [2.000000e+01, 2.100000e+01], [2.800000e+01, 2.900000e+01]
// CHECK: [3.600000e+01, 3.700000e+01], [4.400000e+01, 4.500000e+01], [5.300000e+01, 5.400000e+01], [6.100000e+01, 6.200000e+01]
// CHECK: [6.000000e+00, 7.000000e+00], [1.400000e+01, 1.500000e+01], [2.200000e+01, 2.300000e+01], [3.000000e+01, 3.100000e+01]
// CHECK: [3.800000e+01, 3.900000e+01], [4.600000e+01, 4.700000e+01], [5.500000e+01, 5.600000e+01], [6.300000e+01, 6.400000e+01]

// -----

func.func @non_splat_with_inner() -> tensor<2x4x2x4xf32> {
  %cst = arith.constant dense<[[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                               [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0],
                               [16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0],
                               [24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0],
                               [32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0],
                               [40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0],
                               [49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0],
                               [57.0, 58.0, 59.0, 60.0, 61.0, 62.0, 63.0, 64.0]]> : tensor<8x8xf32>
  %0 = tensor.empty() : tensor<2x4x2x4xf32>
  %pack = tensor.pack %cst inner_dims_pos = [1, 0] inner_tiles = [2, 4] 
    into %0 : tensor<8x8xf32> -> tensor<2x4x2x4xf32>
  return %pack : tensor<2x4x2x4xf32>
}

// CHECK-LABEL: func.func @non_splat_with_inner
// CHECK-NOT: tensor.pack
// CHECK: [0.000000e+00, 1.000000e+00, 2.000000e+00, 3.000000e+00], [8.000000e+00, 9.000000e+00, 1.000000e+01, 1.100000e+01]
// CHECK: [4.000000e+00, 5.000000e+00, 6.000000e+00, 7.000000e+00], [1.200000e+01, 1.300000e+01, 1.400000e+01, 1.500000e+01]
// CHECK: [8.000000e+00, 9.000000e+00, 1.000000e+01, 1.100000e+01], [1.600000e+01, 1.700000e+01, 1.800000e+01, 1.900000e+01]
// CHECK: [1.200000e+01, 1.300000e+01, 1.400000e+01, 1.500000e+01], [2.000000e+01, 2.100000e+01, 2.200000e+01, 2.300000e+01]
// CHECK: [1.600000e+01, 1.700000e+01, 1.800000e+01, 1.900000e+01], [2.400000e+01, 2.500000e+01, 2.600000e+01, 2.700000e+01]
// CHECK: [2.000000e+01, 2.100000e+01, 2.200000e+01, 2.300000e+01], [2.800000e+01, 2.900000e+01, 3.000000e+01, 3.100000e+01]
// CHECK: [2.400000e+01, 2.500000e+01, 2.600000e+01, 2.700000e+01], [3.200000e+01, 3.300000e+01, 3.400000e+01, 3.500000e+01]
// CHECK: [2.800000e+01, 2.900000e+01, 3.000000e+01, 3.100000e+01], [3.600000e+01, 3.700000e+01, 3.800000e+01, 3.900000e+01]

// -----

func.func @non_splat_with_padding() -> tensor<2x4x2x4xf32> {
  %cst = arith.constant dense<[[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                               [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0],
                               [16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0],
                               [24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 30.0, 31.0],
                               [32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0],
                               [40.0, 41.0, 42.0, 43.0, 44.0, 45.0, 46.0, 47.0],
                               [49.0, 50.0, 51.0, 52.0, 53.0, 54.0, 55.0, 56.0],
                               [57.0, 58.0, 59.0, 60.0, 61.0, 62.0, 63.0, 64.0]]> : tensor<8x8xf32>
  %0 = tensor.empty() : tensor<2x4x2x4xf32>
  %pad = arith.constant 0.0 : f32
  // CHECK: tensor.pack
  // CHECK-NOT: arith.constant
  %pack = tensor.pack %cst padding_value(%pad : f32) inner_dims_pos = [1, 0] inner_tiles = [2, 4] 
    into %0 : tensor<8x8xf32> -> tensor<2x4x2x4xf32>
  return %pack : tensor<2x4x2x4xf32>
}
