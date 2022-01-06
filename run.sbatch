#!/bin/bash
#
#SBATCH --job-name=run
#SBATCH --output=job_output/run.%j.out
#SBATCH --error=job_output/run.%j.err
#SBATCH --time=24:00:00
#SBATCH -p horence,quake
#SBATCH --nodes=1
#SBATCH --mem=60Gb
#SBATCH --requeue

nextflow run main.nf -profile sherlock -latest --input test_ids.txt --outdir test_results/ -resume

