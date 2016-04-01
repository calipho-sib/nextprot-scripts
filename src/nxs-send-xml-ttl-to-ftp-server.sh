#!/bin/bash

ftp_server=ftp.nextprot.org
ftp_xml_dir=/local/ftpnextprot/root/pub/current_release/test/xml
ftp_ttl_dir=/local/ftpnextprot/root/pub/current_release/test/rdf/ttl

tmp_dir=/tmp/transfer

src_server=npteam@kant.isb-sib.ch
src_xml_dir=/work/ttldata/xml-compressed
src_ttl_dir=/work/ttldata/ttl-compressed

mkdir -p $tmp_dir

rm -r $tmp_dir/*
ssh ${ftp_server} mkdir -p ${ftp_xml_dir}
ssh ${ftp_server} rm -rf ${ftp_xml_dir}/*
scp ${src_server}:${src_xml_dir}/*.gz ${tmp_dir}/
scp $tmp_dir/* ${ftp_server}:${ftp_xml_dir}/

rm -r $tmp_dir/*
ssh ${ftp_server} mkdir -p ${ftp_ttl_dir}
ssh ${ftp_server} rm -rf ${ftp_ttl_dir}/*
scp ${src_server}:${src_ttl_dir}/*.gz ${tmp_dir}/
scp $tmp_dir/* ${ftp_server}:${ftp_ttl_dir}/

rm -rf $tmp_dir

