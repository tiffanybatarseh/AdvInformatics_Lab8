#!/bin/bash
#$ -N advinf_ATACseq_counts
#$ -q class
#$ -pe openmp 2
#$ -R y
#$ -t 1-24
#$ -m beas

module load bwa/0.7.8
module load samtools/1.3
module load bcftools/1.3
module load enthought_python/7.3.2
module load java/1.7
module load gatk/2.4-7
module load picard-tools/1.87
module load bowtie2/2.2.7
module load tophat/2.1.0
module load bamtools/2.3.0 # bamtools merge is useful
module load freebayes/0.9.21 # fasta_generate_regions.py is useful
module load vcftools/0.1.15

ref="/pub/tbatarse/Bioinformatics_Course/ref/dmel-all-chromosome-r6.13.fasta"
prefix=`head -n $SGE_TASK_ID ATACseq.prefixes.txt | tail -n 1 | cut -f2`

# Option #1 -- quick and dirty look at the data by just looking at coverage|position for each sample
#a=sample_1_R1_001.fastq.gz
#b=sample_1_R2_001.fastq.gz

#bwa mem -t 4 -M $ref $a $b | samtools view -bS - > sample_1.bam

#samtools sort sample_1.bam -o sample_1.sort.bam

#samtools index sample_1.sort.bam

# normalize across samples
Nreads=`samtools view -c -F 4 sample_1.sort.bam`
Scale=`echo "1.0/($Nreads/1000000)" | bc -l`

samtools view -b sample_1.sort.bam | genomeCoverageBed -ibam - -g $ref -bg -scale $Scale > sample_1.coverage

#  module avail -l 2>&1 | grep kent
#  JJ may have installed kentUtils so I could load he module and look or install myself
kentUtils/bin/linux.x86_64/bedGraphToBigWig sample_1.coverage $ref.fai sample_1.bw

# we want the link to be somewhere the public can see on the web
# watch out for the ">>" if you rerun this script...
echo "http://wfitch.bio.uci.edu/~tdlong/SantaCruzTracks/ATACseq/sample_1.bw" >>links.txt

# this is a place where I can host files
scp *.bw tdlong@wfitch.bio.uci.edu:/home/tdlong/public_html/SantaCruzTracks/ATACseq/
