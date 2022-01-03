
This pipeline forks nf-core/fetchngs and incorporates the [dmgfinder](https://github.com/jordiabante/dgmfinder) pipeline.

---

## Introduction

**nf-core/fetchngs** is a bioinformatics pipeline to fetch metadata and raw FastQ files from both public and private databases. At present, the pipeline supports SRA / ENA / DDBJ / GEO / Synapse ids (see [usage docs](https://nf-co.re/fetchngs/usage#introduction)).

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies.

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/fetchngs/results).

## Pipeline summary

Via a single file of ids, provided one-per-line (see [example input file](https://raw.githubusercontent.com/nf-core/test-datasets/fetchngs/sra_ids_test.txt)) the pipeline performs the following steps:

### SRA / ENA / DDBJ / GEO ids

1. Resolve database ids back to appropriate experiment-level ids and to be compatible with the [ENA API](https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access.html)
2. Fetch extensive id metadata via ENA API
3. Download FastQ files:
    - If direct download links are available from the ENA API, fetch in parallel via `curl` and perform `md5sum` check
    - Otherwise use [`sra-tools`](https://github.com/ncbi/sra-tools) to download `.sra` files and convert them to FastQ
4. Collate id metadata and paths to FastQ files in a single samplesheet

### Synapse ids

1. Resolve Synapse directory ids to their corresponding FastQ files ids via the `synapse list` command.
2. Retrieve FastQ file metadata including FastQ file names, md5sums, etags, annotations and other data provenance via the `synapse show` command.
3. Download FastQ files in parallel via `synapse get`
4. Collate paths to FastQ files in a single samplesheet

### Samplesheet format

The columns in the auto-created samplesheet can be tailored to be accepted out-of-the-box by selected nf-core pipelines, these currently include [nf-core/rnaseq](https://nf-co.re/rnaseq/usage#samplesheet-input) and the Illumina processing mode of [nf-core/viralrecon](https://nf-co.re/viralrecon/usage#illumina-samplesheet-format). You can use the `--nf_core_pipeline` parameter to customise this behaviour e.g. `--nf_core_pipeline rnaseq`. More pipelines will be supported in due course as we adopt and standardise samplesheet input across nf-core.

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run nf-core/fetchngs -profile test,<docker/singularity/podman/shifter/charliecloud/conda/institute>
    ```

    > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > - If you are using `singularity` then the pipeline will auto-detect this and attempt to download the Singularity images directly as opposed to performing a conversion from Docker images. If you are persistently observing issues downloading Singularity images directly due to timeout or network issues then please use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, it is highly recommended to use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to pre-download all of the required containers before running the pipeline and to set the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options to be able to store and re-use the images from a central location for future pipeline runs.
    > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    ```bash
    nextflow run nf-core/fetchngs --input ids.txt -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
    ```

## Documentation

The nf-core/fetchngs pipeline comes with documentation about the pipeline [usage](https://nf-co.re/fetchngs/usage), [parameters](https://nf-co.re/fetchngs/parameters) and [output](https://nf-co.re/fetchngs/output).

## Credits

nf-core/fetchngs was originally written by Harshil Patel ([@drpatelh](https://github.com/drpatelh)) from [Seqera Labs, Spain](https://seqera.io/) and Jose Espinosa-Carrasco ([@JoseEspinosa](https://github.com/JoseEspinosa)) from [The Comparative Bioinformatics Group](https://www.crg.eu/en/cedric_notredame) at [The Centre for Genomic Regulation, Spain](https://www.crg.eu/). Support for download of sequencing reads without FTP links via sra-tools was added by Moritz E. Beber ([@Midnighter](https://github.com/Midnighter)) from [Unseen Bio ApS, Denmark](https://unseenbio.com). The Synapse workflow was added by Daisy Han [@daisyhan97](https://github.com/daisyhan97) and Bruno Grande [@BrunoGrandePhD](https://github.com/BrunoGrandePhD) from [Sage Bionetworks, Seattle](https://sagebionetworks.org/).

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#fetchngs` channel](https://nfcore.slack.com/channels/fetchngs) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use  nf-core/fetchngs for your analysis, please cite it using the following doi: [10.5281/zenodo.5070524](https://doi.org/10.5281/zenodo.5070524)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
