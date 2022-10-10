//===- LinalgXTransformOps.cpp - Implementation of LinalgX transform ops--====//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Standalone/Dialect/LinalgX/TransformOps/LinalgXTransformOps.h"
#include "Standalone/Transforms.h"
#include "mlir/AsmParser/AsmParser.h"
#include "mlir/Dialect/Linalg/IR/Linalg.h"
#include "mlir/Dialect/Transform/IR/TransformDialect.h"
#include "mlir/Dialect/Transform/IR/TransformInterfaces.h"
#include "mlir/Interfaces/ViewLikeInterface.h"
#include "mlir/Parser/Parser.h"
#include "llvm/Support/Casting.h"

using namespace mlir;
using namespace mlir::transform;

namespace {
// A simple pattern rewriter that implements no special logic.
class SimpleRewriter : public PatternRewriter {
public:
  SimpleRewriter(MLIRContext *context) : PatternRewriter(context) {}
};
} // namespace

//===----------------------------------------------------------------------===//
// PackOp
//===----------------------------------------------------------------------===//

ParseResult transform::PackOp::parse(OpAsmParser &parser,
                                     OperationState &result) {

  OpAsmParser::UnresolvedOperand target;
  if (parser.parseOperand(target) ||
      parser.parseOptionalAttrDict(result.attributes))
    return failure();
  auto pdlOperationType = pdl::OperationType::get(parser.getContext());
  if (parser.resolveOperand(target, pdlOperationType, result.operands))
    return failure();
  result.addTypes(pdlOperationType);
  return success();
}

void PackOp::print(OpAsmPrinter &p) {
  p << ' ' << getTarget();
  p.printOptionalAttrDict((*this)->getAttrs());
}

DiagnosedSilenceableFailure
transform::PackOp::applyToOne(linalg::LinalgOp target,
                              SmallVector<Operation *> &results,
                              transform::TransformState &state) {
  SmallVector<int64_t> tiles = extractFromI64ArrayAttr(getPackingFactors());
  SimpleRewriter rewriter(target->getContext());
  rewriter.setInsertionPoint(target);
  SmallVector<OpFoldResult> tilesAsOpFold =
      getAsOpFoldResult(rewriter.getI64ArrayAttr(tiles));
  Operation *currentTarget = target;
  if (linalg::Conv2DNchwFchwOp convOp =
          dyn_cast<linalg::Conv2DNchwFchwOp>(currentTarget)) {
    FailureOr<linalg::GenericOp> blockedConv =
        mlir::linalgx::blockConv2DNchwFchwOp(rewriter, convOp, tilesAsOpFold);
    if (succeeded(blockedConv)) {
      results.push_back(*blockedConv);
      return DiagnosedSilenceableFailure(success());
    }
  }
  if (linalg::MatmulOp matmulOp = dyn_cast<linalg::MatmulOp>(currentTarget)) {
    FailureOr<linalg::GenericOp> blockedMatmul =
        mlir::linalgx::blockMatmulOp(rewriter, matmulOp, tilesAsOpFold);
    if (succeeded(blockedMatmul)) {
      results.push_back(*blockedMatmul);
      return DiagnosedSilenceableFailure(success());
    }
  }
  results.assign(1, nullptr);
  return DiagnosedSilenceableFailure::definiteFailure();
}

//===----------------------------------------------------------------------===//
// CollapseOp
//===----------------------------------------------------------------------===//

DiagnosedSilenceableFailure
transform::CollapseOp::applyToOne(linalg::LinalgOp target,
                                  SmallVector<Operation *> &results,
                                  transform::TransformState &state) {
  if (!isa<linalg::GenericOp>(target))
    return DiagnosedSilenceableFailure::definiteFailure();
  SimpleRewriter rewriter(target->getContext());
  rewriter.setInsertionPoint(target);
  FailureOr<linalg::GenericOp> collapsedOp = mlir::linalgx::collapseIterators(
      rewriter, cast<linalg::GenericOp>(target), getReassociationIndices());
  if (failed(collapsedOp))
    return DiagnosedSilenceableFailure::definiteFailure();
  results.push_back(*collapsedOp);
  return DiagnosedSilenceableFailure(success());
}

SmallVector<ReassociationIndices, 4>
transform::CollapseOp::getReassociationIndices() {
  SmallVector<ReassociationIndices, 4> reassociationIndices;
  for (auto attr : getReassociation())
    reassociationIndices.push_back(llvm::to_vector<2>(
        llvm::map_range(attr.cast<ArrayAttr>(), [&](Attribute indexAttr) {
          return indexAttr.cast<IntegerAttr>().getInt();
        })));
  return reassociationIndices;
}

//===----------------------------------------------------------------------===//
// MapToBrgemmOp
//===----------------------------------------------------------------------===//

DiagnosedSilenceableFailure
transform::MapToBrgemmOp::applyToOne(linalg::LinalgOp target,
                                     SmallVector<Operation *> &results,
                                     transform::TransformState &state) {
  if (!llvm::isa_and_nonnull<linalg::GenericOp>(target))
    return DiagnosedSilenceableFailure::success();
  SimpleRewriter rewriter(target->getContext());
  rewriter.setInsertionPoint(target);
  FailureOr<SmallVector<Value>> brgemmLoops =
      mlir::linalgx::mapToBRGEMMOp(rewriter, cast<linalg::GenericOp>(target));
  return DiagnosedSilenceableFailure(success());
}

//===----------------------------------------------------------------------===//
// MapConvToMatmulOp
//===----------------------------------------------------------------------===//

DiagnosedSilenceableFailure
transform::MapConvToMatmulOp::applyToOne(linalg::LinalgOp target,
                                         SmallVector<Operation *> &results,
                                         transform::TransformState &state) {
  if (!isa<linalg::GenericOp>(target))
    return DiagnosedSilenceableFailure::definiteFailure();
  SimpleRewriter rewriter(target->getContext());
  rewriter.setInsertionPoint(target);
  FailureOr<linalg::MatmulOp> matmul =
      mlir::linalgx::mapConvToGemm(rewriter, cast<linalg::GenericOp>(target),
                                   getFilterHeightPos(), getFilterWidthPos());
  if (failed(matmul))
    return DiagnosedSilenceableFailure::definiteFailure();
  results.push_back(*matmul);
  return DiagnosedSilenceableFailure(success());
}

//===----------------------------------------------------------------------===//
// Transform op registration
//===----------------------------------------------------------------------===//

namespace {

class LinalgTransformDialectExtension
    : public transform::TransformDialectExtension<
          LinalgTransformDialectExtension> {
public:
  using Base::Base;

  void init() {
    registerTransformOps<
#define GET_OP_LIST
#include "Standalone/Dialect/LinalgX/TransformOps/LinalgXTransformOps.cpp.inc"
        >();
  }
};
} // namespace

#define GET_OP_CLASSES
#include "Standalone/Dialect/LinalgX/TransformOps/LinalgXTransformOps.cpp.inc"

void mlir::linalgx::registerTransformDialectExtension(
    DialectRegistry &registry) {
  registry.addExtensions<LinalgTransformDialectExtension>();
}
