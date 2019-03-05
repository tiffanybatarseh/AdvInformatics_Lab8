#!/bin/bash
#$ -N advinf_DNAseq_VCF
#$ -q class
#$ -pe openmp 8
#$ -R y
#$ -t 1
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

cd /pub/tbatarse/Bioinformatics_Course/DNAseq/Converted

ref="/pub/tbatarse/Bioinformatics_Course/ref/dmel-all-chromosome-r6.13.fasta"

#To create the file name text file
#ls *1.fq.gz | sed 's/_1.fq.gz//' >DNAseq.prefixes.txt

#prefix=`head -n $SGE_TASK_ID DNAseq.prefixes.txt | tail -n 1 | cut -f2`

# Option #1 -- traditional GATK pipeline (slow)
java -d64 -jar /data/apps/picard-tools/1.87/MergeSamFiles.jar I=A4_1.RG.bam I=A4_2.RG.bam I=A5_1.RG.bam I=A5_2.RG.bam I=A5_3.RG.bam I=A6_1.RG.bam I=A6_2.RG.bam I=A6_3.RG.bam I=A7_2.RG.bam I=A7_3.RG.bam SO=coordinate AS=true VALIDATION_STRINGENCY=SILENT O=merged.bam

samtools index merged.bam

# a little trick if you have lots of I='s you want to compare to one another in the same dir
# just replace the manual list of I= I= ... with $(printf 'I=%s ' $dir/*.RG.bam)

java -d64 -Xmx128g -jar /data/apps/gatk/2.4-7/GenomeAnalysisTK.jar -T RealignerTargetCreator -nt 8 -R $ref -I merged.bam --minReadsAtLocus 4 -o merged.intervals

java -d64 -Xmx20g -jar /data/apps/gatk/2.4-7/GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I merged.bam -targetIntervals merged.intervals -LOD 3.0 -o merged-realigned.bam

java -d64 -Xmx128g -jar /data/apps/gatk/2.4-7/GenomeAnalysisTK.jar -T UnifiedGenotyper -nt 8 -R $ref -I merged-realigned.bam -gt_mode DISCOVERY -stand_call_conf 30 -stand_emit_conf 10 -o rawSNPS-Q30.vcf

java -d64 -Xmx128g -jar  /data/apps/gatk/2.4-7/GenomeAnalysisTK.jar -T UnifiedGenotyper -nt 8 -R $ref -I merged-realigned.bam -gt_mode DISCOVERY -glm INDEL -stand_call_conf 30 -stand_emit_conf 10 -o inDels-Q30.vcf

java -d64 -Xmx20g -jar /data/apps/gatk/2.4-7/GenomeAnalysisTK.jar -T VariantFiltration -R $ref -V rawSNPS-Q30.vcf --mask inDels-Q30.vcf --maskExtension 5 --maskName InDel --clusterWindowSize 10 --filterExpression "MQ0 >= 4 && ((MQ0 / (1.0 * DP)) > 0.1)" --filterName "BadValidation" --filterExpression "QUAL < 30.0" --filterName "LowQual" --filterExpression "QD < 5.0" --filterName "LowVQCBD" --filterExpression "FS > 60" --filterName "FisherStrand" -o Q30-SNPs.vcf

cat Q30-SNPs.vcf | grep 'PASS\|^#' > pass.SNPs.vcf

cat inDels-Q30.vcf | grep 'PASS\|^#' > pass.inDels.vcf

# it I want to display in SCGB I have to bgzip and tabix (part of samtools), see lecture 4
# oddly bgzip is not the same as gzip and tabix is only for indexing bgzip, and SCGB can only deal with bgzip
# the reasons behind this are discussed in the Buffalo book (but basically bgzip indexes on several defined columns)
# may as well run this now

bgzip -c pass.SNPs.vcf >pass.SNPs.vcf.gz
tabix -p vcf pass.SNPs.vcf.gz
bgzip -c pass.inDels.vcf >pass.inDels.vcf.gz
tabix -p pass.inDels.vcf.gz
