#!/bin/sh

copy_rename_touch_compress() {
  cp $1 $2
  [ "$touch_date" != "" ] && touch -t$touch_date $2
  gzip $2
  [ "$touch_date" != "" ] && touch -t$touch_date $2.gz
}

if [ "$1" = "?" ]; then 
  echo "usage: $0 [MMDDhhmm] "
  echo "where MMDDhhmm determines month, day, hour, minutes for timestamp of target files"  
  echo "exiting now"
  exit
fi

touch_date=$1
src_dir1=/work/ttldata/export-xml
trg_dir=/work/ttldata/xml-compressed

echo "target dir              : $trg_dir"

# clear target directories

mkdir -p $trg_dir
rm -rf $trg_dir/*

# rename, copy and compress files in export-xml dir to target directory

copy_rename_touch_compress $src_dir1/1.xml $trg_dir/nextprot_chromosome_01.xml
copy_rename_touch_compress $src_dir1/2.xml $trg_dir/nextprot_chromosome_02.xml
copy_rename_touch_compress $src_dir1/3.xml $trg_dir/nextprot_chromosome_03.xml
copy_rename_touch_compress $src_dir1/4.xml $trg_dir/nextprot_chromosome_04.xml
copy_rename_touch_compress $src_dir1/5.xml $trg_dir/nextprot_chromosome_05.xml
copy_rename_touch_compress $src_dir1/6.xml $trg_dir/nextprot_chromosome_06.xml
copy_rename_touch_compress $src_dir1/7.xml $trg_dir/nextprot_chromosome_07.xml
copy_rename_touch_compress $src_dir1/8.xml $trg_dir/nextprot_chromosome_08.xml
copy_rename_touch_compress $src_dir1/9.xml $trg_dir/nextprot_chromosome_09.xml
copy_rename_touch_compress $src_dir1/10.xml $trg_dir/nextprot_chromosome_10.xml
copy_rename_touch_compress $src_dir1/11.xml $trg_dir/nextprot_chromosome_11.xml
copy_rename_touch_compress $src_dir1/12.xml $trg_dir/nextprot_chromosome_12.xml
copy_rename_touch_compress $src_dir1/13.xml $trg_dir/nextprot_chromosome_13.xml
copy_rename_touch_compress $src_dir1/14.xml $trg_dir/nextprot_chromosome_14.xml
copy_rename_touch_compress $src_dir1/15.xml $trg_dir/nextprot_chromosome_15.xml
copy_rename_touch_compress $src_dir1/16.xml $trg_dir/nextprot_chromosome_16.xml
copy_rename_touch_compress $src_dir1/17.xml $trg_dir/nextprot_chromosome_17.xml
copy_rename_touch_compress $src_dir1/18.xml $trg_dir/nextprot_chromosome_18.xml
copy_rename_touch_compress $src_dir1/19.xml $trg_dir/nextprot_chromosome_19.xml
copy_rename_touch_compress $src_dir1/20.xml $trg_dir/nextprot_chromosome_20.xml
copy_rename_touch_compress $src_dir1/21.xml $trg_dir/nextprot_chromosome_21.xml
copy_rename_touch_compress $src_dir1/22.xml $trg_dir/nextprot_chromosome_22.xml
copy_rename_touch_compress $src_dir1/X.xml $trg_dir/nextprot_chromosome_X.xml
copy_rename_touch_compress $src_dir1/Y.xml $trg_dir/nextprot_chromosome_Y.xml
copy_rename_touch_compress $src_dir1/MT.xml $trg_dir/nextprot_chromosome_MT.xml
copy_rename_touch_compress $src_dir1/unknown.xml $trg_dir/nextprot_chromosome_unknown.xml
copy_rename_touch_compress $src_dir1/nextprot_all.xml $trg_dir/nextprot_all.xml
copy_rename_touch_compress $src_dir1/nextprot-export-v2.xsd $trg_dir/nextprot-export-v2.xsd

# we want an uncompressed version of the xsd
gunzip $trg_dir/nextprot-export-v2.xsd

echo DONE

