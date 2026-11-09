# Nextflow Variant-Calling Pipeline

## Problem

Identifying genetic variants from raw sequencing reads requires several dependent processing stages, including quality control, alignment, duplicate marking and variant calling. Each stage uses specialised bioinformatics tools with different software dependencies.

Running these steps manually can be time-consuming, error-prone and difficult to reproduce. This project addresses these challenges by developing an automated, containerised Nextflow pipeline for processing paired-end sequencing reads through quality control, alignment, duplicate marking and germline variant calling.

## Approach

A Nextflow (DSL2) pipeline was developed to perform germline short-variant calling using publicly available whole-genome sequencing data from NA12878 (HG001), obtained from the European Nucleotide Archive (ENA), sequencing run **SRR8454587**.

Each process runs inside a Docker container to provide consistent software environments without requiring individual bioinformatics tools to be installed locally.

The pipeline consists of five processes:

1. **FastQC:** Assesses the quality of raw paired-end sequencing reads.
2. **BWA-MEM + SAMtools:** Aligns reads to the GRCh38 reference genome and generates a coordinate-sorted BAM file.
3. **GATK MarkDuplicates:** Identifies and marks duplicate reads, producing a duplicate-marked BAM file and duplication metrics.
4. **GATK HaplotypeCaller:** Performs germline short-variant calling, restricted to chromosome 21.
5. **MultiQC:** Consolidates FastQC and duplicate-marking metrics into a quality-control report.

The analysis uses a subsampled dataset targeting approximately **0.65× whole-genome coverage**, making the workflow practical to execute on a personal laptop while demonstrating an end-to-end computational variant-calling workflow.

**Execution environment:** Ubuntu on Windows Subsystem for Linux (WSL2), Nextflow 26.04.6 and Docker.

## Dataset

The analysis uses NA12878 (HG001), a well-characterised human reference sample widely used in genomic benchmarking.

- **Sample:** NA12878 (HG001)
- **ENA sequencing run:** [SRR8454587](https://www.ebi.ac.uk/ena/browser/view/SRR8454587)
- **BioSample:** SAMN10641991
- **Study accession:** PRJNA511646
- **Sequencing platform:** Illumina HiSeq 4000
- **Data type:** Paired-end whole-genome sequencing
- **Analysis dataset:** Subsample targeting approximately 0.65× coverage
- **Reference genome:** GRCh38 primary assembly
- **Variant-calling region:** Chromosome 21
- **Data source:** European Nucleotide Archive

### Data preparation

The original paired-end FASTQ files were downloaded from ENA and verified using their published MD5 checksums.

A reproducible random subsample was generated using **seqtk 1.4-r122**, with:

- Random seed: `42`
- Sampling fraction: `0.021326`
- Validated output: **6,727,605 matching read pairs**

The prepared FASTQ files are:

```text
data/coverage_0.65x/NA12878_R1.fastq.gz
data/coverage_0.65x/NA12878_R2.fastq.gz
```

The 0.65× value represents the approximate target whole-genome coverage, not a measured average depth across chromosome 21.

Raw sequencing data and reference genome files are excluded from the GitHub repository because of their size.

## Results

**Key results:**

- Successful quality-control processing of paired-end reads using FastQC.
- Alignment against the GRCh38 reference genome using BWA-MEM.
- Generation of coordinate-sorted and duplicate-marked BAM files.
- Successful germline variant calling on chromosome 21 using GATK HaplotypeCaller.
- **7,572 raw variant records** identified.
- **6,819 simple biallelic SNP records** (90.1%).
- **753 other variant records** (9.9%), including potential indels and multiallelic variants.
- All 7,572 records have `FILTER = .`, indicating that no filtering status was assigned.
- Consolidated quality-control reporting using MultiQC.

The variant count represents unfiltered HaplotypeCaller output and should not be interpreted as a count of validated variants.

### Quality-control reports

The pipeline generated the following reports:

- FastQC Report — Read 1: `results/fastqc/NA12878_R1_fastqc.html`
- FastQC Report — Read 2: `results/fastqc/NA12878_R2_fastqc.html`
- MultiQC Dashboard: `results/multiqc/multiqc_report.html`

These reports provide access to sequencing quality assessments and duplicate-marking metrics.

## Repository Contents

```text
nextflow-based-variant-calling-pipeline/
├── main.nf
├── nextflow.config
├── README.md
├── .gitignore
└── results/
    ├── fastqc/
    │   ├── NA12878_R1_fastqc.html
    │   ├── NA12878_R1_fastqc.zip
    │   ├── NA12878_R2_fastqc.html
    │   └── NA12878_R2_fastqc.zip
    └── multiqc/
        └── multiqc_report.html
```

The repository structure above represents the intended publication layout.

Large sequencing inputs, reference files, BAM files, VCF files and Nextflow working directories are retained locally and excluded from version control.

## Limitations

- **Low sequencing coverage:** The approximately 0.65× dataset provides limited evidence for reliable germline variant detection, particularly heterozygous variants.
- **Single-chromosome analysis:** Variant calling was restricted to chromosome 21 to reduce computational requirements.
- **No base quality score recalibration:** BQSR was not included in the workflow.
- **No variant filtering:** Raw HaplotypeCaller calls were not subjected to additional quality filtering.
- **No functional annotation:** Variants were not annotated for gene consequences or clinical significance.
- **Single-sample analysis:** Joint genotyping across multiple samples was not performed.
- **No truth-set benchmarking:** Precision, recall and other accuracy metrics were not evaluated against a high-confidence reference call set.
- **Local execution:** The workflow was executed on a personal computer rather than an HPC cluster or cloud infrastructure.

These limitations reflect the project's focus on reproducible workflow development and containerised bioinformatics analysis rather than clinically validated variant detection.

## Usage

### Requirements

- Nextflow
- Docker
- Prepared paired-end FASTQ files
- GRCh38 primary assembly reference FASTA
- BWA reference indexes, FASTA index and sequence dictionary

The input files and reference resources must be available at the paths specified in `nextflow.config`.

Run the pipeline from the project directory:

```bash
nextflow run main.nf
```

To resume a previously interrupted execution:

```bash
nextflow run main.nf -resume
```

The pipeline generates FastQC reports, aligned and duplicate-marked BAM files, raw germline variant calls and a consolidated MultiQC report.

**Note:** The current configuration references a shared GRCh38 directory outside the project folder. Users running the pipeline in a different environment must update the input and reference paths accordingly.

## Future Work

The next phase extends this work through a separate project incorporating selected **nf-core/sarek** workflow capabilities and benchmarking against Genome in a Bottle (GIAB) high-confidence reference data.

The extension will focus on evaluating variant-calling performance, investigating the limitations of low-coverage sequencing and assessing potential improvements to the original workflow.

The original project provides the baseline implementation for this comparative analysis.
