#!/bin/bash

#strelka_anno.sh

# Maintainer: E Chambers

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo
   echo "*** strelka_anno.sh ***"
   echo "Simple script to take the strelka vcf variant call output from nfcore/sarek, select PASS variants and those with QUAL>50 and annotate with annovar"
   echo "Syntax: scriptTemplate [-a|s|h]"
   echo "options:"
   echo "a     Set annovar directory - default = annovar/"
   echo "s     Set sampleSheet.csv this must be a csv file (same as to nextflow input) and must have your samplenames ans 1st column"
   echo "o     Set output directory - default = strelka_anno/"
   echo "i     Set directory for nextflows results file - default results/"
   echo "h     Print this Help."
   echo
}

# script defaults

annovar_dir=$PWD/annovar
output_dir=$PWD/strelka_anno
input_dir=$PWD/results



# Get the options
while getopts ":hs:a:o:i:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      a) annovar_dir=${OPTARG};;
      s) sample_sheet=${OPTARG};;
      o) output_dir=${OPTARG};;
      i) input_dir=${OPTARG};;
     \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit;;
   esac
done

echo "Running strelka_anno"


#Pre-flight checks

if [ -z ${sample_sheet} ]
          then
           echo "Please specify input csv shample sheet using the -s option."
           exit 1

         elif [ -f "${sample_sheet}" ]
          then
           echo "Found "${sample_sheet}"."
         else
           echo "Error: Can not find sample sheet at ${sample_sheet}."
           exit 1
fi


if ! [ -x "$(command -v bcftools)" ]; then
  echo 'Error: cannot find bcftools.' >&2
  exit 1
else
  echo 'Found bcftools.'
fi

#Check for annovar
if [ -d "${annovar_dir}" ] 
 then
    echo "Found "${annovar_dir}"." 
 else
    echo "Error: Can not find annovar at ${annovar_dir}"
    echo "Use -a to set annovar dir."
    exit 1
fi

#Check for nextflow input
if [ -d "${input_dir}" ]
 then
    echo "Found "${input_dir}"."
 else
    echo "Error: Can not find results at ${input_dir}"
    echo "Use -i to set nextflow results dir."
    exit 1
fi

#check callers
#Check for nextflow input
if [ -d "${input_dir}/variant_calling/strelka" ]
 then
    echo "Found strelka data."
fi


mkdir $output_dir

humandb=${annovar_dir}/humandb

#For loop

for sample in $(cut -d',' -f1 ${sample_sheet} | tail -n +2)
do
echo "Working on ${sample}."
echo "   Filtering $sample for QUAL>50 and PASS if applicable"


mkdir -p $output_dir/$sample

# Set file paths for each samplename
input_vcf=${input_dir}/variant_calling/strelka/${sample}/${sample}.strelka.variants.vcf.gz
pass_vcf=${output_dir}/${sample}/${sample}.strelka.variants.PASS.vcf.gz

bcftools view  -Oz -f PASS -i '%QUAL>50' ${input_vcf} > ${pass_vcf}
bcftools index ${pass_vcf}

echo "   Filtering with annovar"
${annovar_dir}/convert2annovar.pl -format vcf4 $pass_vcf > ${pass_vcf}.avinput

${annovar_dir}/annotate_variation.pl -filter -infoasscore -otherinfo -dbtype gnomad_exome -buildver hg38 ${pass_vcf}.avinput $humandb
  
${annovar_dir}/table_annovar.pl ${pass_vcf}.avinput $humandb -buildver hg38 -remove -protocol refGene,cytoband,dbnsfp30a,clinvar_20221231,nci60,cosmic70,gnomad_exome -operation gx,r,f,f,f,f,f -nastring NA
done

