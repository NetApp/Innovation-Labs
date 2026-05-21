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

The extractor service runs as an independent microservice. It supports CPU-only and GPU-accelerated modes, with optional Vision Language Model (VLM) pipelines for scanned and image-heavy documents.

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

The extractor service automatically selects the best extraction backend based on file type and characteristics. If the primary extractor fails or returns empty content, the service falls back to the next available backend in the chain.

**How it works:**

1. The strategy router examines the file extension and size.
2. It selects the most appropriate backend and identifies fallback alternatives.
3. If the primary extractor fails, it automatically retries with the next backend in the chain.

Plain text files are always handled by the TextExtractor. For binary formats (PDFs, Office documents, images), the router selects between MarkItDown and Docling based on file characteristics, ensuring the fastest and most reliable extraction for each document.

---

## VLM Models

The Docling VLM pipeline supports multiple Vision Language Models. Based on [benchmark testing](#vlm-benchmarking-tool), only a subset of models work reliably with current dependencies.

### Working Models

| Model Spec | VRAM Required | Notes |
|------------|---------------|-------|
| `GRANITEDOCLING_TRANSFORMERS` | ~5 GB peak | **Recommended.** Best extraction quality on scanned documents with minimal OCR artifacts. |
| `SMOLDOCLING_TRANSFORMERS` | ~3 GB peak | Smaller and faster, but may produce lower quality output on multi-page structured forms. |

### When to Use VLM vs Standard OCR

| Document Type | Recommended Pipeline | Reason |
|---------------|---------------------|--------|
| Scanned/image-heavy PDFs | Docling VLM (Granite-Docling) | Superior content extraction on scanned pages |
| Text-native PDFs and forms | Standard Docling OCR | Faster processing with good results on structured forms |
| Office documents | MarkItDown | Native format conversion, no GPU needed |
| Plain text / source code | TextExtractor | Direct read, fastest |

> [!NOTE]
> VLM extraction produces significantly better results on scanned documents but is considerably slower than the standard OCR pipeline. Use VLM only when standard extraction produces poor results.

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

For each VLM model and each test document, the benchmark records extraction completeness, content quality metrics, processing time, and GPU memory usage. The standard Docling OCR pipeline is included as a baseline for comparison.

Results are saved as JSON for programmatic analysis.

---

## Recrawl Missing Content

If some files were not extracted successfully (due to transient errors, timeouts, or service restarts), you can re-queue them for extraction without re-crawling the entire share.

### API Endpoint

```
POST /shares/{share_id}/recrawl-missing-content
```

**Authentication:** Requires a valid user token.

The endpoint identifies files with incomplete or missing extracted content and re-queues them for processing.

### Example

```bash
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
