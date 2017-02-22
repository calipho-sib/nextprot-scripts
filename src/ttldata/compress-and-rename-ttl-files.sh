#!/bin/sh

copy_rename_touch_compress() {
  cp $1 $2
  [ "$touch_date" != "" ] && touch -t$touch_date $2
  gzip $2
  [ "$touch_date" != "" ] && touch -t$touch_date $2.gz
}


if [ "$1" = "?" ]; then 
  echo "usage: $0 MMDDhhmm "
  echo "where MMDDhhmm determines month, day, hour, minutes for timestamp of target files"  
  echo "exiting now"
  exit
fi

touch_date=$1
src_dir1=/work/ttldata/nobackup/export-ttl
src_dir2=/work/ttldata/nobackup/construct
trg_dir=/work/ttldata/ttl-compressed

latest_release=$(ls -1tr /mnt/npdata/dump/release/ | grep 20 | tail -n1)
qc_dir=/share/sib/common/Calipho/np/FTP/rdf/ttl

echo "latest release (unused) : $latest_release"
echo "target dir              : $trg_dir"
echo "qc dir         (unused) : $qc_dir"


# clear target directories

mkdir -p $trg_dir
rm -rf $trg_dir/*

#mkdir -p $qc_dir
#rm -f $qc_dir/*.gz


# rename and copy files in chromosome dir to target directory

copy_rename_touch_compress $src_dir1/1.ttl $trg_dir/nextprot_chromosome_01.ttl
copy_rename_touch_compress $src_dir1/2.ttl $trg_dir/nextprot_chromosome_02.ttl
copy_rename_touch_compress $src_dir1/3.ttl $trg_dir/nextprot_chromosome_03.ttl
copy_rename_touch_compress $src_dir1/4.ttl $trg_dir/nextprot_chromosome_04.ttl
copy_rename_touch_compress $src_dir1/5.ttl $trg_dir/nextprot_chromosome_05.ttl
copy_rename_touch_compress $src_dir1/6.ttl $trg_dir/nextprot_chromosome_06.ttl
copy_rename_touch_compress $src_dir1/7.ttl $trg_dir/nextprot_chromosome_07.ttl
copy_rename_touch_compress $src_dir1/8.ttl $trg_dir/nextprot_chromosome_08.ttl
copy_rename_touch_compress $src_dir1/9.ttl $trg_dir/nextprot_chromosome_09.ttl
copy_rename_touch_compress $src_dir1/10.ttl $trg_dir/nextprot_chromosome_10.ttl
copy_rename_touch_compress $src_dir1/11.ttl $trg_dir/nextprot_chromosome_11.ttl
copy_rename_touch_compress $src_dir1/12.ttl $trg_dir/nextprot_chromosome_12.ttl
copy_rename_touch_compress $src_dir1/13.ttl $trg_dir/nextprot_chromosome_13.ttl
copy_rename_touch_compress $src_dir1/14.ttl $trg_dir/nextprot_chromosome_14.ttl
copy_rename_touch_compress $src_dir1/15.ttl $trg_dir/nextprot_chromosome_15.ttl
copy_rename_touch_compress $src_dir1/16.ttl $trg_dir/nextprot_chromosome_16.ttl
copy_rename_touch_compress $src_dir1/17.ttl $trg_dir/nextprot_chromosome_17.ttl
copy_rename_touch_compress $src_dir1/18.ttl $trg_dir/nextprot_chromosome_18.ttl
copy_rename_touch_compress $src_dir1/19.ttl $trg_dir/nextprot_chromosome_19.ttl
copy_rename_touch_compress $src_dir1/20.ttl $trg_dir/nextprot_chromosome_20.ttl
copy_rename_touch_compress $src_dir1/21.ttl $trg_dir/nextprot_chromosome_21.ttl
copy_rename_touch_compress $src_dir1/22.ttl $trg_dir/nextprot_chromosome_22.ttl
copy_rename_touch_compress $src_dir1/X.ttl $trg_dir/nextprot_chromosome_X.ttl
copy_rename_touch_compress $src_dir1/Y.ttl $trg_dir/nextprot_chromosome_Y.ttl
copy_rename_touch_compress $src_dir1/MT.ttl $trg_dir/nextprot_chromosome_MT.ttl
copy_rename_touch_compress $src_dir1/unknown.ttl $trg_dir/nextprot_chromosome_unknown.ttl

copy_rename_touch_compress $src_dir1/experimentalcontext.ttl $trg_dir/experimentalcontext.ttl
copy_rename_touch_compress $src_dir1/publication.ttl $trg_dir/publication.ttl
copy_rename_touch_compress $src_dir1/schema.ttl $trg_dir/schema.ttl
copy_rename_touch_compress $src_dir1/terminology.ttl $trg_dir/terminology.ttl 


# rename and copy files in construct dir to target directory

copy_rename_touch_compress $src_dir2/high-expression.ttl $trg_dir/expression_high.ttl
copy_rename_touch_compress $src_dir2/medium-expression.ttl $trg_dir/expression_medium.ttl
copy_rename_touch_compress $src_dir2/low-expression.ttl $trg_dir/expression_low.ttl

copy_rename_touch_compress $src_dir2/inferredChildOf-a.ttl $trg_dir/inferredChildOf-a.ttl
copy_rename_touch_compress $src_dir2/inferredChildOf-b.ttl $trg_dir/inferredChildOf-b.ttl
copy_rename_touch_compress $src_dir2/inferredSubClassOf-a.ttl $trg_dir/inferredSubClassOf-a.ttl
copy_rename_touch_compress $src_dir2/inferredSubClassOf-b.ttl $trg_dir/inferredSubClassOf-b.ttl

echo "DONE"
exit 0


# what follows done elsewhere: in worksheet integration NP1
# now copy all compressed files of target directory to qc directory (mount of remote HD)

echo "copying compressed files to qc directory $qc_dir"
cp $trg_dir/*.gz $qc_dir/


# now touch target files with date specified in $1 <MMDDhhmm>
if [ "$touch_date" != "" ]; then
  echo "setting timestamp of files in qc directory"
  find $qc_dir/ -type f -exec touch -t$touch_date {} \;
  find $qc_dir/ -type d -exec touch -t$touch_date {} \;
fi
echo "DONE"


