//===- ConvertTppToXsmm.cpp -------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Standalone/Dialect/Tpp/TppOps.h"
#include "Standalone/Dialect/Xsmm/XsmmAttr.h"
#include "Standalone/Dialect/Xsmm/XsmmOps.h"
#include "Standalone/Passes.h"
#include "mlir/Dialect/Arithmetic/IR/Arithmetic.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

using namespace mlir;
using namespace mlir::tpp;

#define GEN_PASS_CLASSES
#include "Standalone/Passes.h.inc"

namespace {

struct ConvertTppMatmulOp : public OpRewritePattern<MatmulOp> {
  using OpRewritePattern<MatmulOp>::OpRewritePattern;

  LogicalResult matchAndRewrite(MatmulOp matmulOp,
                                PatternRewriter &rewriter) const override {
    Location loc = matmulOp.getLoc();

    MemRefType memrefC = matmulOp.getMatrixCType();
    MemRefType memrefA = matmulOp.getMatrixAType();
    int64_t m = memrefC.getShape()[0];
    int64_t n = memrefC.getShape()[1];
    int64_t k = memrefA.getShape()[1];
    int64_t lda = m;
    int64_t ldb = k;
    int64_t ldc = m;
    IntegerType integer64 = IntegerType::get(rewriter.getContext(), 64);
    DenseI64ArrayAttr dims = DenseI64ArrayAttr::get(
        rewriter.getContext(), ArrayRef<int64_t>{m, n, k, lda, ldb, ldc});
    xsmm::TernaryKindAttr attr = xsmm::TernaryKindAttr::get(
        matmulOp.getContext(), xsmm::TernaryKind::MATMUL);
    Value dispatched =
        rewriter.create<xsmm::TernaryDispatchOp>(loc, integer64, attr, dims);

    SmallVector<Value, 6> invokeOperands;
    invokeOperands.push_back(dispatched);
    invokeOperands.append(matmulOp->getOperands().begin(),
                          matmulOp->getOperands().end());
    rewriter.replaceOpWithNewOp<xsmm::TernaryOp>(matmulOp, attr,
                                                 invokeOperands);
    return success();
  }
};

struct ConvertTppIdentityOp : public OpRewritePattern<IdentityOp> {
  using OpRewritePattern<IdentityOp>::OpRewritePattern;

  // Examples:
  // If lower=[c], higher=[a, b, c], [c] reshaped into [1, 1, c].
  // If lower=[b, c], higher=[a, b, c], [b, c] reshaped into [1, b, c].
  // If lower=[a], higher=[a, a], [a] reshaped into [1, a].
  // If lower=[a], target=[a, b, a], [a] reshaped into [1, 1, a].
  // If lower=[], target=[a, b, c], [] reshaped into [1, 1, 1].
  void
  computeBcastShapeInput(ArrayRef<int64_t> higherRankShape,
                         ArrayRef<int64_t> lowerRankShape,
                         SmallVectorImpl<int64_t> &reshapeOutputShape) const {
    // Initialize new shapes with [1] * higherRank.
    int64_t higherRank = higherRankShape.size();
    int64_t lowerRank = lowerRankShape.size();

    reshapeOutputShape.assign(higherRank, 1);

    int64_t higherRankDim;
    int64_t lowerRankDim;

    for (int64_t i = higherRank - 1, j = lowerRank - 1; i >= 0 && j >= 0;
         i--, j--) {
      higherRankDim = higherRankShape[i];
      lowerRankDim = lowerRankShape[j];

      if (lowerRankDim == 1 && higherRankDim > 1)
        reshapeOutputShape[i] = 1;
      else if ((lowerRankDim > 1 && higherRankDim == 1) ||
               (lowerRankDim == higherRankDim))
        reshapeOutputShape[i] = lowerRankDim;
      else if (higherRankDim != lowerRankDim)
        llvm_unreachable("bCast semantics for identity op broken");
    }
  }

  // Return ldi and bCast.
  std::pair<int64_t, xsmm::UnaryFlags> getLdiAndBCast(IdentityOp identityOp,
                                                      int64_t ldo) const {
    Type inputType = identityOp.getInput().getType();

    // There are multiple ways to define a scalar.  f32, memref<1x1xf32> or
    // memref<f32>. Handle f32, and memref<1x1xf32>. memref<f32> is not allowed
    // in tpp at the moment.
    if (!inputType.isa<ShapedType>()) {
      xsmm::UnaryFlags bCast = xsmm::UnaryFlags::BCAST_SCALAR;
      int64_t ldi = 1;
      return {ldi, bCast};
    }
    if (inputType.isa<ShapedType>()) {
      ArrayRef<int64_t> shape = inputType.cast<ShapedType>().getShape();
      if ((shape[0] == 1) && shape[1] == 1) {
        xsmm::UnaryFlags bCast = xsmm::UnaryFlags::BCAST_SCALAR;
        int64_t ldi = 1;
        return {ldi, bCast};
      }
    }

    ArrayRef<int64_t> shapeInput =
        identityOp.getInput().getType().cast<ShapedType>().getShape();
    ArrayRef<int64_t> shapeOutput =
        identityOp.getOutput().getType().cast<ShapedType>().getShape();
    assert(shapeOutput.size() >= shapeInput.size() &&
           "output rank must be >= input rank");
    SmallVector<int64_t, 4> bShapeInput;
    computeBcastShapeInput(shapeOutput, shapeInput, bShapeInput);
    assert(shapeOutput.size() == bShapeInput.size());

    if (shapeInput[1] == 1 && shapeOutput[1] > 1) {
      xsmm::UnaryFlags bCast = xsmm::UnaryFlags::BCAST_ROW;
      int64_t ldi = shapeInput[1];
      return {ldi, bCast};
    }

    if (shapeInput[0] == 1 && shapeOutput[0] > 1) {
      xsmm::UnaryFlags bCast = xsmm::UnaryFlags::BCAST_COL;
      int64_t ldi = shapeInput[1];
      return {ldi, bCast};
    }

    if (shapeInput[0] == shapeOutput[0] && shapeInput[1] == shapeOutput[1]) {
      xsmm::UnaryFlags bCast = xsmm::UnaryFlags::NONE;
      int64_t ldi = shapeInput[1];
      return {ldi, bCast};
    }
    llvm_unreachable("failed to get ldi and bCast for identity");
  }

  LogicalResult matchAndRewrite(IdentityOp identityOp,
                                PatternRewriter &rewriter) const override {
    Location loc = identityOp.getLoc();
    // no conversion if identity is a scalar operation.
    Type outputType = identityOp.getOutput().getType();
    if (!outputType.isa<ShapedType>())
      return failure();

    MemRefType outputMemRef = outputType.cast<MemRefType>();
    int64_t m = outputMemRef.getShape()[0];
    int64_t n = outputMemRef.getShape()[1];
    int64_t ldo = n;
    std::pair<int64_t, xsmm::UnaryFlags> ldiAndBCast =
        getLdiAndBCast(identityOp, ldo);
    int64_t ldi = ldiAndBCast.first;
    xsmm::UnaryFlags bCast = ldiAndBCast.second;
    IntegerType integer64 = IntegerType::get(rewriter.getContext(), 64);
    xsmm::UnaryKindAttr attr = xsmm::UnaryKindAttr::get(
        identityOp.getContext(), xsmm::UnaryKind::IDENTITY);
    DenseI64ArrayAttr dims = DenseI64ArrayAttr::get(
        rewriter.getContext(), ArrayRef<int64_t>{m, n, ldi, ldo});
    xsmm::UnaryFlagsAttr bCastAttr =
        xsmm::UnaryFlagsAttr::get(identityOp.getContext(), bCast);

    Value dispatched = rewriter.create<xsmm::UnaryDispatchOp>(
        loc, integer64, attr, dims, bCastAttr);

    SmallVector<Value, 6> invokeOperands;
    invokeOperands.push_back(dispatched);
    invokeOperands.append(identityOp->getOperands().begin(),
                          identityOp->getOperands().end());

    rewriter.replaceOpWithNewOp<xsmm::UnaryOp>(identityOp, attr,
                                               invokeOperands);
    return success();
  }
};

struct ConvertTppReluOp : public OpRewritePattern<ReluOp> {
  using OpRewritePattern<ReluOp>::OpRewritePattern;

  LogicalResult matchAndRewrite(ReluOp reluOp,
                                PatternRewriter &rewriter) const override {
    Location loc = reluOp.getLoc();
    // no conversion if the relu is a scalar operation.
    Type outputType = reluOp.getOutput().getType();
    if (!outputType.isa<ShapedType>())
      return failure();

    MemRefType outputMemRef = outputType.cast<MemRefType>();
    int64_t m = outputMemRef.getShape()[0];
    int64_t n = outputMemRef.getShape()[1];
    int64_t ldo = n;
    int64_t ldi = m;

    xsmm::UnaryFlags bCast = xsmm::UnaryFlags::NONE;
    xsmm::UnaryKindAttr attr =
        xsmm::UnaryKindAttr::get(reluOp.getContext(), xsmm::UnaryKind::RELU);
    DenseI64ArrayAttr dims = DenseI64ArrayAttr::get(
        rewriter.getContext(), ArrayRef<int64_t>{m, n, ldi, ldo});
    xsmm::UnaryFlagsAttr bCastAttr =
        xsmm::UnaryFlagsAttr::get(reluOp.getContext(), bCast);
    IntegerType integer64 = IntegerType::get(rewriter.getContext(), 64);
    Value dispatched = rewriter.create<xsmm::UnaryDispatchOp>(
        loc, integer64, attr, dims, bCastAttr);

    SmallVector<Value, 6> invokeOperands;
    invokeOperands.push_back(dispatched);
    invokeOperands.append(reluOp->getOperands().begin(),
                          reluOp->getOperands().end());

    rewriter.replaceOpWithNewOp<xsmm::UnaryOp>(reluOp, attr, invokeOperands);
    return success();
  }
};

void populateTppToXsmmPatterns(RewritePatternSet &patterns) {
  // clang-format off
  patterns.add<ConvertTppIdentityOp,
               ConvertTppReluOp,
               ConvertTppMatmulOp>(patterns.getContext());
  // clang-format on
}

struct ConvertTppToXsmm : public ConvertTppToXsmmBase<ConvertTppToXsmm> {
  void runOnOperation() override {
    RewritePatternSet patterns(&getContext());
    populateTppToXsmmPatterns(patterns);
    (void)applyPatternsAndFoldGreedily(getOperation(), std::move(patterns));
    return;
  }
};

} // namespace

std::unique_ptr<OperationPass<func::FuncOp>>
mlir::tpp::createConvertTppToXsmmPass() {
  return std::make_unique<ConvertTppToXsmm>();
}
