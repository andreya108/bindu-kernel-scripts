#!/bin/bash

BASE_DIR=`dirname $(readlink -e $0)`

if [ -z "$1" ]
  then
    echo "No argument supplied"
    echo "usage: ./`basename $0` [n] <config>"
    echo "n - fresh build [makeMk], otherwise r is assumed"
    exit 1
fi

BUILD_PROJECT_NAME=$1
shift
M=r
if [ ! -z "$2" ]
  then
    M=$2
fi

PROJECT=$BUILD_PROJECT_NAME

. $BASE_DIR/bindu.conf

# write new mtk ini
echo "project = $BUILD_PROJECT_NAME" > $BINDU_BUILD_ROOT/makeMtk.ini
echo "build_mode = user" >> $BINDU_BUILD_ROOT/makeMtk.ini

#increment and save build number
BUILD=$(($BINDU_BUILD+1))
echo "$BUILD" > $BINDU_BUILDSTORE

BUILD_ID="$BUILD_PROJECT_NAME-$BINDU_VERSION.$BUILD$EXTRA-$TOOLCHAIN";

export KBUILD_BUILD_USER=bindu-kernel
export KBUILD_BUILD_HOST="$MODEL"
export EXTRAVERSION="-bindu-$BINDU_VERSION.$BUILD$EXTRA"

cat <<EOT
=============================================================
Project                : $BUILD_PROJECT_NAME
Build Id               : $BUILD_ID
Toolchain Id           : $TOOLCHAIN
Toolchain path         : $TC_PATH
KBUILD_BUILD_HOST      : $KBUILD_BUILD_HOST
EXTRAVERSION           : $EXTRAVERSION
=============================================================
EOT

( cd $BINDU_BUILD_ROOT
  [ "$BUILD_LK" = "yes" ] && ./makeMtk $1 $M lk
  ./makeMtk -t $1 $M k
)

if [ "$?" = "0" ]; then
    PROJECT_OUT_DIR=$BINDU_BUILD_ROOT/out/target/product/$BUILD_PROJECT_NAME
    echo "$BUILD_ID" >                                      $BINDU_RELEASE_DIR/version.$BUILD_ID
    [ "$BUILD_LK" = "yes" ] && cp $PROJECT_OUT_DIR/lk.bin   $BINDU_RELEASE_DIR/lk.$BUILD_ID.bin
    cp $PROJECT_OUT_DIR/kernel_$BUILD_PROJECT_NAME.bin      $BINDU_RELEASE_DIR/kernel.$BUILD_ID.bin
    cp $PROJECT_OUT_DIR/obj/KERNEL_OBJ/arch/arm/boot/zImage $BINDU_RELEASE_DIR/$BUILD_ID.zImage
    cp $PROJECT_OUT_DIR/obj/KERNEL_OBJ/arch/arm/boot/Image  $BINDU_RELEASE_DIR/$BUILD_ID.Image

    case "$PACK_METHOD" in
        kpack)
            echo "call kpack.cmd $BUILD_PROJECT_NAME $BUILD_ID kernel.$BUILD_ID.bin" >> $BINDU_RELEASE_DIR/process.cmd
            ;;
        kpack2)
            echo "call kpack2.cmd $BUILD_PROJECT_NAME $BUILD_ID kernel.$BUILD_ID.bin lk.$BUILD_ID.bin" >> $BINDU_RELEASE_DIR/process2.cmd
            ;;
        zImage)
            mkdir -p ~/YD.share/bindu-kernel/$BUILD_PROJECT_NAME
            cp $PROJECT_OUT_DIR/obj/KERNEL_OBJ/arch/arm/boot/zImage ~/YD.share/bindu-kernel/$BUILD_PROJECT_NAME/$BUILD_ID.zImage
            echo "copy $BUILD_ID.zImage d:\\Yandex.Disk\\share\\bindu-kernel\\$BUILD_PROJECT_NAME" >> $BINDU_RELEASE_DIR/processz.cmd
            ;;
        *)
            echo "Unknown kernel packing!"
            exit 1;
            ;;
    esac
else
    echo "Build failed!" 1>&2
    exit 1
fi

