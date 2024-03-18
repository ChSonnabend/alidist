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

case $ARCHITECTURE in
  osx_*)
    if [[ $ARCHITECTURE == *_x86-64 ]]; then
      URL=https://download.pytorch.org/libtorch/cpu/libtorch-macos-x86_64-2.2.1.zip
    else
      URL=https://download.pytorch.org/libtorch/cpu/libtorch-macos-arm64-2.2.1.zip
    fi
  ;;
  *)
    URL=https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.2.1%2Bcpu.zip
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


case $ARCHITECTURE in
  osx_*) install_name_tool -add_rpath "$(brew --prefix libomp)/lib" "$INSTALLROOT/lib/libtorch_cpu.dylib"
  ;;
esac