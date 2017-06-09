#! /bin/bash
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

# zengwen @ WiNG

# sh -x

rel_ver=$(adb shell getprop ro.build.version.release)
# echo "$rel_ver" # 6.0.1
build_ver=$(adb shell getprop ro.build.id) # MMB29Q
product_ver=$(adb shell getprop ro.build.product) # angler

if [ $(test build_ver) = 'MMB29Q' ]; then
	# TODO: download bootimg according to
	# rel_ver and build_ver
	mkdir tmp/
fi;

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

echo " ";
echo "Done unpacking boot.img!";


# below two lines work for GNU
# sed -i -e 's/foo/bar/' target.file
# sed -i'' -e 's/foo/bar/' target.file

# for Mac OS X
# sed -i '' -e 's/foo/bar/' target.file

cd $(pwd/ramdisk)

# sed -n 's/^\(\/dev\/diag[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
# sed -n 's/^\(\/dev\/smd0[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
# sed -n 's/^\(\/dev\/smd11[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc

sed -i '' -e 's/^\(\/dev\/diag[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
sed -i '' -e 's/^\(\/dev\/smd0[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc
sed -i '' -e 's/^\(\/dev\/smd11[[:blank:]]*\)[[:digit:]]\{4\}/\10666/g' *.rc

echo " ";
echo "Done patching boot.img!";
# exit 0;

if [ -z "$(ls split_img/* 2> /dev/null)" -o -z "$(ls ramdisk/* 2> /dev/null)" ]; then
  echo "No files found to be packed/built.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - RepackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

if [ ! -z "$(ls *-new.* 2> /dev/null)" ]; then
  echo "Warning: Overwriting existing files!";
  echo " ";
fi;

if [ `stat -c %U ramdisk/* | head -n 1` = "root" ]; then
  sumsg=" (as root)";
fi;

rm -f ramdisk-new.cpio*;
case $1 in
  --original)
    echo "Repacking with original ramdisk...";;
  --level|*)
    echo "Packing ramdisk$sumsg...";
    echo " ";
    ramdiskcomp=`cat split_img/*-ramdiskcomp`;
    if [ "$1" = "--level" -a "$2" ]; then
      level="-$2";
      lvltxt=" - Level: $2";
    elif [ "$ramdiskcomp" = "xz" ]; then
      level=-1;
    fi;
    echo "Using compression: $ramdiskcomp$lvltxt";
    repackcmd="$ramdiskcomp $level";
    compext=$ramdiskcomp;
    case $ramdiskcomp in
      gzip) compext=gz;;
      lzop) compext=lzo;;
      xz) repackcmd="xz $level -Ccrc32";;
      lzma) repackcmd="xz $level -Flzma";;
      bzip2) compext=bz2;;
      lz4) repackcmd="$bin/$arch/lz4 $level -l stdin stdout";;
      *) abort; exit 1;;
    esac;
    if [ "$sumsg" ]; then
      cd ramdisk;
      sudo chown -R root.root *;
      sudo find . | sudo cpio -H newc -o 2> /dev/null | $repackcmd > ../ramdisk-new.cpio.$compext;
    else
      "$bin/$arch/mkbootfs" ramdisk | $repackcmd > ramdisk-new.cpio.$compext;
    fi;
    if [ ! $? -eq "0" ]; then
      abort;
      exit 1;
    fi;
    cd "$aik";;
esac;

echo " ";
echo "Getting build information...";
cd split_img;
kernel=`ls *-zImage`;               echo "kernel = $kernel";
if [ "$1" = "--original" ]; then
  ramdisk=`ls *-ramdisk.cpio*`;     echo "ramdisk = $ramdisk";
  ramdisk="split_img/$ramdisk";
else
  ramdisk="ramdisk-new.cpio.$compext";
fi;
cmdline=`cat *-cmdline`;            echo "cmdline = $cmdline";
board=`cat *-board`;                echo "board = $board";
base=`cat *-base`;                  echo "base = $base";
pagesize=`cat *-pagesize`;          echo "pagesize = $pagesize";
kerneloff=`cat *-kerneloff`;        echo "kernel_offset = $kerneloff";
ramdiskoff=`cat *-ramdiskoff`;      echo "ramdisk_offset = $ramdiskoff";
tagsoff=`cat *-tagsoff`;            echo "tags_offset = $tagsoff";
if [ -f *-second ]; then
  second=`ls *-second`;             echo "second = $second";  
  second="--second split_img/$second";
  secondoff=`cat *-secondoff`;      echo "second_offset = $secondoff";
  secondoff="--second_offset $secondoff";
fi;
if [ -f *-dtb ]; then
  dtb=`ls *-dtb`;                   echo "dtb = $dtb";
  dtb="--dt split_img/$dtb";
fi;
cd ..;

echo " ";
echo "Building image...";
echo " ";
"$bin/$arch/mkbootimg" --kernel "split_img/$kernel" --ramdisk "$ramdisk" $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff $dtb -o image-new.img;
if [ ! $? -eq "0" ]; then
  abort;
  exit 1;
fi;

echo "Done!";

if [fastboot flash boot image-new.img > /dev/null]; then
	echo " ";
	echo "Successfully flashed patched boot.img!";
	echo "Now iCellular can be used normally!";
	exit 0;
else
	abort;
	exit 1;
fi;


