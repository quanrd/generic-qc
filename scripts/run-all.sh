#!/bin/bash

set -a

input=/input
output=/output
tmpdir=$output/tmp
outputfqc=$output/fastqc
log=${output}/logs

mkdir -p $output $log $tmpdir $outputfqc

function runfastqc {
    basename=$1

    echo "starting: $basepath"

    tomerge=$(find $input -path "*${basename}*.fastq.gz"|sort)

    regularizedname=$(echo ${basename}|sed -e 's|/input/||g' -e 's|/|_|g')

    mergedfile=${tmpdir}/${regularizedname}.fastq.gz

    echo -e "$tomerge" > ${log}/${regularizedname}_merged.log

    if [ "$(echo $tomerge| wc -w)" == "1" ]; then
        # nothing to merge, create a link instead
        ln -s $tomerge $mergedfile
    else
        # actually merge the files
        cat $tomerge > $mergedfile
    fi


    fastqc \
        -o $outputfqc \
        -t $THREADS \
        $mergedfile

    rm $mergedfile
}

export -f runfastqc

pathsfile=$tmpdir/pathsfile.txt

find $input -name "*.fastq.gz" \
    | sort \
    | uniq \
    | sed -e 's/_[0-9]\{3\}.fastq.gz//g' \
    | sort \
    | uniq \
          > $pathsfile

parallel --eta --will-cite -j $JOBS runfastqc :::: $pathsfile

filelist=$tmpdir/logfilelist
find $outputfqc -name "*_fastqc.zip" >> $filelist

multiqc \
    -f \
    -o $output \
    --file-list $filelist

chmod -R a+w $output
chown -R nobody $output

rm -rf $outputfqc
rm -rf $tmpdir
