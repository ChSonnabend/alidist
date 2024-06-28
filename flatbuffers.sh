package: flatbuffers
version: v23.5.26
source: https://github.com/google/flatbuffers
requires:
  - zlib
build_requires:
  - CMake
  - "GCC-Toolchain:(?!osx)"
  - alibuild-recipe-tools
  - ninja
---
cmake "$SOURCEDIR"                                                                                                      \
      -G 'Ninja'                                                                                                        \
      -DFLATBUFFERS_BUILD_TESTS=OFF                                                                                     \
      -DCMAKE_INSTALL_PREFIX="$INSTALLROOT"                                                                          

make ${JOBS:+-j $JOBS}
make install

# Modulefile
mkdir -p "$INSTALLROOT/etc/modulefiles"
alibuild-generate-module --bin --lib --cmake > "$INSTALLROOT/etc/modulefiles/$PKGNAME"
