#!/bin/bash

tar xzf bin.tgz
PATH=$PATH:`pwd`/bin
## File to split
INFILE="${infile}"

## File containing read mates
MATES="${MATES}"

## Basename of the outfile.
OUTFILE="${OUTPUT}"

## Number of slices
SLICES="${slices}"

## Max number of records per slice
RECORDS="${records}"

## BWA Algorithm to use for analysis
ALG="${ALG}"

## Reference genome for alignment
BWAINDEX="${BWAINDEX}"

## The number of threads to use for each BWA process
THREADS=4

## Split the input file into smaller files
time python ./bin/split.py -i ${INFILE} -r ${RECORDS}

## If there are paired ends, split them as well
## Needs to rename/relabel splits to make sure they don't overlap
## python ./bin/split.py -i ${MATES} -r ${RECORDS}
time python ./bin/split.py -i ${MATES} -r 100000 -o "mate"




## Build up the ARGS string to pass to BWA based on user input
ARGS=""

if [ -n "${minSeedLength}" ]; then ARGS="${ARGS} -k ${qualityForTrimming}"; fi
if [ -n "${bandWidth}" ]; then ARGS="${ARGS} -w ${bandWidth}"; fi
if [ -n "${zDropoff}" ]; then ARGS="${ARGS} -d ${zDropoff}"; fi
if [ -n "${reSeedFactor}" ]; then ARGS="${ARGS} -r ${reSeedFactor}"; fi

if [ -n "${trimDupsThreshold}" ]; then ARGS="${ARGS} -c ${trimDupsThreshold}"; fi
if [ -n "${interleavedPairedEnd}" ]; then ARGS="${ARGS} -P"; fi
if [ -n "${readGroupHeader}" ]; then ARGS="${ARGS} -R ${readGroupHeader}"; fi
if [ -n "${alignmentScoreThreshold}" ]; then ARGS="${ARGS} -T ${alignmentScoreThreshold}"; fi
if [ -n "${outputAllAlignments}" ]; then ARGS="${ARGS} -a"; fi
if [ -n "${appendFastaComments}" ]; then ARGS="${ARGS} -C"; fi
if [ -n "${hardClipping}" ]; then ARGS="${ARGS} -H"; fi
if [ -n "${markSecondaries}" ]; then ARGS="${ARGS} -M"; fi
if [ -n "${verbose}" ]; then ARGS="${ARGS} -v ${verbose}"; fi


## Run BWA on the splits using PyLauncher
## Use four cores per BWA thread. BWA scales relatively
## poorly beyond 4 threads, at which point it is better to simply
## split the input file into more intermediate files.
## First, remove and previous commandfiles.
if [ -e commandfile.txt ]
    then rm commandfile.txt
fi

for i in `ls | grep -o "[0-9]*"`
do
    echo "bwa mem -t 4 ${ARGS} ${INDEX} ./temp/split_${i}\.* ./temp/mate_${i}\.* | samtools view -S -b -u - | samtools sort -o -m 4G -@ 4 - - >> ./temp/split_sorted_${i}.bam" >> commandfile.txt
done

python ./bin/launcher.py -i commandfile -c 4

## Splice the output back together
INTERMEDIATES=""
for i in `ls ./temp/ | grep "split_sorted" | sort`
do
    INTERMEDIATES="${INTERMEDIATES} ./temp/${i}"
done

samtools merge -f $OUTFILE $INTERMEDIATES

## python splice.py -o ${OUTFILE}


## Clean up all the mess we brought with us so it doesn't
## get pushed back.
rm -rf temp
rm -rf bin
