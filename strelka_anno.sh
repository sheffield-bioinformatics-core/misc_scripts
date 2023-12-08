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
   echo "Simple script to take the strelka or mutect2 vcf variant call output from nfcore/sarek, select PASS variants and those with QUAL>50 and annotate with annovar"
   echo "Syntax: scriptTemplate [-a|s|h]"
   echo "options:"
   echo "a     Set annovar directory - default = annovar/"
   echo "s     Set sampleSheet.csv this must be a csv file (same as to nextflow input) and must have your samplenames in the 1st column"
   echo "o     Set output directory - default = strelka_anno/"
   echo "r     Set directory for nextflows results file - default results/"
   echo "h     Print this Help."
   echo "m    The variant calling method to filter and annotate; strelka or mutect2"
   echo "i     Column number in the sample sheet that contains the sample IDs"
   echo "d     Directory containing pre-downloaded annovar database(s)  - default annovar/humandb"
   echo "v     Genome version used for annovar annotation - default hg38"
   echo
}

# script defaults

annovar_dir=$PWD/annovar
output_dir=$PWD/strelka_anno
input_dir=$PWD/results
annovar_db=${annovar_dir}/humandb
id_col=1
caller=strelka
genome_version=hg38

# Get the options
while getopts ":hs:a:o:r:i:m:d:v:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      a) annovar_dir=${OPTARG};;
      s) sample_sheet=${OPTARG};;
      o) output_dir=${OPTARG};;
      r) input_dir=${OPTARG};;
      i) id_col=${OPTARG};;
      m) 
	 caller=${OPTARG}
	 ((caller == strelka || caller == mutect2 || caller == intersect)) || Help 
	  ;;
      d) annovar_db=${OPTARG};;
      v) genome_version=${OPTARG};;
      \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit;;
   esac
done

echo "Running strelka_anno"
echo "Using column $id_col as sample names"
echo "caller was set to ${caller}"

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
  echo 'Error: cannot find bcftools. On Stanage, this can be loaded using module load BCFtools' >&2
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

#Check for annovar database
if [ -d "${annovar_db}" ] 
 then
    echo "Found "${annovar_db}"." 
 else
    echo "Error: Can not find annovar database at ${annovar_db}"
    echo "Use -d to set annovar database directory."
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

if [[ $caller == "strelka" ]]; then

  if [ -d "${input_dir}/variant_calling/strelka" ]
   then
      echo "Found strelka data."
  fi
  
elif [ $caller == "mutect2" ]; then

  if [ -d "${input_dir}/variant_calling/mutect2" ]
   then
      echo "Found mutect2 data."
  fi
  
   
elif [ $caller == "intersect" ]; then
 
  if [ -d "${input_dir}/variant_calling/mutect2" & -d "${input_dir}/variant_calling/strelka"  ]
   then
      echo "Found both mutect2 and strelka data. Will proceed with merge"
  fi

fi

mkdir -p $output_dir


## Create variables to hold annovar operation and protocol script
annovar_op=""
annovar_pr=""


### Checking to see if all the databases are present

if [ ! -e  "${annovar_db}/${genome_version}_refGene.txt" ]
   then
    echo "No refGene annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found refGene annotations in ${annovar_db}/${genome_version}_refGene.txt. This will be used for annovar annotation"
     annovar_pr="refGene" 
     annovar_op="gx"		
fi

if [ ! -e  "${annovar_db}/${genome_version}_cytoBand.txt" ]
   then
    echo "No cytoband annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found cytoBand annotations in ${annovar_db}/${genome_version}_cyotBand.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},cytoband"
     annovar_op="${annovar_op},r"		
fi


if [ ! -e  "${annovar_db}/${genome_version}_dbnsfp30a.txt" ]
   then
    echo "No dbnsfp30a annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found dbnsfp30a annotations in ${annovar_db}/${genome_version}_dbnsfp30a.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},dbnsfp30a"
     annovar_op="${annovar_op},f"		
fi


##Could check if other clinvar annotations are present, not just this specific version

if [ ! -e  "${annovar_db}/${genome_version}_clinvar_20221231.txt" ]
   then
    echo "No clinvar annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found clinvar annotations in ${annovar_db}/${genome_version}_clinvar_20221231.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},clinvar_20221231"
     annovar_op="${annovar_op},f"		
fi


if [ ! -e  "${annovar_db}/${genome_version}_nci60.txt" ]
   then
    echo "No NCI60 annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found NCI60 annotations in ${annovar_db}/${genome_version}_nci60.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},nci60"
     annovar_op="${annovar_op},f"		
fi

if [ ! -e  "${annovar_db}/${genome_version}_cosmic70.txt" ]
   then
    echo "No COSMIC annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found COSMIC annotations in ${annovar_db}/${genome_version}_cosmic70.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},cosmic70"
     annovar_op="${annovar_op},f"		
fi

if [ ! -e  "${annovar_db}/${genome_version}_gnomad_exome.txt" ]
   then
    echo "No GNOMAD annotation found in ${annovar_db}. Please check that your annovar database and genome version are correct"
    echo "Value of annovar database (-d) was: ${annovar_db}"
    echo "Value of genome version (-v) was ${genome_version}"

else
     echo "Found GNOMAD annotations in ${annovar_db}/${genome_version}_gnomad_exome.txt. This will be used for annovar annotation"
     annovar_pr="${annovar_pr},gnomad_exome"
     annovar_op="${annovar_op},f"		
fi




echo "Current value of annovar protocol is ${annovar_pr}"
echo "Current value of annovar operation is ${annovar_op}"




#For loop

for sample in $(cut -d',' -f"$id_col" ${sample_sheet} | tail -n +2)
do
echo "Working on ${sample}"
echo ""
echo ""


mkdir -p $output_dir/$sample

# Strelka filtering
# Set file paths for each samplename

if [[ $caller == "strelka" ]]; then 

echo "Filtering strelka output for $sample for QUAL>50 and PASS if applicable"

input_vcf=${input_dir}/variant_calling/strelka/${sample}/${sample}.strelka.variants.vcf.gz
pass_vcf=${output_dir}/${sample}/${sample}.strelka.variants.PASS.vcf.gz
bcftools view  -Oz -f PASS -i '%QUAL>50' ${input_vcf} > ${pass_vcf}
bcftools index ${pass_vcf}

# mutect2 filtering
#
# Set file paths for each samplename
elif [ $caller == "mutect2" ]; then

echo "Filtering mutect2 output for $sample for PASS if applicable"

	input_vcf=${input_dir}/variant_calling/mutect2/${sample}/${sample}.mutect2.filtered.vcf.gz
	pass_vcf=${output_dir}/${sample}/${sample}.mutect2.variants.PASS.vcf.gz
	bcftools view  -Oz -f PASS ${input_vcf} > ${pass_vcf}
	bcftools index ${pass_vcf}
	

elif [ $caller == "intersect" ]; then

echo "Filtering mutect2 output for $sample for PASS if applicable"

	input_vcf=${input_dir}/variant_calling/mutect2/${sample}/${sample}.mutect2.filtered.vcf.gz
	pass_vcf_m=${output_dir}/${sample}/${sample}.mutect2.variants.PASS.vcf.gz
	bcftools view  -Oz -f PASS ${input_vcf} > ${pass_vcf_m}
	bcftools index ${pass_vcf_m}

echo "Filtering strelka output for $sample for PASS if applicable"

	input_vcf=${input_dir}/variant_calling/strelka/${sample}/${sample}.strelka.variants.vcf.gz
	pass_vcf_s=${output_dir}/${sample}/${sample}.strelka.variants.PASS.vcf.gz
	bcftools view  -Oz -f PASS -i '%QUAL>50' ${input_vcf} > ${pass_vcf_s}
	bcftools index ${pass_vcf_s}

echo "Merging filtered strelka and mutect2 variants"

pass_vcf=${output_dir}/${sample}/${sample}.INTERSECT.variants.PASS.vcf
	
bcftools isec ${pass_vcf_m} ${pass_vcf_s} -p ${output_dir}/${sample}/TMP_MERGE
mv ${output_dir}/${sample}/TMP_MERGE/0002.vcf ${pass_vcf}

fi




echo ".....Converting vcf to annovar"
${annovar_dir}/convert2annovar.pl -format vcf4 $pass_vcf > ${pass_vcf}.avinput

echo "..........Annotating with annovar"

##${annovar_dir}/annotate_variation.pl -filter -infoasscore -otherinfo -dbtype gnomad_exome -buildver ${genome_version} ${pass_vcf}.avinput ${annovar_db} &> /dev/null
 
echo "Using the annovar command: ${annovar_dir}/table_annovar.pl ${pass_vcf}.avinput  ${annovar_db} -buildver ${genome_version} -remove -protocol ${annovar_pr} -operation ${annovar_op} -nastring NA"

 
${annovar_dir}/table_annovar.pl ${pass_vcf}.avinput  ${annovar_db} -buildver ${genome_version} -remove -protocol ${annovar_pr} -operation ${annovar_op} -nastring NA &> /dev/null


done

