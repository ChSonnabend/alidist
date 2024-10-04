package: ONNXRuntime
version: "%(tag_basename)s"
tag: v1.19.0
source: https://github.com/microsoft/onnxruntime
requires:
  - protobuf
  - re2
  - boost
  - abseil
build_requires:
  - CMake
  - alibuild-recipe-tools
  - "Python:(slc|ubuntu)"  # this package builds ONNX, which requires Python
  - "Python-system:(?!slc.*|ubuntu)"
prepend_path:
  ROOT_INCLUDE_PATH: "$ONNXRUNTIME_ROOT/include/onnxruntime"
---
#!/bin/bash -e

mkdir -p $INSTALLROOT

# Check ROCm build conditions
if { [ "$ALIBUILD_O2_FORCE_GPU" -ne 0 ] || [ "$ALIBUILD_ENABLE_HIP" -ne 0 ] || command -v rocminfo >/dev/null 2>&1; } && \
   { [ -z "$DISABLE_GPU" ] || [ "$DISABLE_GPU" -eq 0 ]; }; then
    export ORT_ROCM_BUILD=1
else
    export ORT_ROCM_BUILD=0
fi
# Check CUDA build conditions
if { [ "$ALIBUILD_O2_FORCE_GPU" -ne 0 ] || [ "$ALIBUILD_ENABLE_CUDA" -ne 0 ] || command -v nvcc >/dev/null 2>&1; } && \
   { [ -z "$DISABLE_GPU" ] || [ "$DISABLE_GPU" -eq 0 ]; }; then
    export ORT_CUDA_BUILD=1
else
    export ORT_CUDA_BUILD=0
fi

# Optional builds
### MIGraphX
if [ "$ORT_ROCM_BUILD" -eq 1 ] && [ $(find /opt/rocm* -name "libmigraphx*" -print -quit | wc -l 2>&1) -eq 1 ]; then
    export ORT_MIGRAPHX_BUILD=1
else
    export ORT_MIGRAPHX_BUILD=0
fi
### TensorRT
if [ "$ORT_CUDA_BUILD" -eq 1 ] && [ $(find /opt/rocm* -name "libnvinfer*" -print -quit | wc -l 2>&1) -eq 1 ]; then
    export ORT_TENSORRT_BUILD=1
else
    export ORT_TENSORRT_BUILD=0
fi

cmake "$SOURCEDIR/cmake"                                                                                    \
      -DCMAKE_INSTALL_PREFIX=$INSTALLROOT                                                                   \
      -DCMAKE_BUILD_TYPE=Release                                                                            \
      -DCMAKE_INSTALL_LIBDIR=lib                                                                            \
      -DPYTHON_EXECUTABLE=$(python3 -c "import sys; print(sys.executable)")                                 \
      -Donnxruntime_BUILD_UNIT_TESTS=OFF                                                                    \
      -Donnxruntime_PREFER_SYSTEM_LIB=ON                                                                    \
      -Donnxruntime_BUILD_SHARED_LIB=ON                                                                     \
      -DProtobuf_USE_STATIC_LIBS=ON                                                                         \
      -Donnxruntime_ENABLE_TRAINING=OFF                                                                     \
      ${PROTOBUF_ROOT:+-DProtobuf_LIBRARY=$PROTOBUF_ROOT/lib/libprotobuf.a}                                 \
      ${PROTOBUF_ROOT:+-DProtobuf_LITE_LIBRARY=$PROTOBUF_ROOT/lib/libprotobuf-lite.a}                       \
      ${PROTOBUF_ROOT:+-DProtobuf_PROTOC_LIBRARY=$PROTOBUF_ROOT/lib/libprotoc.a}                            \
      ${PROTOBUF_ROOT:+-DProtobuf_INCLUDE_DIR=$PROTOBUF_ROOT/include}                                       \
      ${PROTOBUF_ROOT:+-DProtobuf_PROTOC_EXECUTABLE=$PROTOBUF_ROOT/bin/protoc}                              \
      ${RE2_ROOT:+-DRE2_INCLUDE_DIR=${RE2_ROOT}/include}                                                    \
      ${BOOST_ROOT:+-DBOOST_INCLUDE_DIR=${BOOST_ROOT}/include}                                              \
      -Donnxruntime_USE_MIGRAPHX=${ORT_MIGRAPHX_BUILD}                                                      \
      -Donnxruntime_USE_ROCM=${ORT_ROCM_BUILD}                                                              \
      -Donnxruntime_ROCM_HOME=/opt/rocm                                                                     \
      -Donnxruntime_CUDA_HOME=/usr/local/cuda                                                               \
      -DCMAKE_HIP_COMPILER=/opt/rocm/llvm/bin/clang++                                                       \
      -D__HIP_PLATFORM_AMD__=1                                                                              \
      -DCMAKE_HIP_ARCHITECTURES=gfx906,gfx908                                                               \
      ${ALIBUILD_O2_OVERRIDE_HIP_ARCHS:+-DCMAKE_HIP_ARCHITECTURES=${ALIBUILD_O2_OVERRIDE_HIP_ARCHS}}        \
      -Donnxruntime_USE_COMPOSABLE_KERNEL=OFF                                                               \
      -Donnxruntime_USE_ROCBLAS_EXTENSION_API=ON                                                            \
      -Donnxruntime_USE_COMPOSABLE_KERNEL_CK_TILE=ON                                                        \
      -Donnxruntime_DISABLE_RTTI=OFF                                                                        \
      -DMSVC=OFF                                                                                            \
      -Donnxruntime_USE_CUDA=${ORT_CUDA_BUILD}                                                              \
      -Donnxruntime_USE_CUDA_NHWC_OPS=${ORT_CUDA_BUILD}                                                     \
      -Donnxruntime_CUDA_USE_TENSORRT=${ORT_TENSORRT_BUILD}                                                 \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS -Wno-unknown-warning -Wno-unknown-warning-option -Wno-pass-failed -Wno-error=unused-but-set-variable -Wno-pass-failed=transform-warning -Wno-error=deprecated" \
      -DCMAKE_C_FLAGS="$CFLAGS -Wno-unknown-warning -Wno-unknown-warning-option -Wno-pass-failed -Wno-error=unused-but-set-variable -Wno-pass-failed=transform-warning -Wno-error=deprecated"

cmake --build . -- ${JOBS:+-j$JOBS} install

# Modulefile
mkdir -p "$INSTALLROOT/etc/modulefiles"
MODULEFILE="$INSTALLROOT/etc/modulefiles/$PKGNAME"
alibuild-generate-module --lib > "$MODULEFILE"
cat >> "$MODULEFILE" <<EoF

# Our environment
set ${PKGNAME}_ROOT \$::env(BASEDIR)/$PKGNAME/\$version
prepend-path ROOT_INCLUDE_PATH \$${PKGNAME}_ROOT/include/onnxruntime
EoF
