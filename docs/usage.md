# nf-core/fetchngs: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/fetchngs/usage](https://nf-co.re/fetchngs/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

The pipeline has been set-up to automatically download and process the raw FastQ files from public repositories. Identifiers can be provided in a file, one-per-line via the `--input` parameter. Currently, the following types of example identifiers are supported:

| `SRA`        | `ENA`        | `DDBJ`       | `GEO`      |
| ------------ | ------------ | ------------ | ---------- |
| SRR11605097  | ERR4007730   | DRR171822    | GSM4432381 |
| SRX8171613   | ERX4009132   | DRX162434    | GSE147507  |
| SRS6531847   | ERS4399630   | DRS090921    |            |
| SAMN14689442 | SAMEA6638373 | SAMD00114846 |            |
| SRP256957    | ERP120836    | DRP004793    |            |
| SRA1068758   | ERA2420837   | DRA008156    |            |
| PRJNA625551  | PRJEB37513   | PRJDB4176    |            |

### SRR / ERR / DRR ids

If `SRR`/`ERR`/`DRR` run ids are provided then these will be resolved back to their appropriate `SRX`/`ERX`/`DRX` ids to be able to merge multiple runs from the same experiment. This is conceptually the same as merging multiple libraries sequenced from the same sample.

The final sample information for all identifiers is obtained from the ENA which provides direct download links for FastQ files as well as their associated md5 sums. If download links exist, the files will be downloaded in parallel by FTP. Otherwise they are downloaded using sra-tools.

All of the sample metadata obtained from the ENA will be appended as additional columns to help you manually curate the generated samplesheet before you run the pipeline. You can customise the metadata fields that are appended to the samplesheet via the `--ena_metadata_fields` parameter. The default list of fields used by the pipeline can be found at the top of the [`bin/sra_ids_to_runinfo.py`](https://github.com/nf-core/fetchngs/blob/master/bin/sra_ids_to_runinfo.py) script within the pipeline repo. However, this pipeline requires a minimal set of fields to download FastQ files i.e. `'run_accession,experiment_accession,library_layout,fastq_ftp,fastq_md5'`. A comprehensive list of accepted metadata fields can be obtained from the [ENA API](https://www.ebi.ac.uk/ena/portal/api/returnFields?dataPortal=ena&format=tsv&result=read_run).

If you have a GEO accession (found in the data availability section of published papers) you can directly download a text file containing the appropriate SRA ids to pass to the pipeline:

- Search for your GEO accession on [GEO](https://www.ncbi.nlm.nih.gov/geo)
- Click `SRA Run Selector` at the bottom of the GEO accession page
- Select the desired samples in the `SRA Run Selector` and then download the `Accession List`

This downloads a text file called `SRR_Acc_List.txt` that can be directly provided to the pipeline once renamed with a .csv extension e.g. `--input SRR_Acc_List.csv`.

### Samplesheet format

As a bonus, the columns in the auto-created samplesheet can be tailored to be accepted out-of-the-box by selected nf-core pipelines, these currently include:

- [nf-core/rnaseq](https://nf-co.re/rnaseq/usage#samplesheet-input)
- [nf-core/atacseq](https://nf-co.re/atacseq/usage#samplesheet-input)
- Ilumina processing mode of [nf-core/viralrecon](https://nf-co.re/viralrecon/usage#illumina-samplesheet-format)
- [nf-core/taxprofiler](https://nf-co.re/nf-core/taxprofiler)

You can use the `--nf_core_pipeline` parameter to customise this behaviour e.g. `--nf_core_pipeline rnaseq`. More pipelines will be supported in due course as we adopt and standardise samplesheet input across nf-core. It is highly recommended that you double-check that all of the identifiers required by the downstream nf-core pipeline are accurately represented in the samplesheet. For example, the nf-core/atacseq pipeline requires a `replicate` column to be provided in it's input samplehsheet, however, public databases don't reliably hold information regarding replicates so you may need to amend these entries if your samplesheet was created by providing `--nf_core_pipeline atacseq`.

From v1.9 of this pipeline the default `strandedness` in the output samplesheet will be set to `auto` when using `--nf_core_pipeline rnaseq`. This will only work with v3.10 onwards of nf-core/rnaseq which permits the auto-detection of strandedness during the pipeline execution. You can change this behaviour with the `--nf_core_rnaseq_strandedness` parameter which is set to `auto` by default.

### Accessions with more than 2 FastQ files

Using `SRR9320616` as an example, if we run the pipeline with default options to download via Aspera/FTP the ENA API indicates that this sample is associated with a single FastQ file:

```
run_accession	experiment_accession	sample_accession	secondary_sample_accession	study_accession	secondary_study_accession	submission_accession	run_alias	experiment_alias	sample_alias	study_alias	library_layout	library_selection	library_source	library_strategy	library_name	instrument_model	instrument_platform	base_count	read_count	tax_id	scientific_name	sample_title	experiment_title	study_title	sample_description	fastq_md5	fastq_bytes	fastq_ftp	fastq_galaxy	fastq_aspera
SRR9320616	SRX6088086	SAMN12086751	SRS4989433	PRJNA549480	SRP201778	SRA900583	GSM3895942_r1	GSM3895942	GSM3895942	GSE132901	PAIRED	cDNA	TRANSCRIPTOMIC	RNA-Seq		Illumina HiSeq 2500	ILLUMINA	11857688850	120996825	10090	Mus musculus	Old 3 Kidney	Illumina HiSeq 2500 sequencing: GSM3895942: Old 3 Kidney Mus musculus RNA-Seq	A murine aging cell atlas reveals cell identity and tissue-specific trajectories of aging	Old 3 Kidney	98c939bbae1a1fcf9624905516485b67	7763114613	ftp.sra.ebi.ac.uk/vol1/fastq/SRR932/006/SRR9320616/SRR9320616.fastq.gz	ftp.sra.ebi.ac.uk/vol1/fastq/SRR932/006/SRR9320616/SRR9320616.fastq.gz	fasp.sra.ebi.ac.uk:/vol1/fastq/SRR932/006/SRR9320616/SRR9320616.fastq.gz
```

However, this sample actually has 2 additional FastQ files that are flagged as technical and can only be obtained by running sra-tools. This is particularly important for certain preps like 10x and others using UMI barcodes.

```
$ fasterq-dump --threads 6 --split-files --include-technical SRR9320616 --outfile SRR9320616.fastq --progress

SRR9320616_1.fastq
SRR9320616_2.fastq
SRR9320616_3.fastq
```

This highlights that there is a discrepancy between the read data hosted on the ENA API and what can actually be fetched from sra-tools, where the latter seems to be the source of truth. If you anticipate that you may have more than 2 FastQ files per sample, it is recommended to use this pipeline with the `--download_method sratools` parameter.

See [issue #260](https://github.com/nf-core/fetchngs/issues/260) for more details.

### Primary options for downloading data

If the appropriate download links are available, the pipeline uses FTP by default to download FastQ files by setting the `--download_method ftp` parameter. If you are having issues and prefer to use sra-tools or Aspera instead, you can set the [`--download_method`](https://nf-co.re/fetchngs/parameters#download_method) parameter to `--download_method sratools` or `--download_method aspera`, respectively.

### Downloading dbGAP data with JWT

As of v1.10.0, the SRA Toolkit used in this pipeline can be configured to access protected data from dbGAP using a [JWT cart file](https://www.ncbi.nlm.nih.gov/sra/docs/sra-dbGAP-cloud-download/) on a supported cloud computing environment (Amazon Web Services or Google Cloud Platform). The JWT cart file can be specified with `--dbgap_key /path/to/cart.jwt`.

Note that due to the way the pipeline resolves SRA IDs down to the experiment to be able to merge multiple runs, your JWT cart file must be generated for _all_ runs in an experiment. Otherwise, upon running `prefetch` and `fasterq-dump`, the pipeline will return a `403 Error` when trying to download data for other runs under an experiment that are not authenticated for with the provided JWT cart file.

Users can log into the [SRA Run Selector](https://www.ncbi.nlm.nih.gov/Traces/study/), search for the dbGAP study they have been granted access to using the phs identifier, and select all available runs to activate the `JWT Cart` button to download the file.

To test this functionality in your cloud computing environment, you can use the protected dbGAP cloud testing study with experiment accession `SRX512039`:

- On the [SRA Run Selector page for `SRX512039`](https://www.ncbi.nlm.nih.gov/Traces/study/?acc=SRX512039&o=acc_s%3Aa), select the two available runs (`SRR1219865` and `SRR1219902`) and click on `JWT Cart` to download a key file called `cart.jwt` that can be directly provided to the pipeline with `--dbgap_key cart.jwt`
- Click on `Accession List` to download a text file called `SRR_Acc_List.txt` with the SRR IDs that can be directly provided to the pipeline with `--input SRR_Acc_List.txt`

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/fetchngs --input ./ids.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

:::warning
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
:::

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/fetchngs -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './ids.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/fetchngs
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/fetchngs releases page](https://github.com/nf-core/fetchngs/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

:::tip
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.
:::

## Core Nextflow arguments

:::note
These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).
:::

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

:::info
We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.
:::

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
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
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version may be out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

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
