#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

JPEGLIB_VERSION="8c"
JPEGLIB_SOURCE_DIR="jpeg-$JPEGLIB_VERSION"

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

stage="$(pwd)/stage"

# load autbuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${JPEGLIB_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$JPEGLIB_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            case "${AUTOBUILD_VSVER:-}" in
                "120")
                    target="setup-v12"
                    ;;
                "150")
                    target="setup-v15"
                    ;;
                "160")
                    target="setup-v16"
                    ;;
                "170")
                    target="setup-v17"
                    ;;
                *)
                    echo "Unrecognized AUTOBUILD_VSVER = '${AUTOBUILD_VSVER:-}'" 1>&2 ; exit 1
                    ;;
            esac

            nmake -f makefile.vc "$target"

            msbuild.exe \
                -t:jpeg \
                -p:Configuration=Release \
                -p:Platform=$AUTOBUILD_WIN_VSPLATFORM \
                -p:PlatformToolset=v143 \
                jpeg.sln

            mkdir -p "$stage/lib/release"

            if [ "$AUTOBUILD_ADDRSIZE" = 32 ]
            then cp "Release\jpeg.lib" "$stage/lib/release/jpeglib.lib"
            else cp "x64\Release\jpeg.lib" "$stage/lib/release/jpeglib.lib"
            fi

            mkdir -p "$stage/include/jpeglib"
            cp {jconfig.h,jerror.h,jinclude.h,jmorecfg.h,jpeglib.h} "$stage/include/jpeglib"
        ;;
        darwin*)
            opts="-arch $AUTOBUILD_CONFIGURE_ARCH $LL_BUILD_RELEASE"
            export CFLAGS="$opts" 
            export CPPFLAGS="$opts" 
            export LDFLAGS="$opts"
            ./configure --prefix="$stage"
            make
            make install
            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
            mkdir -p "$stage/include/jpeglib"
            mv "$stage/include/"*.h "$stage/include/jpeglib/"
        ;;
        linux*)
            opts="-m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE"
            CFLAGS="$opts" CXXFLAGS="$opts" ./configure --prefix="$stage"
            make
            make install
            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
            mkdir -p "$stage/include/jpeglib"
            mv "$stage/include/"*.h "$stage/include/jpeglib/"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp README "$stage/LICENSES/jpeglib.txt"
popd
