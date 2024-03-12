package: PyTorch
version: "%(tag_basename)s"
tag: "2.2.1"
build_requires:
  - alibuild-recipe-tools
  - curl:(?!osx)
prepend_path:
  # For C++ bindings.
  CMAKE_PREFIX_PATH: "$PYTORCH_ROOT/share/cmake"
---
#!/bin/bash -e
curl -fSsLo pytorch.zip "https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcpu.zip"
unzip -o pytorch.zip -d "$INSTALLROOT"
mv "$INSTALLROOT/libtorch"/* "$INSTALLROOT/"
rmdir "$INSTALLROOT/libtorch"

# Modulefile
mkdir -p "$INSTALLROOT/etc/modulefiles"
alibuild-generate-module --lib > "$INSTALLROOT/etc/modulefiles/$PKGNAME"