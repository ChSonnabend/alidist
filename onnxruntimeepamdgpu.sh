package: ONNXRuntimeEPAMDGPU
version: "%(tag_basename)s"
tag: main
license: MIT
source: https://github.com/onnxruntime/onnxruntime-ep-amdgpu
requires:
  - ONNXRuntime
  - gpu-system
build_requires:
  - CMake
  - Python
  - ninja-fortran
  - alibuild-recipe-tools
---
#!/bin/bash -e

rsync -a --chmod=ug=rwX --delete --exclude '**/.git' --delete-excluded "$SOURCEDIR"/ ./

if [[ -f "$GPU_SYSTEM_ROOT/etc/gpu-features-available.sh" ]]; then
  source "$GPU_SYSTEM_ROOT/etc/gpu-features-available.sh"
fi

if [[ ${O2_GPU_ROCM_AVAILABLE:-0} != 1 ]]; then
  echo "ONNXRuntimeEPAMDGPU needs a ROCm/HIP gpu-system; O2_GPU_ROCM_AVAILABLE=${O2_GPU_ROCM_AVAILABLE:-unset}" >&2
  exit 1
fi

: "${O2_GPU_ROCM_HOME:=/opt/rocm}"

MIGRAPHX_HOME=
for _p in "${O2_GPU_ROCM_HOME}/lib/migraphx" "${O2_GPU_ROCM_HOME}"; do
  if [[ -f "$_p/include/migraphx/version.h" ]]; then
    MIGRAPHX_HOME=$_p
    break
  fi
done

if [[ -z "$MIGRAPHX_HOME" ]]; then
  echo "ONNXRuntimeEPAMDGPU needs MIGraphX headers with migraphx/version.h under O2_GPU_ROCM_HOME=$O2_GPU_ROCM_HOME" >&2
  exit 1
fi

# GCC's C++20 module dependency scanner interprets MIGraphX's method named
# "module" as a module declaration while scanning headers. The project does not
# use C++ modules, so disable scanning explicitly.
sed -i '/project(onnxruntime-ep-amdgpu/a set(CMAKE_CXX_SCAN_FOR_MODULES OFF)' CMakeLists.txt

# The MIGraphX CMake package in ROCm 6.x may not propagate the self-contained
# include prefix where migraphx/version.h lives.
sed -i "/target_link_libraries(migraphx-ep PRIVATE migraphx::c/a target_include_directories(migraphx-ep BEFORE PRIVATE \"$MIGRAPHX_HOME/include\")" src/migraphx/CMakeLists.txt

# Older ROCm/MIGraphX headers do not expose all data-type enum aliases used by
# the current plugin source. The TPC NN model uses float16, so keep building by
# marking only those newer types unsupported when their symbols are absent.
disable_migraphx_type_if_missing() {
  local onnx_type=$1
  local migraphx_type=$2

  if ! grep -R -q "$migraphx_type" "$MIGRAPHX_HOME/include/migraphx"; then
    echo "Disabling unsupported MIGraphX type mapping: $onnx_type -> $migraphx_type" >&2
    sed -i \
      -e "/case ${onnx_type}:/d" \
      -e "/${migraphx_type}/d" \
      src/migraphx/mgx_ep.cc
  fi
}

disable_migraphx_type_if_missing ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16 migraphx_shape_bf16_type
disable_migraphx_type_if_missing ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT8E5M2FNUZ migraphx_shape_fp8e5m2fnuz_type
disable_migraphx_type_if_missing ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT4E2M1 migraphx_shape_fp4x2_type

if grep -q "migraphx::quantize_fp8" src/migraphx/mgx_program_ops.cc; then
  echo "Disabling MIGraphX fp8 quantization path: quantize_fp8 API is unavailable" >&2
  perl -0pi -e 's/\s*\} else if \(fp8_enable\) \{\n\s*migraphx::quantize_fp8_options options;\n\s*options\.add_calibration_data\(params\);\n\s*migraphx::quantize_fp8\(prog, target, options\);\n\s*\}/\n        }/s' \
    src/migraphx/mgx_program_ops.cc
fi

if ! grep -R -q "quantize_bf16" "$MIGRAPHX_HOME/include/migraphx"; then
  echo "Disabling MIGraphX bf16 quantization path: quantize_bf16 API is unavailable" >&2
  perl -0pi -e 's/\n    if \(bf16_enable\) \{\n        migraphx::quantize_bf16\(prog\);\n    \}//s' \
    src/migraphx/mgx_program_ops.cc
fi

if ! grep -R -q "set_compile_mode" "$MIGRAPHX_HOME/include/migraphx"; then
  echo "Disabling MIGraphX compile-mode option: set_compile_mode API is unavailable" >&2
  sed -i \
    -e '/migraphx_compile_mode_/d' \
    -e '/options.set_compile_mode/d' \
    src/migraphx/mgx_program_ops.cc
fi

if ! grep -R -q "set_advance_backend_option" "$MIGRAPHX_HOME/include/migraphx"; then
  echo "Disabling MIGraphX advanced backend options: set_advance_backend_option API is unavailable" >&2
  perl -0pi -e 's/\n    if \(!mlss_use_specific_ops\.empty\(\)\) \{.*?\n    \}\n    prog\.compile/\n    prog.compile/s' \
    src/migraphx/mgx_program_ops.cc
fi

if grep -q "migraphx::get_onnx_operators" src/migraphx/mgx_ep.cc; then
  echo "Using static ONNX operator allowlist: get_onnx_operators API is unavailable" >&2
  perl -0pi -e 's/const auto v\{migraphx::get_onnx_operators\(\)\}; return \{v\.begin\(\), v\.end\(\)\};/return {"Abs", "Acos", "Acosh", "Add", "And", "ArgMax", "ArgMin", "Asin", "Asinh", "Atan", "Atanh", "AveragePool", "BatchNormalization", "Cast", "Ceil", "Clip", "Concat", "Constant", "ConstantOfShape", "Conv", "ConvTranspose", "Cos", "Cosh", "Div", "Dropout", "Elu", "Equal", "Erf", "Exp", "Expand", "Flatten", "Floor", "Gather", "Gemm", "GlobalAveragePool", "GlobalMaxPool", "Greater", "GreaterOrEqual", "HardSigmoid", "Identity", "LeakyRelu", "Less", "LessOrEqual", "Log", "MatMul", "Max", "MaxPool", "Min", "Mul", "Neg", "Not", "Or", "Pad", "Pow", "PRelu", "Reciprocal", "ReduceMax", "ReduceMean", "ReduceMin", "ReduceProd", "ReduceSum", "Relu", "Reshape", "Resize", "Shape", "Sigmoid", "Sin", "Sinh", "Slice", "Softmax", "Sqrt", "Squeeze", "Sub", "Sum", "Tan", "Tanh", "Transpose", "Unsqueeze", "Where"};/' \
    src/migraphx/mgx_ep.cc
fi

BUILD_DIR=build.AMDGPU
BUILD_ARGS=(
  --config Release
  --cmake_generator Ninja
  --onnxrt_home "$ONNXRUNTIME_ROOT"
  --use_amdgpu
  --hip_path "$O2_GPU_ROCM_HOME"
  --build_dir "$BUILD_DIR"
  --compile_no_warning_as_error
  --cmake_extra_defines
  CMAKE_CXX_SCAN_FOR_MODULES=OFF
  CMAKE_INCLUDE_DIRECTORIES_BEFORE=ON
)

if [[ -n "$MIGRAPHX_HOME" ]]; then
  BUILD_ARGS+=(--migraphx_home "$MIGRAPHX_HOME")
fi

if [[ -n "$JOBS" ]]; then
  BUILD_ARGS+=(--parallel "$JOBS")
else
  BUILD_ARGS+=(--parallel)
fi

./build.sh "${BUILD_ARGS[@]}"

mkdir -p "$INSTALLROOT/lib"

mapfile -t PROVIDER_LIBS < <(find "$BUILD_DIR" -type f -name '*.so' | sort)
if [[ ${#PROVIDER_LIBS[@]} -eq 0 ]]; then
  echo "Could not find any shared libraries produced by the AMDGPU plugin build" >&2
  exit 1
fi

for _lib in "${PROVIDER_LIBS[@]}"; do
  cp -av "$_lib" "$INSTALLROOT/lib/"
done

AMDGPU_PLUGIN=$(find "$INSTALLROOT/lib" -type f \( -name '*amdgpu-ep*.so' -o -name '*amdgpu*.so' \) | sort | head -n1)
if [[ -z "$AMDGPU_PLUGIN" ]]; then
  echo "Provider libraries were installed, but none looked like an AMDGPU/HIP plugin:" >&2
  find "$INSTALLROOT/lib" -type f -name '*.so' -print >&2
  exit 1
fi

if ! nm -D "$AMDGPU_PLUGIN" | grep -q 'CreateEpFactories'; then
  echo "The selected provider library does not export CreateEpFactories: $AMDGPU_PLUGIN" >&2
  exit 1
fi

MODULEFILE="$INSTALLROOT/etc/modulefiles/$PKGNAME"
mkdir -p "$(dirname "$MODULEFILE")"
alibuild-generate-module --lib > "$MODULEFILE"
cat >> "$MODULEFILE" <<EoF
setenv ONNXRUNTIME_EP_AMDGPU_PLUGIN \$PKG_ROOT/lib/$(basename "$AMDGPU_PLUGIN")
EoF
