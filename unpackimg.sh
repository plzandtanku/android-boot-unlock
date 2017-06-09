#!/bin/sh
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { $sudo rm -rf ramdisk split_img *new.*; }
abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --sudo) sudo=sudo; sumsg=" (as root)"; shift;;
esac;

aik="$(cd "$(dirname "$0")"; pwd)";
bin="$aik/bin";
chmod -R 755 "$bin" "$aik"/*.sh;
chmod 644 "$bin/magic";
cd "$aik";
pwd

arch=`uname -m`;

if [ $(uname) = 'Darwin' ]; then
  echo "Arch is Mac OS X";
  arch='darwin_x86_64';
  echo "arch = $arch";
fi;

if [ ! "$1" -o ! -f "$1" ]; then
  echo "No image file supplied.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

file=$(basename "$1");
echo "Supplied image: $file";
echo " ";

if [ -d split_img -o -d ramdisk ]; then
  echo "Removing old work folders and files...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

echo 'Splitting image to "split_img/"...';
"$bin/$arch/unpackbootimg" -i "$1" -o split_img;
if [ ! $? -eq "0" ]; then
  cleanup;
  abort;
  exit 1;
fi;

cd split_img;
file -m "$bin/magic" *-ramdisk.gz | cut -d: -f2 | awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/$arch/lz4 -dq"; extra="stdout";;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv "$file-ramdisk.gz" "$file-ramdisk.cpio$compext";
cd ..;

echo " ";
echo "Unpacking ramdisk$sumsg to \"ramdisk/\"...";
echo " ";
cd ramdisk;
echo "Compression used: $ramdiskcomp";
if [ ! "$compext" ]; then
  abort;
  exit 1;
fi;
$unpackcmd "../split_img/$file-ramdisk.cpio$compext" $extra | $sudo cpio -i;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;
cd ..;

echo $(pwd)

# below two lines work for GNU
# sed -i -e 's/foo/bar/' target.file
# sed -i'' -e 's/foo/bar/' target.file

# sed -n 's/^\(\/dev\/diag[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
# sed -n 's/^\(\/dev\/smd0[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
# sed -n 's/^\(\/dev\/smd11[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
# sed -n 's/rm\([[:blank:]]*\/dev\/diag\)/ls\1/g' *.rc

# for Mac OS X
# sed -i '' -e 's/foo/bar/' target.file

cd $(pwd)/ramdisk

echo "Patching radio device permissions: /dev/diag, /dev/smd0, /dev/smd11...";
sed -i '' -e 's/^\(\/dev\/diag[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
sed -i '' -e 's/^\(\/dev\/smd0[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
sed -i '' -e 's/^\(\/dev\/smd11[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
sed -i '' -e 's/rm\([[:blank:]]*\/dev\/diag\)/ls\1/g' *.rc

echo " ";
echo "Done!";
exit 0;

