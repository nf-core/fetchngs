nextflow.enable.types = true

process SRA_RUNINFO_TO_FTP {
    tag "${runinfo_file.name.tokenize(".")[0]}"

    input:
    runinfo_file: Path

    output:
    file("*.runinfo_ftp.tsv")

    exec:
    def (samplesheet, header) = parseSraRuninfo(realPath(runinfo_file))
    header = ["id"] + header

    // the Python script did not create the output file if there were no samples
    if( !samplesheet )
        return

    // the Python script failed to sort missing sample identifiers alongside others
    if( null in samplesheet.keySet() && samplesheet.size() > 1 )
        throw new Exception("Input run info file has rows without an experiment accession")

    def prefix = runinfo_file.name.tokenize(".")[0]
    def file_out = task.workDir.resolve("${prefix}.runinfo_ftp.tsv")
    file_out << formatTsvRecord(header)

    samplesheet
        .keySet()
        .toSorted()
        .each { id ->
            samplesheet[id].each { row ->
                row.id = "${id}_${row.run_accession}"
                file_out << formatTsvRecord(header.collect { k -> row[k] })
            }
        }
}


def parseSraRuninfo(file_in: Path) {
    def runinfo = [:] as Map<String,List<Map>>
    def columns = [
        "run_accession",
        "experiment_accession",
        "library_layout",
        "fastq_ftp",
        "fastq_md5",
    ]
    def records = parseTsv(file_in.text)
    def header = records ? records.first() : []
    def missing = columns.findAll { c -> c !in header }
    if( missing )
        throw new Exception("The following expected columns are missing from ${file_in}: ${missing.join(', ')}.")

    records.tail().findAll { fields -> fields }.each { fields ->
        if( fields.size() > header.size() )
            throw new Exception("Input run info file has a row with more fields than the header: ${fields}")
        def row = (0..<header.size()).inject([:]) { acc, i ->
            acc[header[i]] = i < fields.size() ? fields[i] : null
            acc
        }
        def db_id = row.experiment_accession
        def sample = getSample(row, file_in.name)

        sample += row
        if( db_id !in runinfo ) {
            runinfo[db_id] = [sample]
        }
        else {
            if( sample in runinfo[db_id] )
                log.error("Input run info file contains duplicate rows: ${row}")
            else
                runinfo[db_id].add(sample)
        }
    }

    return tuple(runinfo, header + getExtensions())
}


def getSample(row: Map, filename: String) -> Map {
    if( row.fastq_ftp ) {
        def fq_files = row.fastq_ftp.split(";", -1).toList().takeRight(2)
        def fq_md5 = row.fastq_md5.split(";", -1).toList().takeRight(2)
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

        assert fq_files[0].endsWith("_1.fastq.gz") : "Unexpected FastQ file format ${filename}."
        assert fq_files[1].endsWith("_2.fastq.gz") : "Unexpected FastQ file format ${filename}."
        if( row.library_layout != "PAIRED" )
            log.warn("The library layout '${row.library_layout}' should be 'PAIRED'.")
        return [
            "fastq_1": fq_files[0],
            "fastq_2": fq_files[1],
            "md5_1": fq_md5[0],
            // get() fails like the Python script when there are fewer md5s than files
            "md5_2": fq_md5.get(1),
            "single_end": "false",
        ]
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


def getExtensions() -> List<String> {
    return [
        "fastq_1",
        "fastq_2",
        "md5_1",
        "md5_2",
        "single_end",
    ]
}


/**
 * Parse TSV text into records, matching Python's csv.reader with
 * delimiter="\t" and skipinitialspace=True.
 */
def parseTsv(text: String) -> List<List<String>> {
    // insert an end-of-line marker ('') after each line, as Python does
    def n = text.length()
    def chars = (0..<n).collectMany { i ->
        def c = text[i]
        def eol = c == '\n' || (c == '\r' && (i + 1 == n || text[i + 1] != '\n'))
        eol ? [c, ''] : [c]
    }.toList()
    if( n > 0 && text[n - 1] != '\n' && text[n - 1] != '\r' )
        chars = chars + ['']

    def records = []
    def record = []
    def field = ''
    def state = 'START_RECORD'
    chars.each { c ->
        if( state == 'START_RECORD' && c != '' && c != '\n' && c != '\r' )
            state = 'START_FIELD'

        if( state == 'START_RECORD' ) {
            if( c != '' )
                state = 'EAT_CRNL'
        }
        else if( state == 'START_FIELD' ) {
            if( c == '' || c == '\n' || c == '\r' ) {
                record = record + [field]
                field = ''
                state = c == '' ? 'START_RECORD' : 'EAT_CRNL'
            }
            else if( c == '"' ) {
                state = 'IN_QUOTED_FIELD'
            }
            else if( c == '\t' ) {
                record = record + [field]
                field = ''
            }
            else if( c != ' ' ) {
                field += c
                state = 'IN_FIELD'
            }
        }
        else if( state == 'IN_FIELD' ) {
            if( c == '' || c == '\n' || c == '\r' ) {
                record = record + [field]
                field = ''
                state = c == '' ? 'START_RECORD' : 'EAT_CRNL'
            }
            else if( c == '\t' ) {
                record = record + [field]
                field = ''
                state = 'START_FIELD'
            }
            else {
                field += c
            }
        }
        else if( state == 'IN_QUOTED_FIELD' ) {
            if( c == '"' )
                state = 'QUOTE_IN_QUOTED_FIELD'
            else if( c != '' )
                field += c
        }
        else if( state == 'QUOTE_IN_QUOTED_FIELD' ) {
            if( c == '"' ) {
                field += c
                state = 'IN_QUOTED_FIELD'
            }
            else if( c == '\t' ) {
                record = record + [field]
                field = ''
                state = 'START_FIELD'
            }
            else if( c == '' || c == '\n' || c == '\r' ) {
                record = record + [field]
                field = ''
                state = c == '' ? 'START_RECORD' : 'EAT_CRNL'
            }
            else {
                field += c
                state = 'IN_FIELD'
            }
        }
        else if( state == 'EAT_CRNL' ) {
            if( c == '' )
                state = 'START_RECORD'
            else if( c != '\n' && c != '\r' )
                throw new Exception("New-line character seen in unquoted field")
        }

        if( c == '' && state == 'START_RECORD' ) {
            records = records + [record]
            record = []
        }
    }
    // a quoted field left open at the end of the input is saved as-is
    if( state == 'IN_QUOTED_FIELD' ) {
        record = record + [field]
        records = records + [record]
    }
    return records
}


/**
 * Format a TSV record, matching Python's csv.writer with delimiter="\t".
 */
def formatTsvRecord(values: Iterable) -> String {
    def fields = values.collect { v ->
        def s = v == null ? '' : v as String
        def quoted = ['\t', '"', '\r', '\n'].any { ch -> s.contains(ch) }
        quoted ? '"' + s.replace('"', '""') + '"' : s
    }
    return fields.join("\t") + "\r\n"
}


// shortcut: typed exec processes receive unreadable TaskPath inputs, remove once fixed in Nextflow
def realPath(file) {
    return file.toRealPath()
}
