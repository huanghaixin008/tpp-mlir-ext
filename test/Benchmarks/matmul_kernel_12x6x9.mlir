// RUN: tpp-opt %s -map-linalg-to-tpp \
// RUN: -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map" \
// RUN: -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize \
// RUN: -convert-linalg-to-tpp="enable-tiling" -convert-tpp-to-xsmm \
// RUN: -convert-xsmm-to-func | \
// RUN: tpp-run \
// RUN:  -e entry -entry-point-result=void  \
// RUN: -shared-libs=%llvmlirdir/libmlir_c_runner_utils%shlibext,%tpplibdir/libtpp_c_runner_utils%shlibext | \
// RUN: FileCheck %s
//

// RUN: tpp-opt %s -map-linalg-to-tpp \
// RUN: -one-shot-bufferize="bufferize-function-boundaries allow-return-allocs function-boundary-type-conversion=identity-layout-map" \
// RUN: -canonicalize -drop-equivalent-buffer-results -finalizing-bufferize \
// RUN: -convert-linalg-to-tpp="enable-tiling" | FileCheck -check-prefix=TPP %s
//

#map0 = affine_map<(d0, d1, d2) -> (d0, d2)>
#map1 = affine_map<(d0, d1, d2) -> (d2, d1)>
#map2 = affine_map<(d0, d1, d2) -> (d0, d1)>

func.func @entry(%A: tensor<12x9xf32>, %B: tensor<9x6xf32>,
                  %C: tensor<12x6xf32>) -> tensor<12x6xf32> {
  %D = linalg.generic {indexing_maps = [#map0, #map1, #map2],
                         iterator_types = ["parallel", "parallel", "reduction"]}
    ins(%A, %B: tensor<12x9xf32>, tensor<9x6xf32>) outs(%C: tensor<12x6xf32>) {
      ^bb0(%a: f32, %b: f32, %c: f32):
        %0 = arith.mulf %a, %b : f32
        %1 = arith.addf %c, %0 : f32
        linalg.yield %1 : f32
    } -> tensor<12x6xf32>
  return %D : tensor<12x6xf32>
}
// CHECK-COUNT-12: ( 10, 10, 10, 10, 10, 10 )

// TPP: func.func @entry(
// TPP-SAME:  %[[ARG0:.+]]: memref<12x9xf32>,
// TPP-SAME:  %[[ARG1:.+]]: memref<9x6xf32>,
// TPP-SAME:  %[[ARG2:.+]]: memref<12x6xf32>)
// TPP: tpp.matmul ins(%[[ARG0]] : memref<12x9xf32>, %[[ARG1]] : memref<9x6xf32>) out(%[[ARG2]] : memref<12x6xf32>)
// TPP: return
