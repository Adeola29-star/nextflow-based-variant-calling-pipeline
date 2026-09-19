cat > README.md << 'EOF'
# Nextflow Variant-Calling Pipeline

## Problem

Identifying genetic variants from raw sequencing reads requires several dependent processing stages; quality control, alignment, duplicate removal, and variant calling. Each uses different bioinformatics tools with their own software dependencies. Run manually, this process is slow, error-prone, difficult to reproduce exactly on another machine, and hard to scale to more samples. This project addresses that by building an automated, fully containerised pipeline that performs the full process end-to-end from raw reads to called variants, reliably and reproducibly on any machine with Docker and Nextflow installed.

## Approach

A Nextflow (DSL2) pipeline was built to perform germline short-variant calling on a public 1000 Genomes Project sample (NA12878). **Every stage runs inside its own Docker container**, declared per-process in `main.nf` and enabled via `docker.enabled = true` in `nextflow.config`. No bioinformatics tools (BWA, samtools, GATK, FastQC, MultiQC) need to be installed locally at all; Docker pulls and runs each one automatically.

Pipeline stages:

1. **FastQC** (containerised) - quality control on raw paired-end reads
2. **BWA-MEM + samtools** (containerised, single combined image) - alignment to the GRCh38 reference with BWA-MEM, piped directly into `samtools sort` to produce a sorted BAM in one step, avoiding an intermediate SAM file on disk entirely
3. **GATK MarkDuplicates** (containerised) - PCR/optical duplicate flagging; the resulting BAM is indexed with `samtools index` for downstream processing
4. **GATK HaplotypeCaller** (containerised) - germline variant calling, restricted to chromosome 21
5. **MultiQC** (containerised) - consolidated QC report combining FastQC and MarkDuplicates output

For this pipeline, reads were randomly subsampled to ~5% of the original depth (via `seqtk`), giving an effective coverage of roughly 0.65×, and variant calling was restricted to chromosome 21. Both are done to keep runtime and resource use practical on a personal laptop while still producing genuine, biologically realistic results.

**Execution environment:** developed and run entirely on a personal laptop, using a Linux environment (Ubuntu via WSL2 on Windows) rather than a cloud instance or HPC cluster. Long-running steps (alignment, variant calling) were executed inside `tmux` sessions, so the pipeline continued running independently of the terminal connection. This is a practical safeguard against local machine interruptions (terminal disconnects, system sleep) that cloud or HPC execution environments typically handle natively via job schedulers.

## Dataset

The pipeline uses NA12878 (HG001), a well-characterised human reference sample from the 1000 Genomes Project. The sequencing data were obtained from the European Nucleotide Archive (ENA) and correspond to sequencing run ERR174310. The dataset consists of paired-end whole-genome sequencing (WGS) reads generated on an Illumina platform, with approximately 13× coverage.

- **Sample:** NA12878 (HG001) - [IGSR sample record](https://www.internationalgenome.org/data-portal/sample/NA12878)
- **Project:** 1000 Genomes Project
- **Run accession:** ERR174310 - [ENA run record](https://www.ebi.ac.uk/ena/browser/view/ERR174310)
- **Data type:** Paired-end whole-genome sequencing (WGS)
- **Read length:** 101 bp
- **Approximate original coverage:** 13×
- **Reference genome:** GRCh38
- **Data source:** European Nucleotide Archive (ENA)
The original paired FASTQ files were downloaded from the ENA and are excluded from this repository due to file size; the accession above makes the input dataset identifiable and independently reproducible without version-controlling the raw sequencing data.

## Result

The pipeline completed successfully end-to-end with no manual intervention (`nextflow run main.nf`, 5 of 5 processes succeeded, fully containerised and confirmed via `docker images`). On chromosome 21, 7,209 variants were called from the subsampled NA12878 data, with realistic genotype, depth, and quality distributions. A consolidated MultiQC report was generated alongside the variant calls. FastQC showed no critical quality failures, with two WARNs (per-sequence GC content; per-tile quality on one read file) that did not indicate a major quality issue. MarkDuplicates reported a 0.07% duplication rate.

## Repository contents

This repository contains only the pipeline code, Docker configuration, and QC reports (`results/fastqc/`, `results/multiqc/`). Raw sequencing data, the reference genome, Nextflow's working cache, and large intermediate outputs (BAM, VCF) are excluded. These remain in a separate local working directory and are excluded here via `.gitignore`, both because of GitHub's file size limits and because they are fully reproducible by re-running the pipeline rather than needing to be version-controlled.

## Limitations

What this pipeline does not check for, and what a production genomics team would add before trusting it at scale:

- **Subsampled coverage.** Reads were reduced to ~5% of original depth (~0.65× effective coverage, down from ~13× in the source data) for practical runtime. A production pipeline would run at full depth (typically 30x+ for germline WGS) for reliable variant confidence, particularly at heterozygous sites.
- **Single-chromosome scope.** Variant calling was restricted to chromosome 21 rather than genome-wide, again for runtime.
- **Personal-laptop execution.** The pipeline was developed and run on a single personal Linux (WSL2) machine rather than cloud or HPC infrastructure, using `tmux` to protect long-running steps from terminal/connection interruptions. A production deployment would instead run on managed compute (cloud VM, HPC cluster, or Nextflow's native executors for AWS Batch/Kubernetes/Slurm etc.), removing this dependency on a single machine staying powered on and connected.
- **No base quality score recalibration (BQSR).** GATK best practice typically recalibrates base quality scores to correct systematic sequencer errors before variant calling; this step was omitted here.
- **No variant filtering.** HaplotypeCaller's raw output was used as-is. A production pipeline would apply hard filters or GATK's VQSR to remove likely false-positive calls before treating the VCF as final.
- **No functional annotation.** Variants are reported by genomic position only, with no gene, consequence, or clinical-significance annotation (e.g. via VEP or ANNOVAR) . This is appropriate for a pipeline-engineering demonstration, but necessary for biological interpretation in a real analysis.
- **Single sample, no joint genotyping.** Multi-sample studies would typically use GATK's joint genotyping workflow (GenomicsDBImport + GenotypeGVCFs) for more accurate population-level calling.
- **No benchmarking against a truth set.** NA12878 has a publicly available high-confidence truth VCF from the Genome in a Bottle consortium. Calls were not benchmarked against it (e.g. via `hap.py`), so sensitivity/precision were not formally measured.
- **No read trimming step.** FastQC showed no adapter contamination in this dataset, so trimming was not required here. A general-purpose production pipeline would typically include a trimming step (e.g. fastp) regardless, to handle datasets where contamination is present.

## Usage

```bash
nextflow run main.nf
```

Requires Nextflow and Docker. See `results/fastqc/` and `results/multiqc/` for QC reports.
