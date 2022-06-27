#!/bin/bash

BASE=$(pwd)

# This assume you built the sandbox as described in the readme.
LIB_PATH=$BASE/../../build/lib
BIN_PATH=$BASE/../../build/bin

# make standalone-opt (TPP compiler) available.
export PATH=${BIN_PATH}:$PATH

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if ! command -v standalone-opt &> /dev/null
then
  echo "standalone-opt could not be found"
  exit
fi

if ! command -v mlir-translate &> /dev/null
then
  echo "mlir-translate could not be found"
  exit
fi

if ! command -v llc &> /dev/null
then
  echo "llc could not be found"
  exit
fi

if ! command -v clang &> /dev/null
then
  echo "clang could not be found"
  exit
fi

# Clang.
which clang

# Assembler.
which llc

# LLVM MLIR IR to LLVM IR.
which mlir-translate

# TPP compiler.
which standalone-opt

# Compile driver. 
clang -O3 -emit-llvm -S matmul_driver.c
llc matmul_driver.ll

# Fire tpp compiler.
standalone-opt matmul_kernel.mlir -tpp-compiler="enable-xsmm-conversion" | mlir-translate -mlir-to-llvmir -o matmul_kernel.ll
llc matmul_kernel.ll

# Merge them.
unamestr=$(uname)
if [[ "$unamestr" == 'Darwin' ]]; then
  export DYLD_LIBRARY_PATH=$LIB_PATH
else
  export LD_LIBRARY_PATH=$LIB_PATH
fi

clang -O3 matmul_driver.s matmul_kernel.s -L$LIB_PATH -lstandalone_c_runner_utils -o matmul

# Execute and check result.
./matmul > result.txt 2>&1

if cat result.txt | grep "Result is correct" &> /dev/null ; then
  printf "${GREEN} OK ${NC} \n"
else
  printf "${RED} Oh NO ${NC} \n";
fi

rm matmul
rm *.s
rm *.ll
rm result.txt
