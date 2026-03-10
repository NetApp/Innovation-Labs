# Content Extraction

This guide explains how Project Neo's extractor service converts files from your shares into searchable text content used for full-text search and Named Entity Recognition (NER).

---

## Table of Contents

1. [Overview](#overview)
2. [Extraction Backends](#extraction-backends)
3. [Intelligent Routing & Fallback Chain](#intelligent-routing--fallback-chain)
4. [VLM Models](#vlm-models)
5. [Configuration](#configuration)
6. [VLM Benchmarking Tool](#vlm-benchmarking-tool)
7. [Recrawl Missing Content](#recrawl-missing-content)

---

## Overview

The **extractor service** is the component responsible for reading files from mounted SMB shares and extracting their text content. Extracted content is stored in the database and used for:

- **Full-text search** -- users can search across all indexed file content via the API or MCP tools.
- **Named Entity Recognition (NER)** -- the NER service processes extracted text to identify entities such as people, organizations, addresses, financial data, and personally identifiable information (PII).

The extractor service runs as an independent microservice that pulls work items from a shared queue. It supports CPU-only and GPU-accelerated modes, with optional Vision Language Model (VLM) pipelines for scanned and image-heavy documents.

---

## Extraction Backends

Project Neo includes four extraction backends, each optimized for different file types.

### TextExtractor

The simplest backend. Reads plain text and source code files directly with no conversion. Supports automatic encoding detection, trying UTF-8, UTF-8 with BOM, Latin-1, and CP1252 in order.

**Supported extensions (50+):**

| Category | Extensions |
|----------|-----------|
| Source code | `.py`, `.js`, `.ts`, `.jsx`, `.tsx`, `.java`, `.c`, `.cpp`, `.h`, `.hpp`, `.cs`, `.go`, `.rs`, `.rb`, `.php`, `.swift`, `.kt`, `.scala`, `.pl`, `.pm`, `.lua`, `.vim` |
| Shell scripts | `.sh`, `.bash`, `.zsh`, `.ps1`, `.bat`, `.cmd` |
| Data / config | `.json`, `.jsonl`, `.yaml`, `.yml`, `.toml`, `.ini`, `.cfg`, `.conf`, `.env`, `.csv`, `.tsv`, `.sql` |
| Documentation | `.txt`, `.md`, `.markdown`, `.rst`, `.tex`, `.log` |
| Web / markup | `.html`, `.htm`, `.xml`, `.xhtml`, `.css`, `.graphql`, `.proto` |
| Dot files | `.gitignore`, `.dockerignore`, `.editorconfig`, `.config` |

### MarkItDown

Primary extractor for Office documents, PDFs, images, and archives. Uses Microsoft's [MarkItDown](https://github.com/microsoft/markitdown) library to convert binary formats into Markdown text. Optionally integrates with OpenAI for enhanced image and audio description.

**Supported extensions:**

`.pdf`, `.docx`, `.doc`, `.pptx`, `.ppt`, `.xlsx`, `.xls`, `.rtf`, `.zip`, `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`, `.webp`, `.mp3`, `.wav`, `.ogg`, `.aac`

When an `OPENAI_API_KEY` is configured, MarkItDown sends images and audio to the OpenAI API for richer descriptions.

### Docling (Standard OCR Pipeline)

GPU-accelerated extraction using IBM's [Docling](https://github.com/DS4SD/docling) library. Handles PDFs with OCR and table structure recognition. Automatically detects and uses CUDA GPUs when available, falling back to CPU if none are found or if `EXTRACTOR_FORCE_CPU=true`.

**Supported extensions:**

`.pdf`, `.docx`, `.xlsx`, `.pptx`, `.png`, `.jpg`, `.jpeg`, `.tiff`, `.bmp`, `.webp`, `.md`, `.markdown`, `.html`, `.xhtml`, `.csv`

This is the recommended pipeline for text-native PDFs and structured forms, where it extracts embedded text directly and preserves table layouts.

### Docling VLM (Vision Language Models)

Advanced GPU-accelerated pipeline that processes documents as images using Vision Language Models. Best suited for scanned documents and image-heavy PDFs where traditional OCR produces poor results.

**Supported extensions:** `.pdf`

Operates in two modes:

- **Local model** -- runs a VLM directly on the GPU (requires CUDA). Set `VLM_MODEL` to a model spec name such as `GRANITEDOCLING_TRANSFORMERS`.
- **Remote API** -- sends pages to an external vLLM or Ollama endpoint. Set `VLM_MODEL=api` with `VLM_API_URL` pointing to the inference server.

---

## Intelligent Routing & Fallback Chain

The extractor service uses a **strategy router** (`ExtractionStrategy`) that selects the best backend based on file extension and file size. If the primary extractor fails, the service automatically falls back to the next extractor in the chain.

### Routing Rules

| File Type | Small Files | Large Files | Threshold |
|-----------|------------|-------------|-----------|
| **Plain text / source code** | TextExtractor | TextExtractor | -- |
| **PDF** | MarkItDown, then Docling | Docling, then MarkItDown | 1 MB |
| **Office** (`.docx`, `.xlsx`, `.pptx`, etc.) | MarkItDown, then Docling | Docling, then MarkItDown | 2 MB |
| **Images** (`.jpg`, `.png`, `.tiff`, etc.) | MarkItDown, then Docling | Docling, then MarkItDown | 512 KB |
| **Markup** (`.html`, `.xml`, etc.) | TextExtractor, then Docling | Docling, then TextExtractor | 5 MB |
| **Unknown extensions** | MarkItDown, then Docling | MarkItDown, then Docling | -- |

**How it works:**

1. The strategy router examines the file extension and size.
2. It returns an ordered list of extractors to try.
3. The service attempts the first extractor. If it fails or returns empty content, it tries the next one.
4. For small PDFs and Office files, MarkItDown is tried first because it is faster. For large files, Docling is preferred because it handles complex layouts and large documents more reliably.

### Example

A 3 MB PDF file:
1. File size (3 MB) exceeds the PDF threshold (1 MB).
2. Strategy returns: `["docling", "markitdown"]`.
3. Docling attempts extraction with OCR and table recognition.
4. If Docling fails (e.g., not installed), MarkItDown handles it as a fallback.

---

## VLM Models

The Docling VLM pipeline supports multiple Vision Language Models. Based on [benchmark testing](#vlm-benchmarking-tool), only a subset of models work reliably with current dependencies.

### Working Models

| Model Spec | HuggingFace Repo | Output Format | VRAM Required | Notes |
|------------|------------------|---------------|---------------|-------|
| `GRANITEDOCLING_TRANSFORMERS` | `ibm-granite/granite-docling-258M` | DOCTAGS | ~5 GB peak | **Recommended.** Best extraction quality on scanned documents. 3.4x more content than OCR baseline on image-heavy PDFs with zero OCR artifacts. |
| `SMOLDOCLING_TRANSFORMERS` | `docling-project/SmolDocling-256M-preview` | DOCTAGS | ~3 GB peak | Smaller and faster, but produces hallucinated output on multi-page structured forms. Not recommended for complex documents. |

### Models Requiring Specific Hardware or Software

| Model Spec | HuggingFace Repo | VRAM Required | Status |
|------------|------------------|---------------|--------|
| `GOT2_TRANSFORMERS` | `stepfun-ai/GOT-OCR-2.0-hf` | ~1.5 GB | Blocked by SDPA attention incompatibility in transformers 4.57+. |
| `DOLPHIN_TRANSFORMERS` | `ByteDance/Dolphin` | ~2 GB | Same SDPA issue as GOT2. |
| `GRANITE_VISION_TRANSFORMERS` | `ibm-granite/granite-vision-3.2-2b` | ~4 GB | Requires isolated GPU process; OOMs when sharing VRAM with other models. |
| `PHI4_TRANSFORMERS` | `microsoft/Phi-4-multimodal-instruct` | ~8 GB | Requires `transformers<4.52.0`. |
| `PIXTRAL_12B_TRANSFORMERS` | `mistral-community/pixtral-12b` | ~24 GB | Requires high-end GPU (A100, H100, or multi-GPU). |

### When to Use VLM vs Standard OCR

| Document Type | Recommended Pipeline | Reason |
|---------------|---------------------|--------|
| Scanned/image-heavy PDFs | Docling VLM (Granite-Docling) | 3.4x better content extraction than OCR on scanned pages |
| Text-native PDFs and forms | Standard Docling OCR | 5x more content on structured forms, 25x faster |
| Office documents | MarkItDown | Native format conversion, no GPU needed |
| Plain text / source code | TextExtractor | Direct read, fastest |

::: warning Performance Trade-off
VLM extraction is approximately 25x slower than the standard OCR pipeline. Granite-Docling averaged 5 minutes 49 seconds per document vs 14 seconds for OCR baseline in benchmarks. Use VLM only when standard extraction produces poor results.
:::

---

## Configuration

All configuration is done through environment variables, typically set in `docker-compose.yml`.

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `EXTRACTOR_DEFAULT_PIPELINE` | `markitdown` | Default extraction pipeline when strategy routing is not used. Options: `markitdown`, `docling`, `text`. |
| `EXTRACTOR_FORCE_CPU` | `false` | Force CPU-only processing even when a GPU is available. Set to `true` to disable CUDA. |
| `EXTRACTOR_LOG_LEVEL` | `INFO` | Log verbosity. Options: `DEBUG`, `INFO`, `WARNING`, `ERROR`. |
| `DOCLING_CONCURRENCY` | `1` | Maximum number of concurrent Docling extraction jobs. Increase if you have sufficient GPU VRAM and CPU cores. Higher values use more memory. |

### VLM Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLM_MODEL` | *(empty)* | VLM model to use. Set to a model spec name (e.g., `GRANITEDOCLING_TRANSFORMERS`) for local GPU inference, or `api` for remote API mode. Leave empty to disable VLM. |
| `VLM_API_URL` | *(empty)* | API endpoint URL when `VLM_MODEL=api`. Compatible with vLLM and Ollama OpenAI-compatible endpoints. Example: `http://vllm:8000/v1/chat/completions`. |
| `VLM_API_MODEL` | `ds4sd/SmolDocling-256M-preview` | Model name to request from the remote API when using `VLM_MODEL=api`. |

### OpenAI Integration (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENAI_API_KEY` | *(empty)* | OpenAI API key for enhanced image and audio description in MarkItDown. Leave empty to disable. |
| `OPENAI_MODEL` | `gpt-4o` | OpenAI model to use for image/audio description. |

### Example Docker Compose Configuration

```yaml
services:
  extractor:
    environment:
      # Use standard OCR by default, Granite-Docling VLM when GPU is available
      EXTRACTOR_DEFAULT_PIPELINE: markitdown
      EXTRACTOR_FORCE_CPU: "false"
      DOCLING_CONCURRENCY: "1"

      # Enable VLM for scanned document extraction
      VLM_MODEL: GRANITEDOCLING_TRANSFORMERS

      # Or use a remote vLLM server instead of local GPU:
      # VLM_MODEL: api
      # VLM_API_URL: http://vllm-server:8000/v1/chat/completions
      # VLM_API_MODEL: ds4sd/SmolDocling-256M-preview
```

---

## VLM Benchmarking Tool

Project Neo includes a built-in benchmarking tool to evaluate VLM model performance on your own documents and hardware.

### Running the Benchmark

```bash
# Rebuild extractor to include benchmark script
docker compose up -d --build extractor

# Copy test PDFs into the container
docker compose cp ./my-test-pdfs/. extractor:/tmp/benchmark_pdfs/

# Run benchmark against all available VLM models
docker compose exec extractor python3 -m extractor_service.app.benchmark_vlm \
  --pdf-dir /tmp/benchmark_pdfs \
  --output /tmp/vlm_benchmark_results.json

# Copy results out
docker cp $(docker compose ps -q extractor):/tmp/vlm_benchmark_results.json .
```

### What It Measures

For each VLM model and each test document, the benchmark records:

- **Word count** and **character count** -- measures extraction completeness.
- **Long words** (>30 characters) -- detects OCR artifacts where spaces between words are missed.
- **Repeated lines** -- detects hallucination patterns where models emit repeated sequences.
- **Image placeholder count** -- counts image tags in output.
- **Extraction time** -- wall-clock duration.
- **Peak VRAM usage** -- GPU memory consumption.
- **Content sample** -- first 500 characters for manual quality inspection.

The standard Docling OCR pipeline is included as a baseline for comparison.

### Interpreting Results

- High word count with low long-word count indicates clean, complete extraction.
- Low word count relative to baseline suggests the model missed content.
- High repeated-line count indicates hallucination (the model generates plausible-looking but fabricated text).
- Results are saved as JSON for programmatic analysis.

---

## Recrawl Missing Content

If some files were not extracted successfully (due to transient errors, timeouts, or service restarts), you can re-queue them for extraction without re-crawling the entire share.

### API Endpoint

```
POST /shares/{share_id}/recrawl-missing-content
```

**Authentication:** Requires a valid user token.

### What It Does

The endpoint identifies files with missing content in two categories:

1. **NULL content** -- files that have metadata records but the content field is NULL (extraction started but failed).
2. **Unextracted files** -- files in the inventory that are stuck in `discovered` status with no metadata at all (extraction was never attempted).

For each identified file, the endpoint:

1. Deletes any stale metadata records (for NULL content files).
2. Resets the file inventory status so extraction can be reattempted.
3. Queues new extraction work items at priority 3.
4. Sets the share status back to `PROCESSING`.

### Example

```bash
# Get an auth token
TOKEN=$(curl -s -X POST http://localhost:8000/token \
  -d "username=admin&password=yourpassword" | jq -r .access_token)

# Recrawl missing content for a specific share
curl -X POST http://localhost:8000/shares/{share_id}/recrawl-missing-content \
  -H "Authorization: Bearer $TOKEN"
```

### Response

```json
{
  "status": "queued",
  "share_id": "abc123",
  "files_queued": 42,
  "files_found": 45
}
```

If no files are missing content:

```json
{
  "status": "no_action",
  "share_id": "abc123",
  "message": "No files with missing content found",
  "files_queued": 0
}
```
