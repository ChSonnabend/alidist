package: PyTorch
version: "%(tag_basename)s"
tag: "1.13.0"
build_requires:
  - alibuild-recipe-tools
  - curl:(?!osx)
prepend_path:
  # For C++ bindings.
  CMAKE_PREFIX_PATH: "$PYTORCH_ROOT/share/cmake"
---

export PYTORCH_ROCM_ARCH=gfx906
export USE_ROCM=1
# URL=https://download.pytorch.org/libtorch/rocm5.2/libtorch-cxx11-abi-shared-with-deps-1.13.0%2Brocm5.2.zip

case $ARCHITECTURE in
  osx_*)
    if [[ $ARCHITECTURE == *_x86-64 ]]; then
      echo "Installing PyTorch for MacOS (CPU version)"
      URL=https://download.pytorch.org/libtorch/cpu/libtorch-macos-x86_64-2.2.1.zip
    else
      echo "Installing PyTorch for MacOS (Metal backend)"
      URL=https://download.pytorch.org/libtorch/cpu/libtorch-macos-arm64-2.2.1.zip
    fi
  ;;
  *)
    if command -v rocminfo >/dev/null 2>&1; then
      echo "Installing PyTorch for ROCm"
      export PYTORCH_ROCM_ARCH=gfx906
      export USE_ROCM=1
      URL=https://download.pytorch.org/libtorch/rocm5.2/libtorch-cxx11-abi-shared-with-deps-1.13.0%2Brocm5.2.zip
    elif command -v nvcc >/dev/null 2>&1; then
      CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $NF}' | cut -d. -f1)
      if [[ "$CUDA_VERSION" == "V11" ]]; then
        echo "Installing PyTorch for CUDA 11.x"
        URL=https://download.pytorch.org/libtorch/cu118/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcu118.zip
      elif [[ "$CUDA_VERSION" == "V12" ]]; then
        echo "Installing PyTorch for CUDA 12.x"
        URL=https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcu121.zip
      else
        echo "CUDA version is not 11.x or 12.x, installing PyTorch basic CPU version"
        URL=https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcpu.zip
      fi
    else
      echo "Installing PyTorch basic CPU version"
      URL=https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcpu.zip
    fi
  ;;
esac

#!/bin/bash -e
curl -fSsLo pytorch.zip $URL
unzip -o pytorch.zip -d "$INSTALLROOT"
mv "$INSTALLROOT/libtorch"/* "$INSTALLROOT/"
rmdir "$INSTALLROOT/libtorch"

# Modulefile
mkdir -p "$INSTALLROOT/etc/modulefiles"
alibuild-generate-module --lib > "$INSTALLROOT/etc/modulefiles/$PKGNAME"