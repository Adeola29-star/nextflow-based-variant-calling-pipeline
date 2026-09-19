nextflow.enable.dsl = 2

process FASTQC {
    container 'biocontainers/fastqc:v0.11.9_cv8'

    publishDir 'results/fastqc', mode: 'copy'

    input:
    tuple val(sample_id), path(read1), path(read2)

    output:
    path("*.{html,zip}")

    script:
    """
    fastqc ${read1} ${read2}
    """
}

process BWA_ALIGN {
    container 'quay.io/biocontainers/mulled-v2-fe8faa35dbf6dc65a0f7f5d4ea12e31a79f73e40:66ed1b38d280722529bb8a0167b0cf02f8a0b488-0'

    publishDir 'results/aligned', mode: 'copy'

    input:
    tuple val(sample_id), path(read1), path(read2)
    path reference
    path reference_index

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam")

    script:
    """
    bwa mem -t 4 -R '@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:ILLUMINA' \
        ${reference} ${read1} ${read2} | \
    samtools sort -@ 4 -o ${sample_id}.sorted.bam -
    """
}

process MARK_DUPLICATES {
    container 'broadinstitute/gatk:4.5.0.0'

    publishDir 'results/dedup', mode: 'copy'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path("${sample_id}.dedup.bam"), path("${sample_id}.dedup.metrics.txt")

    script:
    """
    gatk MarkDuplicates \
        -I ${bam} \
        -O ${sample_id}.dedup.bam \
        -M ${sample_id}.dedup.metrics.txt
    """
}

process HAPLOTYPE_CALLER {
    container 'broadinstitute/gatk:4.5.0.0'

    publishDir 'results/variants', mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(metrics)
    path reference
    path reference_index

    output:
    tuple val(sample_id), path("${sample_id}.vcf.gz")

    script:
    """
    samtools index ${bam}
    gatk HaplotypeCaller \
        -R ${reference} \
        -I ${bam} \
        -L 21 \
        -O ${sample_id}.vcf.gz
    """
}

process MULTIQC {
    container 'multiqc/multiqc:v1.21'

    publishDir 'results/multiqc', mode: 'copy'

    input:
    path('*')

    output:
    path("multiqc_report.html")

    script:
    """
    multiqc .
    """
}

workflow {
    reads_ch = Channel.of(
        ['NA12878', file('data/NA12878_sub_R1.fastq.gz'), file('data/NA12878_sub_R2.fastq.gz')]
    )
    reference_ch = file('reference/Homo_sapiens.GRCh38.dna.primary_assembly.fa')
    reference_index_ch = Channel.fromPath([
        'reference/Homo_sapiens.GRCh38.dna.primary_assembly.fa.*',
        'reference/Homo_sapiens.GRCh38.dna.primary_assembly.dict'
    ]).collect()

    FASTQC(reads_ch)
    BWA_ALIGN(reads_ch, reference_ch, reference_index_ch)
    MARK_DUPLICATES(BWA_ALIGN.out)
    HAPLOTYPE_CALLER(MARK_DUPLICATES.out, reference_ch, reference_index_ch)
    MULTIQC(FASTQC.out.mix(MARK_DUPLICATES.out.map { it[2] }).collect())
}
