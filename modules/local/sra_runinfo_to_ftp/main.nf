
process SRA_RUNINFO_TO_FTP {

    input:
    path runinfo_file

    output:
    path "*.runinfo_ftp.tsv", emit: tsv

    exec:
    def (runinfo, header) = parseSraRuninfo(runinfo_file)
    header.add(0, "id")

    def samplesheet = [:]
    runinfo.each { db_id, rows ->
        if( db_id !in samplesheet )
            samplesheet[db_id] = rows
        else
            log.warn("Duplicate sample identifier found -- ID: '${db_id}'")
    }

    def prefix = runinfo_file.name.tokenize(".")[0]
    def file_out = task.workDir.resolve("${prefix}.runinfo_ftp.tsv")
    file_out << header.join("\t") << "\n"

    samplesheet
        .sort { id, _rows -> id }
        .each { id, rows ->
            rows.each { row ->
                row.id = row.run_accession
                    ? "${id}_${row.run_accession}"
                    : id
                def values = header.collect { k -> row[k] }
                file_out << values.join("\t") << "\n"
            }
        }
}


def parseSraRuninfo(file_in) {
    def runinfo = [:]
    def columns = [
        "run_accession",
        "experiment_accession",
        "library_layout",
        "fastq_ftp",
        "fastq_md5",
    ]
    def records = file_in.splitCsv(header: true, sep: "\t")
    def header = file_in.readLines().first().tokenize("\t")
    def missing = columns.findAll { c -> c !in header }
    if( missing )
        throw new Exception("The following expected columns are missing from ${file_in}: ${missing.join(', ')}.")

    records.each { row ->
        def db_id = row.experiment_accession
        def sample = getSample(row, file_in.name)

        sample.putAll(row)
        if( db_id !in runinfo ) {
            runinfo[db_id] = [sample]
        }
        else {
            if( sample in runinfo[db_id] )
                log.error("Input run info file contains duplicate rows: ${row}")
            else
                runinfo[db_id].append(sample)
        }
    }

    return [ runinfo, (header + getExtensions()).unique() ]
}


def getSample(row, filename) {
    if( row.fastq_ftp ) {
        def fq_files = row.fastq_ftp.tokenize(";")
        def fq_md5 = row.fastq_md5.tokenize(";")
        if( fq_files.size() == 1 ) {
            assert fq_files[0].endsWith(".fastq.gz") : "Unexpected FastQ file format ${filename}."
            if( row.library_layout != "SINGLE" )
                log.warn("The library layout '${row.library_layout}' should be 'SINGLE'.")
            return [
                "fastq_1": fq_files[0],
                "fastq_2": null,
                "md5_1": fq_md5[0],
                "md5_2": null,
                "single_end": "true",
            ]
        }

        if( fq_files.size() == 2 ) {
            assert fq_files[0].endsWith("_1.fastq.gz") : "Unexpected FastQ file format ${filename}."
            assert fq_files[1].endsWith("_2.fastq.gz") : "Unexpected FastQ file format ${filename}."
            if( row.library_layout != "PAIRED" )
                log.warn("The library layout '${row.library_layout}' should be 'PAIRED'.")
            return [
                "fastq_1": fq_files[0],
                "fastq_2": fq_files[1],
                "md5_1": fq_md5[0],
                "md5_2": fq_md5[1],
                "single_end": "false",
            ]
        }

        throw new Exception("Unexpected number of FastQ files: ${fq_files}")
    }

    // In some instances, FTP links don't exist for FastQ files.
    // These have to be downloaded with the run accession using sra-tools.
    def sample = getExtensions().inject([:]) { acc, k ->
        acc[k] = null
        acc
    }
    if( row.library_layout == "SINGLE" )
        sample.single_end = "true"
    else if( row.library_layout == "PAIRED" )
        sample.single_end = "false"
    return sample
}


def getExtensions() {
    return [
        "fastq_1",
        "fastq_2",
        "md5_1",
        "md5_2",
        "single_end",
    ]
}
