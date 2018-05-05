#!/bin/sh
######################################################################
#
#    Copyright 2004 Sony Corporation
#
#    This software is provided "as is" without warranty of any kind,
#    either expressed or implied, including but not limited to the
#    implied warranties of fitness for a particular purpose.
#
# This script builds the following tools so as to be used with OPEN-R
# SDK.
#
#      binutils-2.14
#      gcc-3.3.6
#      newlib-1.10.0
#
# Run the script in the directory where the source packages (.tar.gz
# or .tar.bz2 files) of the above tools are placed.
#
# NOTE: this script was modified (not by Sony) to use gcc 3.3.6
#
######################################################################

# Constants

# Installation directory
PREFIX=/usr/local/OPEN_R_SDK

# Target name
#     Note: The target name `mipsel-linux' does not mean that Linux is
#           running on AIBO.  `linux' is specified just for enabling
#           PIC code generation.
TARGET=mipsel-linux

# source packages
BINUTILS=binutils-2.14
GCC=gcc-3.3.6
NEWLIB=newlib-1.10.0
GCC_PATCHSET=gcc-3.3.6-patches-1.4

PACKAGES="BINUTILS GCC NEWLIB GCC_PATCHSET"

BINUTILS_BLD=bld-$BINUTILS
GCC_BLD=bld-$GCC
NEWLIB_BLD=bld-$NEWLIB

GENTOO_MIRROR_DIST="http://dev.gentoo.org/~vapier/dist/"


######################################################################
# Functions

#apply gentoo's gcc patches. this function is also based on gentoo's eutils.class.
apply_gcc_patches() {

    pushd . > /dev/null
    cd $GCC

    for f in `ls -1 ../patch/*.patch`
    do

        echo -n "patching gcc with $f... "

        if ( ! echo $f | grep _all_ > /dev/null )
        then
            echo "skipped"
            continue
        fi

        local count=0

        while [ "${count}" -lt 5 ]
        do

            if (cat $f | patch -g0 -E --no-backup-if-mismatch -p${count} --dry-run -f ) &> /dev/null
            then
                echo "ok with -p${count}"
                cat $f | patch -g0 -E --no-backup-if-mismatch -p${count} --quiet
                break;
            fi
            count=$((count + 1))
        done

        if [ "${count}" -ge 5 ]
        then
            echo "failed!"
        fi

    done

    popd > /dev/null

}


######################################################################
# Preparation
#

# download the gentoo patchset automatically to enable gcc 3.3.x to be built with newer gcc versions
if [ ! -f $GCC_PATCHSET.tar.bz2 ]; then
    URL=${GENTOO_MIRROR_DIST}${GCC_PATCHSET}.tar.bz2
    if ( ! wget "${URL}" ); then
        echo "Couldn't download $GCC_PATCHSET.tar.bz2 automatically. Please download it manually from ${URL}"
	exit 1
    fi
fi

# Confirm the source packages exists
for p in $PACKAGES; do
    pkg=${!p}; #p is the variable name, pkg is the actual package name
    if [ ! -f "$pkg.tar.gz" -a ! -f "$pkg.tar.bz2" ] ; then
        echo $pkg not found in the current directory, exiting. 1>&2
        exit 1
    fi
done

# Confirm the directory $PREFIX exists and is writable
if mkdir -p $PREFIX/tmp$$ > /dev/null 2>&1; then
    # OK; $PREFIX is writable directory
    rmdir $PREFIX/tmp$$
else
    echo Please create the writable directory $PREFIX.   Exiting. 1>&2
    exit 1
fi

for p in $PACKAGES ; do
    pkg=${!p}; #p is the variable name, pkg is the actual package name
    if [ -f "$pkg.tar.gz" ] ; then
        echo "Unpacking $pkg.tar.gz..."
        tar xzf "$pkg.tar.gz" || exit
    elif [ -f "$pkg.tar.bz2" ] ; then
        echo "Unpacking $pkg.tar.bz2..."
        tar xjf "$pkg.tar.bz2" || exit
    else
        echo "Could not find $pkg.tar.{gz,bz2}"
        exit 1;
    fi;
done

######################################################################
# Applying patches
#

apply_gcc_patches

# --------------------------------------------------------------------
# Make libstdc++-v3 use newlib
patch -p0 <<'EOF' || exit
--- gcc-3.3.6/libstdc++-v3/configure.orig	2003-09-11 12:08:35.000000000 +0900
+++ gcc-3.3.6/libstdc++-v3/configure	2003-11-18 15:12:29.552891100 +0900
@@ -4213,7 +4213,8 @@
   # GLIBCPP_CHECK_MATH_SUPPORT
 
   case "$target" in
-    *-linux*)
+#    *-linux*)
+    *-linux-nevermatch*)
       os_include_dir="os/gnu-linux"
       for ac_hdr in nan.h ieeefp.h endian.h sys/isa_defs.h \
         machine/endian.h machine/param.h sys/machine.h sys/types.h \
EOF

# --------------------------------------------------------------------
# BUFSIZ defined in newlib's stdio.h is too small for AIBO's file
# system.
patch -p0 <<'EOF' || exit
--- newlib-1.10.0/newlib/libc/include/stdio.h.orig	Mon Oct  7 17:19:42 2002
+++ newlib-1.10.0/newlib/libc/include/stdio.h	Mon Oct  7 17:20:00 2002
@@ -92,7 +92,7 @@
 #ifdef __BUFSIZ__
 #define	BUFSIZ		__BUFSIZ__
 #else
-#define	BUFSIZ		1024
+#define	BUFSIZ		16384
 #endif
 
 #ifdef __FOPEN_MAX__
EOF

# --------------------------------------------------------------------
# vfprintf modified not to use too much stack size
patch -p0 <<'EOF' || exit
--- newlib-1.10.0/newlib/libc/stdio/vfprintf.c.orig	Mon Oct  7 17:22:28 2002
+++ newlib-1.10.0/newlib/libc/stdio/vfprintf.c	Mon Oct  7 17:22:50 2002
@@ -429,9 +429,12 @@
 		return (EOF);
 
 	/* optimise fprintf(stderr) (and other unbuffered Unix files) */
+/* comment out: __sbprintf requires too large stack size (> BUFSIZ) */
+#if 0
 	if ((fp->_flags & (__SNBF|__SWR|__SRW)) == (__SNBF|__SWR) &&
 	    fp->_file >= 0)
 		return (__sbprintf(fp, fmt0, ap));
+#endif
 
 	fmt = (char *)fmt0;
 	uio.uio_iov = iovp = iov;
EOF

######################################################################
# Building binutils
#

rm -fr $BINUTILS_BLD
mkdir $BINUTILS_BLD || exit
echo Configuring $BINUTILS
(cd $BINUTILS_BLD; ../$BINUTILS/configure --prefix=$PREFIX \
                                          --target=$TARGET) || exit

echo Making $BINUTILS
(cd $BINUTILS_BLD; make) || exit

echo Installing $BINUTILS
(cd $BINUTILS_BLD; make install) || exit

######################################################################
# Building gcc
#

# $TARGET-ar must be found via PATH
export PATH="$PREFIX/bin:$PATH"

cp -R $NEWLIB/newlib/libc/include $PREFIX/mipsel-linux

rm -fr $GCC_BLD
mkdir $GCC_BLD || exit
echo Configuring $GCC
(cd $GCC_BLD; ../$GCC/configure --prefix=$PREFIX \
                                --target=$TARGET \
                                --with-gnu-as \
                                --with-gnu-ld \
                                --with-headers=../$NEWLIB/newlib/libc/include \
                                --with-as=$PREFIX/bin/$TARGET-as \
                                --with-ld=$PREFIX/bin/$TARGET-ld \
                                --disable-shared \
                                --enable-languages=c,c++ \
                                --disable-threads \
                                --with-newlib) || exit

echo Making $GCC
(cd $GCC_BLD; make) || exit

echo Installing $GCC
(cd $GCC_BLD; make install) || exit

######################################################################
# Building newlib
#

rm -fr $NEWLIB_BLD
mkdir $NEWLIB_BLD || exit
echo Configuring $NEWLIB
(cd $NEWLIB_BLD; ../$NEWLIB/configure --prefix=$PREFIX \
                                      --target=$TARGET) || exit

echo Making $NEWLIB
(cd $NEWLIB_BLD; make) || exit

echo Installing $NEWLIB
(cd $NEWLIB_BLD; make install) || exit

######################################################################
# Creating libc-.a
#
# Some functions in libc.a have improper implementation.  Correct
# version of them are provided by libapsys.a.  To avoid mislinking, we
# use libc-.a, from which the duplicated functions are removed.

echo Creating $PREFIX/$TARGET/lib/libc-.a
cp $PREFIX/$TARGET/lib/libc.a $PREFIX/$TARGET/lib/libc-.a || exit
$PREFIX/bin/$TARGET-ar d $PREFIX/$TARGET/lib/libc-.a \
        mallocr.o freer.o reallocr.o callocr.o cfreer.o malignr.o \
	vallocr.o pvallocr.o mallinfor.o mallstatsr.o msizer.o malloptr.o \
        calloc.o malign.o msize.o mstats.o mtrim.o realloc.o valloc.o malloc.o \
	abort.o sbrkr.o exit.o rename.o || exit
$PREFIX/bin/$TARGET-ranlib $PREFIX/$TARGET/lib/libc-.a || exit
echo Done
