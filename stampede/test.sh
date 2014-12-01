#!/bin/bash
#SBATCH -p development
#SBATCH -t 02:00:00
#SBATCH -n 16
#SBATCH -A iPlant-Collabs 
#SBATCH -J test-BWA
#SBATCH -o test-BWA-index.o%j

module load python
module load pylauncher
module unload samtools
module unload bwa


cd ..

##./build.sh
tar xzf bin.tgz

##Fix the path so that it contains the bin directory
PATH=$PATH:`pwd`/bin

## Input (a fastq file)
INFILE=$WORK/sandbox/ecoli_mda_lane1.fastq
INDEX=${WORK}/sandbox/e_coli_idx
OUTFILE="e_coli_test.bam"
MATES=$WORK/sandbox/ecoli_mda_lane1.fastq

#Split it all up: 100K records per file
echo "Time to split file into files of 100K records a piece"
time python ./bin/split.py -i ${INFILE} -r 100000

# Split the paired reads file using the same settings.
time python ./bin/split.py -i ${MATES} -r 100000 -o "mate"

## Algorithm (we'll start with mem, but others may be appropriate)
if [ -e commandfile.txt ]
    then rm commandfile.txt
fi



for i in `ls ./temp | grep -o "[0-9]*"`
do
# ~/bioinformatica/bwa-0.7.10/bwa mem -t 2 bwa_index_hg19 test.fa | samtools view -S -b -u -| samtools sort -o -m 4G -@ 2 - - >> out.bam
    echo "bwa mem -t 4 ${ARGS} ${INDEX} ./temp/split_${i}.* ./temp/mate_${i}.* | samtools view -S -b -u - | samtools sort -o -m 4G -@ 4 - - >> ./temp/split_sorted_`echo ${i} | grep -o [0-9]*`.bam" >> commandfile.txt
done

python ./bin/launcher.py -i commandfile.txt -c 4

INTERMEDIATES=""
for i in `ls ./temp/ | grep "split_sorted"`
do
    INTERMEDIATES="${INTERMEDIATES} ./temp/${i}"
done

samtools merge -f $OUTFILE ${INTERMEDIATES}

rm -rf ./bin
rm -rf temp
