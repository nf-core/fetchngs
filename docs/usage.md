# nf-core/fetchngs: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/fetchngs/usage](https://nf-co.re/fetchngs/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

The pipeline has been set-up to automatically download and process the raw FastQ files from both public and private repositories. Identifiers can be provided in a file, one-per-line via the `--input` parameter. Currently, the following types of example identifiers are supported:

| `SRA`        | `ENA`        | `DDBJ`       | `GEO`      | `Synapse`   |
|--------------|--------------|--------------|------------|-------------|
| SRR11605097  | ERR4007730   | DRR171822    | GSM4432381 | syn26240435 |
| SRX8171613   | ERX4009132   | DRX162434    | GSE147507  |             |
| SRS6531847   | ERS4399630   | DRS090921    |            |             |
| SAMN14689442 | SAMEA6638373 | SAMD00114846 |            |             |
| SRP256957    | ERP120836    | DRP004793    |            |             |
| SRA1068758   | ERA2420837   | DRA008156    |            |             |
| PRJNA625551  | PRJEB37513   | PRJDB4176    |            |             |

### SRR / ERR / DRR Sample Identifiers

If `SRR`/`ERR`/`DRR` run ids are provided then these will be resolved back to their appropriate `SRX`/`ERX`/`DRX` ids to be able to merge multiple runs from the same experiment. This is conceptually the same as merging multiple libraries sequenced from the same sample.

The final sample information for all identifiers is obtained from the ENA which provides direct download links for FastQ files as well as their associated md5 sums. If download links exist, the files will be downloaded in parallel by FTP otherwise they will NOT be downloaded. This is intentional because tools such as `parallel-fastq-dump`, `fasterq-dump`, `prefetch` etc require pre-existing configuration files in the users home directory which makes automation tricky across different platforms and containerisation. We may add this functionality in later releases.

All of the sample metadata obtained from the ENA will be appended as additional columns to help you manually curate the generated samplesheet before you run the pipeline. You can customise the metadata fields that are appended to the samplesheet via the `--ena_metadata_fields` parameter. The default list of fields used by the pipeline can be found at the top of the [`bin/sra_ids_to_runinfo.py`](https://github.com/nf-core/fetchngs/blob/master/bin/sra_ids_to_runinfo.py) script within the pipeline repo. However, this pipeline requires a minimal set of fields to download FastQ files i.e. `'run_accession,experiment_accession,library_layout,fastq_ftp,fastq_md5'`. A comprehensive list of accepted metadata fields can be obtained from the [ENA API](https://www.ebi.ac.uk/ena/portal/api/returnFields?dataPortal=ena&format=tsv&result=read_run]).

If you have a GEO accession (found in the data availability section of published papers) you can directly download a text file containing the appropriate SRA ids to pass to the pipeline:

* Search for your GEO accession on [GEO](https://www.ncbi.nlm.nih.gov/geo)
* Click `SRA Run Selector` at the bottom of the GEO accession page
* Select the desired samples in the `SRA Run Selector` and then download the `Accession List`

This downloads a text file called `SRR_Acc_List.txt` that can be directly provided to the pipeline e.g. `--input SRR_Acc_List.txt`.

### Synapse Sample Identifiers

[Synapse](https://www.synapse.org/#) is a collaborative research platform created by [Sage Bionetworks](https://sagebionetworks.org/). Its aim is to promote reproducible research and responsible data sharing throughout the biomedical community. To download data from `Synapse`, the SynapseID of the _directory_ containing all files to be downloaded should be provided. The SynapseID should be an eleven-character identifier, beginning with `syn`.

This SynapseID will then be resolved to the SynapseIDs of the corresponding FastQ files contained within the directory. The individual FastQ files are then downloaded in parellel using the `synapse get` command. All Synapse metadata, annotations and provenance are also downloaded using the `synapse show` command, and are outputted to a separate metadata file. By default, only the md5sums, file sizes, etags, Synapse IDs, file names, and file versions are shown.

In order to download data from Synapse, an account must be created and a user configuration file provided via the parameter `--synapse_config`. For more information about Synapse configuration, please see the [Synapse client configuration](https://help.synapse.org/docs/Client-Configuration.1985446156.html) documentation.

The final sample information for the FastQ files used for samplesheet generation is obtained from the file name itself. The file names are parsed according to the glob pattern `*{1,2}*`, which returns the sample name, presumed to be the longest possible string matching the glob pattern, with the fewest number of wildcard insertions.

<details markdown="1">
<summary>Supported File Names</summary>

* Files named `SRR493366_1.fastq` and `SRR493366_2.fastq` will have a sample name of `SRR493366`
* Files named `SRR_493_367_1.fastq` and `SRR_493_367_2.fastq` will have a sample name of `SRR_493_367`
* Files named `filename12_1.fastq` and `filename12_2.fastq` will have a sample name of `filename12`

</details>

### Samplesheet Generation

As a bonus, the columns in the auto-created samplesheet can be tailored to be accepted out-of-the-box by selected nf-core pipelines, these currently include [nf-core/rnaseq](https://nf-co.re/rnaseq/usage#samplesheet-input) and the Illumina processing mode of [nf-core/viralrecon](https://nf-co.re/viralrecon/usage#illumina-samplesheet-format). You can use the `--nf_core_pipeline` parameter to customise this behaviour e.g. `--nf_core_pipeline rnaseq`. More pipelines will be supported in due course as we adopt and standardise samplesheet input across nf-core. It is highly recommended that you double-check that all of the identifiers you defined using `--input` are represented in the samplesheet. Also, public databases don't reliably hold information such as strandedness information so you may need to amend these entries too if for example your samplesheet was created by providing `--nf_core_pipeline rnaseq`.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/fetchngs --input ids.txt -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```console
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```console
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

* `docker`
    * A generic configuration profile to be used with [Docker](https://docker.com/)
* `singularity`
    * A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
* `podman`
    * A generic configuration profile to be used with [Podman](https://podman.io/)
* `shifter`
    * A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
* `charliecloud`
    * A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
* `conda`
    * A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.
* `test`
    * A profile with a complete configuration for automated testing
    * Includes links to test data so needs no other parameters

### `-resume`

Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

For example, if the nf-core/rnaseq pipeline is failing after multiple re-submissions of the `STAR_ALIGN` process due to an exit code of `137` this would indicate that there is an out of memory issue:

```console
[62/149eb0] NOTE: Process `RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137) -- Execution is retried (1)
Error executing process > 'RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)'

Caused by:
    Process `RNASEQ:ALIGN_STAR:STAR_ALIGN (WT_REP1)` terminated with an error exit status (137)

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

To bypass this error you would need to find exactly which resources are set by the `STAR_ALIGN` process. The quickest way is to search for `process STAR_ALIGN` in the [nf-core/rnaseq Github repo](https://github.com/nf-core/rnaseq/search?q=process+STAR_ALIGN). We have standardised the structure of Nextflow DSL2 pipelines such that all module files will be present in the `modules/` directory and so based on the search results the file we want is `modules/nf-core/software/star/align/main.nf`. If you click on the link to that file you will notice that there is a `label` directive at the top of the module that is set to [`label process_high`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/modules/nf-core/software/star/align/main.nf#L9). The [Nextflow `label`](https://www.nextflow.io/docs/latest/process.html#label) directive allows us to organise workflow processes in separate groups which can be referenced in a configuration file to select and configure subset of processes having similar computing requirements. The default values for the `process_high` label are set in the pipeline's [`base.config`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L33-L37) which in this case is defined as 72GB. Providing you haven't set any other standard nf-core parameters to __cap__ the [maximum resources](https://nf-co.re/usage/configuration#max-resources) used by the pipeline then we can try and bypass the `STAR_ALIGN` process failure by creating a custom config file that sets at least 72GB of memory, in this case increased to 100GB. The custom config below can then be provided to the pipeline via the [`-c`](#-c) parameter as highlighted in previous sections.

```nextflow
process {
    withName: STAR_ALIGN {
        memory = 100.GB
    }
}
```

> **NB:** We specify just the process name i.e. `STAR_ALIGN` in the config file and not the full task name string that is printed to screen in the error message or on the terminal whilst the pipeline is running i.e. `RNASEQ:ALIGN_STAR:STAR_ALIGN`. You may get a warning suggesting that the process selector isn't recognised but you can ignore that if the process name has been specified correctly. This is something that needs to be fixed upstream in core Nextflow.

### Tool-specific options

For the ultimate flexibility, we have implemented and are using Nextflow DSL2 modules in a way where it is possible for both developers and users to change tool-specific command-line arguments (e.g. providing an additional command-line argument to the `STAR_ALIGN` process) as well as publishing options (e.g. saving files produced by the `STAR_ALIGN` process that aren't saved by default by the pipeline). In the majority of instances, as a user you won't have to change the default options set by the pipeline developer(s), however, there may be edge cases where creating a simple custom config file can improve the behaviour of the pipeline if for example it is failing due to a weird error that requires setting a tool-specific parameter to deal with smaller / larger genomes.

The command-line arguments passed to STAR in the `STAR_ALIGN` module are a combination of:

* Mandatory arguments or those that need to be evaluated within the scope of the module, as supplied in the [`script`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/modules/nf-core/software/star/align/main.nf#L49-L55) section of the module file.

* An [`options.args`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/modules/nf-core/software/star/align/main.nf#L56) string of non-mandatory parameters that is set to be empty by default in the module but can be overwritten when including the module in the sub-workflow / workflow context via the `addParams` Nextflow option.

The nf-core/rnaseq pipeline has a sub-workflow (see [terminology](https://github.com/nf-core/modules#terminology)) specifically to align reads with STAR and to sort, index and generate some basic stats on the resulting BAM files using SAMtools. At the top of this file we import the `STAR_ALIGN` module via the Nextflow [`include`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/subworkflows/nf-core/align_star.nf#L10) keyword and by default the options passed to the module via the `addParams` option are set as an empty Groovy map [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/subworkflows/nf-core/align_star.nf#L5); this in turn means `options.args` will be set to empty by default in the module file too. This is an intentional design choice and allows us to implement well-written sub-workflows composed of a chain of tools that by default run with the bare minimum parameter set for any given tool in order to make it much easier to share across pipelines and to provide the flexibility for users and developers to customise any non-mandatory arguments.

When including the sub-workflow above in the main pipeline workflow we use the same `include` statement, however, we now have the ability to overwrite options for each of the tools in the sub-workflow including the [`align_options`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/workflows/rnaseq.nf#L225) variable that will be used specifically to overwrite the optional arguments passed to the `STAR_ALIGN` module. In this case, the options to be provided to `STAR_ALIGN` have been assigned sensible defaults by the developer(s) in the pipeline's [`modules.config`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/modules.config#L70-L74) and can be accessed and customised in the [workflow context](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/workflows/rnaseq.nf#L201-L204) too before eventually passing them to the sub-workflow as a Groovy map called `star_align_options`. These options will then be propagated from `workflow -> sub-workflow -> module`.

As mentioned at the beginning of this section it may also be necessary for users to overwrite the options passed to modules to be able to customise specific aspects of the way in which a particular tool is executed by the pipeline. Given that all of the default module options are stored in the pipeline's `modules.config` as a [`params` variable](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/modules.config#L24-L25) it is also possible to overwrite any of these options via a custom config file.

Say for example we want to append an additional, non-mandatory parameter (i.e. `--outFilterMismatchNmax 16`) to the arguments passed to the `STAR_ALIGN` module. Firstly, we need to copy across the default `args` specified in the [`modules.config`](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/modules.config#L71) and create a custom config file that is a composite of the default `args` as well as the additional options you would like to provide. This is very important because Nextflow will overwrite the default value of `args` that you provide via the custom config.

As you will see in the example below, we have:

* appended `--outFilterMismatchNmax 16` to the default `args` used by the module.
* changed the default `publish_dir` value to where the files will eventually be published in the main results directory.
* appended `'bam':''` to the default value of `publish_files` so that the BAM files generated by the process will also be saved in the top-level results directory for the module. Note: `'out':'log'` means any file/directory ending in `out` will now be saved in a separate directory called `my_star_directory/log/`.

```nextflow
params {
    modules {
        'star_align' {
            args          = "--quantMode TranscriptomeSAM --twopassMode Basic --outSAMtype BAM Unsorted --readFilesCommand zcat --runRNGseed 0 --outFilterMultimapNmax 20 --alignSJDBoverhangMin 1 --outSAMattributes NH HI AS NM MD --quantTranscriptomeBan Singleend --outFilterMismatchNmax 16"
            publish_dir   = "my_star_directory"
            publish_files = ['out':'log', 'tab':'log', 'bam':'']
        }
    }
}
```

### Updating containers

The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. If for some reason you need to use a different version of a particular tool with the pipeline then you just need to identify the `process` name and override the Nextflow `container` definition for that process using the `withName` declaration. For example, in the [nf-core/viralrecon](https://nf-co.re/viralrecon) pipeline a tool called [Pangolin](https://github.com/cov-lineages/pangolin) has been used during the COVID-19 pandemic to assign lineages to SARS-CoV-2 genome sequenced samples. Given that the lineage assignments change quite frequently it doesn't make sense to re-release the nf-core/viralrecon everytime a new version of Pangolin has been released. However, you can override the default container used by the pipeline by creating a custom config file and passing it as a command-line argument via `-c custom.config`.

1. Check the default version used by the pipeline in the module file for [Pangolin](https://github.com/nf-core/viralrecon/blob/a85d5969f9025409e3618d6c280ef15ce417df65/modules/nf-core/software/pangolin/main.nf#L14-L19)
2. Find the latest version of the Biocontainer available on [Quay.io](https://quay.io/repository/biocontainers/pangolin?tag=latest&tab=tags)
3. Create the custom config accordingly:

    * For Docker:

        ```nextflow
        process {
            withName: PANGOLIN {
                container = 'quay.io/biocontainers/pangolin:3.0.5--pyhdfd78af_0'
            }
        }
        ```

    * For Singularity:

        ```nextflow
        process {
            withName: PANGOLIN {
                container = 'https://depot.galaxyproject.org/singularity/pangolin:3.0.5--pyhdfd78af_0'
            }
        }
        ```

    * For Conda:

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

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```console
NXF_OPTS='-Xms1g -Xmx4g'
```
