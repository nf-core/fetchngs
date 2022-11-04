# nf-core/fetchngs: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/fetchngs/usage](https://nf-co.re/fetchngs/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

The pipeline has been set-up to automatically download and process the raw FastQ files from both public and private repositories. Identifiers can be provided in a file, one-per-line via the `--input` parameter. Currently, the following types of example identifiers are supported:

| `SRA`        | `ENA`        | `DDBJ`       | `Synapse`   |
| ------------ | ------------ | ------------ | ----------- |
| SRR11605097  | ERR4007730   | DRR171822    | syn26240435 |
| SRX8171613   | ERX4009132   | DRX162434    |             |
| SRS6531847   | ERS4399630   | DRS090921    |             |
| SAMN14689442 | SAMEA6638373 | SAMD00114846 |             |
| SRP256957    | ERP120836    | DRP004793    |             |
| SRA1068758   | ERA2420837   | DRA008156    |             |
| PRJNA625551  | PRJEB37513   | PRJDB4176    |             |

### SRR / ERR / DRR ids

If `SRR`/`ERR`/`DRR` run ids are provided then these will be resolved back to their appropriate `SRX`/`ERX`/`DRX` ids to be able to merge multiple runs from the same experiment. This is conceptually the same as merging multiple libraries sequenced from the same sample.

The final sample information for all identifiers is obtained from the ENA which provides direct download links for FastQ files as well as their associated md5 sums. If download links exist, the files will be downloaded in parallel by FTP. Otherwise they are downloaded using sra-tools.

All of the sample metadata obtained from the ENA will be appended as additional columns to help you manually curate the generated samplesheet before you run the pipeline. You can customise the metadata fields that are appended to the samplesheet via the `--ena_metadata_fields` parameter. The default list of fields used by the pipeline can be found at the top of the [`bin/sra_ids_to_runinfo.py`](https://github.com/nf-core/fetchngs/blob/master/bin/sra_ids_to_runinfo.py) script within the pipeline repo. However, this pipeline requires a minimal set of fields to download FastQ files i.e. `'run_accession,experiment_accession,library_layout,fastq_ftp,fastq_md5'`. A comprehensive list of accepted metadata fields can be obtained from the [ENA API](https://www.ebi.ac.uk/ena/portal/api/returnFields?dataPortal=ena&format=tsv&result=read_run).

If you have a GEO accession (found in the data availability section of published papers) you can directly download a text file containing the appropriate SRA ids to pass to the pipeline:

- Search for your GEO accession on [GEO](https://www.ncbi.nlm.nih.gov/geo)
- Click `SRA Run Selector` at the bottom of the GEO accession page
- Select the desired samples in the `SRA Run Selector` and then download the `Accession List`

This downloads a text file called `SRR_Acc_List.txt` that can be directly provided to the pipeline once renamed with a .csv extension e.g. `--input SRR_Acc_List.csv`.

### Synapse ids

[Synapse](https://www.synapse.org/#) is a collaborative research platform created by [Sage Bionetworks](https://sagebionetworks.org/). Its aim is to promote reproducible research and responsible data sharing throughout the biomedical community. To download data from `Synapse`, the Synapse id of the _directory_ containing all files to be downloaded should be provided. The Synapse id should be an eleven-characters beginning with `syn`.

This Synapse id will then be resolved to the Synapse id of the corresponding FastQ files contained within the directory. The individual FastQ files are then downloaded in parellel using the `synapse get` command. All Synapse metadata, annotations and data provenance are also downloaded using the `synapse show` command, and are outputted to a separate metadata file. By default, only the md5sums, file sizes, etags, Synapse ids, file names, and file versions are shown.

In order to download data from Synapse, an account must be created and a user configuration file provided via the parameter `--synapse_config`. For more information about Synapse configuration, please see the [Synapse client configuration](https://help.synapse.org/docs/Client-Configuration.1985446156.html) documentation.

The final sample information for the FastQ files used for samplesheet generation is obtained from the file name itself. The file names are parsed according to the glob pattern `*{1,2}*`, which returns the sample name, presumed to be the longest possible string matching the glob pattern, with the fewest number of wildcard insertions.

<details markdown="1">
<summary>Supported File Names</summary>

- Files named `SRR493366_1.fastq` and `SRR493366_2.fastq` will have a sample name of `SRR493366`
- Files named `SRR_493_367_1.fastq` and `SRR_493_367_2.fastq` will have a sample name of `SRR_493_367`
- Files named `filename12_1.fastq` and `filename12_2.fastq` will have a sample name of `filename12`

</details>

### Samplesheet format

As a bonus, the columns in the auto-created samplesheet can be tailored to be accepted out-of-the-box by selected nf-core pipelines, these currently include:

- [nf-core/rnaseq](https://nf-co.re/rnaseq/usage#samplesheet-input)
- Ilumina processing mode of [nf-core/viralrecon](https://nf-co.re/viralrecon/usage#illumina-samplesheet-format)
- [nf-core/taxprofiler](https://nf-co.re/nf-core/taxprofiler)

You can use the `--nf_core_pipeline` parameter to customise this behaviour e.g. `--nf_core_pipeline rnaseq`. More pipelines will be supported in due course as we adopt and standardise samplesheet input across nf-core. It is highly recommended that you double-check that all of the identifiers you defined using `--input` are represented in the samplesheet. Also, public databases don't reliably hold information such as strandedness information so you may need to amend these entries too if for example your samplesheet was created by providing `--nf_core_pipeline rnaseq`.

### Bypass `FTP` data download

If FTP connections are blocked on your network use the [`--force_sratools_download`](https://nf-co.re/fetchngs/parameters#force_sratools_download) parameter to force the pipeline to download data using sra-tools instead of the ENA FTP.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/fetchngs --input ids.csv --outdir <OUTDIR> -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/fetchngs
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/fetchngs releases page](https://github.com/nf-core/fetchngs/releases) and find the latest version number - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Conda) - see below. When using Biocontainers, most of these software packaging methods pull Docker containers from quay.io e.g [FastQC](https://quay.io/repository/biocontainers/fastqc) except for Singularity which directly downloads Singularity images via https hosted by the [Galaxy project](https://depot.galaxyproject.org/singularity/) and Conda which downloads and installs software locally from [Bioconda](https://bioconda.github.io/).

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended.

- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.
- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

For example, if the nf-core/rnaseq pipeline is failing after multiple re-submissions of the `STAR_ALIGN` process due to an exit code of `137` this would indicate that there is an out of memory issue:

```console
[62/149eb0] NOTE: Process `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137) -- Execution is retried (1)
Error executing process > 'NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)'

Caused by:
    Process `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137)

Command executed:
    STAR \
        --genomeDir star \
        --readFilesIn WT_REP1_trimmed.fq.gz  \
        --runThreadN 2 \
        --outFileNamePrefix WT_REP1. \
        <TRUNCATED>

Command exit status:
    137

Command output:
    (empty)

Command error:
    .command.sh: line 9:  30 Killed    STAR --genomeDir star --readFilesIn WT_REP1_trimmed.fq.gz --runThreadN 2 --outFileNamePrefix WT_REP1. <TRUNCATED>
Work dir:
    /home/pipelinetest/work/9d/172ca5881234073e8d76f2a19c88fb

Tip: you can replicate the issue by changing to the process work dir and entering the command `bash .command.run`
```

To bypass this error you would need to find exactly which resources are set by the `STAR_ALIGN` process. The quickest way is to search for `process STAR_ALIGN` in the [nf-core/rnaseq Github repo](https://github.com/nf-core/rnaseq/search?q=process+STAR_ALIGN).
We have standardised the structure of Nextflow DSL2 pipelines such that all module files will be present in the `modules/` directory and so, based on the search results, the file we want is `modules/nf-core/software/star/align/main.nf`.
If you click on the link to that file you will notice that there is a `label` directive at the top of the module that is set to [`label process_high`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/modules/nf-core/software/star/align/main.nf#L9).
The [Nextflow `label`](https://www.nextflow.io/docs/latest/process.html#label) directive allows us to organise workflow processes in separate groups which can be referenced in a configuration file to select and configure subset of processes having similar computing requirements.
The default values for the `process_high` label are set in the pipeline's [`base.config`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L33-L37) which in this case is defined as 72GB.
Providing you haven't set any other standard nf-core parameters to **cap** the [maximum resources](https://nf-co.re/usage/configuration#max-resources) used by the pipeline then we can try and bypass the `STAR_ALIGN` process failure by creating a custom config file that sets at least 72GB of memory, in this case increased to 100GB.
The custom config below can then be provided to the pipeline via the [`-c`](#-c) parameter as highlighted in previous sections.

```nextflow
process {
    withName: 'NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN' {
        memory = 100.GB
    }
}
```

> **NB:** We specify the full process name i.e. `NFCORE_RNASEQ:RNASEQ:ALIGN_STAR:STAR_ALIGN` in the config file because this takes priority over the short name (`STAR_ALIGN`) and allows existing configuration using the full process name to be correctly overridden.
>
> If you get a warning suggesting that the process selector isn't recognised check that the process name has been specified correctly.

### Updating containers

The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. If for some reason you need to use a different version of a particular tool with the pipeline then you just need to identify the `process` name and override the Nextflow `container` definition for that process using the `withName` declaration. For example, in the [nf-core/viralrecon](https://nf-co.re/viralrecon) pipeline a tool called [Pangolin](https://github.com/cov-lineages/pangolin) has been used during the COVID-19 pandemic to assign lineages to SARS-CoV-2 genome sequenced samples. Given that the lineage assignments change quite frequently it doesn't make sense to re-release the nf-core/viralrecon everytime a new version of Pangolin has been released. However, you can override the default container used by the pipeline by creating a custom config file and passing it as a command-line argument via `-c custom.config`.

1. Check the default version used by the pipeline in the module file for [Pangolin](https://github.com/nf-core/viralrecon/blob/a85d5969f9025409e3618d6c280ef15ce417df65/modules/nf-core/software/pangolin/main.nf#L14-L19)
2. Find the latest version of the Biocontainer available on [Quay.io](https://quay.io/repository/biocontainers/pangolin?tag=latest&tab=tags)
3. Create the custom config accordingly:

   - For Docker:

     ```nextflow
     process {
         withName: PANGOLIN {
             container = 'quay.io/biocontainers/pangolin:3.0.5--pyhdfd78af_0'
         }
     }
     ```

   - For Singularity:

     ```nextflow
     process {
         withName: PANGOLIN {
             container = 'https://depot.galaxyproject.org/singularity/pangolin:3.0.5--pyhdfd78af_0'
         }
     }
     ```

   - For Conda:

     ```nextflow
     process {
         withName: PANGOLIN {
             conda = 'bioconda::pangolin=3.0.5'
         }
     }
     ```

> **NB:** If you wish to periodically update individual tool-specific results (e.g. Pangolin) generated by the pipeline then you must ensure to keep the `work/` directory otherwise the `-resume` ability of the pipeline will be compromised and it will restart from scratch.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute `params.vm_type` of `Standard_D16_v3` VMs by default but these options can be changed if required.

Note that the choice of VM size depends on your quota and the overall workload during the analysis.
For a thorough list, please refer the [Azure Sizes for virtual machines in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
