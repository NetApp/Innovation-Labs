# Named Entity Recognition (NER)

Project Neo uses [GLiNER2](https://github.com/urchade/GLiNER) (Generalist and Lightweight model for Named Entity Recognition) to identify and extract structured entities from document text. NER runs as a dedicated microservice (`ner_service`) and processes files asynchronously via the worker queue after text extraction completes.

## How It Works

1. A file is uploaded to a share that has `enable_ner_analysis` turned on.
2. The worker service extracts text from the file (PDF, DOCX, etc.).
3. The worker sends the extracted text to the NER service over an internal HTTP call.
4. The NER service runs the GLiNER2 model against the text using the share's configured schema.
5. Detected entities, classifications, and structured extractions are stored in PostgreSQL.
6. Results are available immediately through the API.

The underlying model is **DeBERTa-v3-base** fine-tuned for zero-shot NER. It accepts a list of target entity labels and returns spans with confidence scores -- no task-specific training is needed.

## NER Schemas

A schema defines which entity types to extract, which document classifications to apply, and what structured fields to pull from the text. Five pre-built schemas ship with Neo.

### Default Schema

General-purpose extraction suitable for most document types.

| Entity Type | Description |
|---|---|
| `person` | Names of people, individuals, or human beings |
| `organization` | Company names, institutions, agencies, or organizations |
| `location` | Geographic locations, cities, countries, addresses |
| `date` | Dates, time periods, or temporal references |
| `money` | Monetary amounts, prices, or financial values |
| `email` | Email addresses |
| `phone` | Phone numbers or contact numbers |
| `url` | Web URLs or links |

**Classifications:** `document_type` (report, memo, email, contract, invoice, policy, manual, other), `language` (english, spanish, french, german, other)

**Default confidence threshold:** 0.7

### Legal Schema

Optimized for contracts, agreements, and court filings.

| Entity Type | Description |
|---|---|
| `party` | Legal parties, signatories, or contracting entities |
| `person` | Names of individuals mentioned in the document |
| `organization` | Company names, law firms, or institutions |
| `date` | Dates, deadlines, or time periods |
| `money` | Monetary amounts, fees, or financial terms |
| `jurisdiction` | Legal jurisdictions, courts, or governing law references |
| `case_number` | Case numbers, docket numbers, or reference numbers |
| `law_reference` | References to laws, statutes, or regulations |

**Classifications:** `document_type` (contract, agreement, amendment, nda, mou, letter_of_intent, court_filing, legal_opinion, terms_of_service, privacy_policy, other), `contract_status` (draft, pending_signature, executed, expired, terminated)

**Structured extraction:** `contract_terms` -- parties, effective_date, expiration_date, term_length, renewal, termination_notice, governing_law, total_value

**Default confidence threshold:** 0.75

### Financial Schema

Tailored for invoices, bank statements, and financial reports.

| Entity Type | Description |
|---|---|
| `company` | Company names, corporations, or business entities |
| `person` | Names of individuals, executives, or account holders |
| `money` | Monetary amounts, prices, or financial values |
| `percentage` | Percentage values, rates, or ratios |
| `date` | Dates, fiscal periods, or time references |
| `account_number` | Bank account numbers or financial account identifiers |
| `ticker` | Stock ticker symbols |
| `currency` | Currency types or codes |

**Classifications:** `document_type` (invoice, receipt, bank_statement, financial_report, tax_document, expense_report, purchase_order, quote, other), `transaction_type` (payment, refund, transfer, deposit, withdrawal, fee, other)

**Structured extraction:** `transaction` (amount, date, description, type, account, reference), `invoice_details` (invoice_number, vendor, customer, subtotal, tax, total, due_date)

**Default confidence threshold:** 0.8

### Healthcare Schema

Designed for medical records, lab reports, and prescriptions.

| Entity Type | Description |
|---|---|
| `patient` | Patient names or identifiers |
| `provider` | Healthcare provider names, doctors, or medical staff |
| `organization` | Hospitals, clinics, or healthcare facilities |
| `medication` | Drug names, medications, or pharmaceutical substances |
| `dosage` | Medication dosages, amounts, or frequencies |
| `condition` | Medical conditions, diagnoses, or symptoms |
| `procedure` | Medical procedures, treatments, or interventions |
| `date` | Dates, appointment times, or time references |
| `lab_value` | Laboratory test values or measurements |

**Classifications:** `document_type` (medical_record, lab_report, prescription, discharge_summary, referral, insurance_claim, consent_form, other), `urgency` (routine, urgent, emergency)

**Structured extraction:** `patient_info`, `prescription`, `visit_summary`

**Default confidence threshold:** 0.8

### HR Schema

Built for resumes, offer letters, and employee records.

| Entity Type | Description |
|---|---|
| `person` | Names of individuals, candidates, or employees |
| `organization` | Company names, employers, or institutions |
| `job_title` | Job titles, positions, or roles |
| `skill` | Skills, competencies, or qualifications |
| `education` | Educational institutions, degrees, or certifications |
| `date` | Dates, employment periods, or time references |
| `location` | Work locations, offices, or addresses |
| `salary` | Salary amounts, compensation, or benefits |
| `email` | Email addresses |
| `phone` | Phone numbers |

**Classifications:** `document_type` (resume, cover_letter, job_description, offer_letter, performance_review, employee_handbook, policy, other), `experience_level` (entry, mid, senior, executive)

**Structured extraction:** `candidate_info`, `employment_history`, `education`

**Default confidence threshold:** 0.7

## Configuration

The NER service is configured through environment variables set on the `ner` container.

| Variable | Default | Description |
|---|---|---|
| `NER_MODEL_NAME` | `fastino/gliner2-base-v1` | Hugging Face model identifier. The model is downloaded on first startup. |
| `NER_CONFIDENCE_THRESHOLD` | `0.7` | Global minimum confidence score (0.0--1.0). Per-share thresholds override this. |
| `NER_DEVICE` | `auto` | Compute device: `auto`, `cuda`, or `cpu`. `auto` selects CUDA when a GPU is detected. |
| `NER_MAX_TEXT_LENGTH` | `8000` | Maximum characters per chunk sent to the model. GLiNER2 has a 2048-token context window (~4 chars/token = ~8000 chars). |
| `NER_CUDA_MAX_TEXT_LENGTH` | `8000` | Hard cap on chunk size when running on CUDA to prevent out-of-memory errors. |
| `NER_CHUNK_OVERLAP` | `500` | Character overlap between adjacent chunks so entities at boundaries are not missed. |
| `NER_TOKEN_BUDGET` | `2048` | Token budget per chunk for the tokenizer-aware chunking path. |
| `NER_MAX_BATCH_SIZE` | `32` | Upper limit for adaptive batch sizing on GPU. |
| `NER_ESTIMATED_MB_PER_CHUNK` | `1500` | Estimated VRAM (MB) per chunk, used for initial batch size calculation before probing. |
| `NER_CPU_BATCH_SIZE` | `16` | Fixed batch size when running on CPU. |
| `NER_BATCH_RECOVERY_INTERVAL` | `50` | Number of successful inferences before attempting to increase batch size after an OOM. |
| `NER_MAX_CONSECUTIVE_OOMS` | `3` | After this many consecutive OOM errors, the engine falls back to CPU. |
| `NER_CUDA_RETRY_COOLDOWN` | `200` | Number of successful CPU inferences before retrying CUDA after an OOM fallback. |
| `NER_MAX_CUDA_RETRIES` | `3` | Maximum number of times to retry moving back to CUDA after OOM fallback. |

## Per-Share NER Settings

NER is enabled and configured per share through the share's rules. When creating or updating a share, include the NER fields in the `rules` object.

| Rule Field | Type | Default | Description |
|---|---|---|---|
| `enable_ner_analysis` | bool | `false` | Master switch -- set to `true` to run NER on files in this share. |
| `ner_schema` | string | `"default"` | Which pre-built schema to use (`default`, `legal`, `financial`, `healthcare`, `hr`). |
| `ner_entity_types` | list | `["person", "organization", "location", "date", "money"]` | Override the schema's entity types with a custom list. |
| `ner_classifications` | object | `null` | Override classification labels. |
| `ner_structured_extraction` | object | `null` | Override structured extraction fields. |
| `ner_confidence_threshold` | float | `0.7` | Minimum confidence for this share (overrides global and schema defaults). |

### Example: Creating a Share with Legal NER

```bash
curl -s -X POST "$NEO_URL/shares" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Legal Contracts",
    "path": "/mnt/contracts",
    "rules": {
      "enable_ner_analysis": true,
      "ner_schema": "legal",
      "ner_confidence_threshold": 0.75
    }
  }'
```

### Example: Custom Entity Types (No Schema)

```bash
curl -s -X POST "$NEO_URL/shares" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Research Papers",
    "path": "/mnt/research",
    "rules": {
      "enable_ner_analysis": true,
      "ner_entity_types": ["person", "organization", "date", "location", "chemical_compound", "gene_name"],
      "ner_confidence_threshold": 0.65
    }
  }'
```

## API Endpoints

All NER endpoints are under `/ner` and require a valid bearer token.

### List Schemas

```bash
curl -s "$NEO_URL/ner/schemas" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Returns all registered schemas with their entity types, classification availability, and structured extraction availability.

### Get a Specific Schema

```bash
curl -s "$NEO_URL/ner/schemas/legal" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Get NER Results for a File

```bash
curl -s "$NEO_URL/ner/files/{file_id}" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Returns entities, classifications, and structured extractions for a single file.

### Get NER Results for a Share

```bash
curl -s "$NEO_URL/ner/shares/{share_id}/results?page=1&page_size=50" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Paginated results across all files in a share. Use `entity_type` to filter:

```bash
curl -s "$NEO_URL/ner/shares/{share_id}/results?entity_type=person" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Global NER Statistics

```bash
curl -s "$NEO_URL/ner/stats" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Returns `total_entities`, `total_files_processed`, and a breakdown by `entity_types`.

### Per-Share NER Statistics

```bash
curl -s "$NEO_URL/ner/shares/{share_id}/stats" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Search Entities

Search for entities by value across all shares or within a specific share.

```bash
# Search globally
curl -s "$NEO_URL/ner/entities/search?q=NetApp" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Filter by entity type and share
curl -s "$NEO_URL/ner/entities/search?q=NetApp&entity_type=organization&share_id={share_id}" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Aggregate Entities

Get aggregated counts of entity values, useful for dashboards and analytics.

```bash
# All entities
curl -s "$NEO_URL/ner/entities/aggregate" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Filter by type
curl -s "$NEO_URL/ner/entities/aggregate?entity_type=person&share_id={share_id}&limit=20" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Get NER Settings

```bash
curl -s "$NEO_URL/ner/settings" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Returns the current global NER configuration: `enabled`, `model`, `batch_size`, `confidence_threshold`, `device`.

### Update NER Settings

```bash
curl -s -X PUT "$NEO_URL/ner/settings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confidence_threshold": 0.8,
    "device": "cuda"
  }' | jq .
```

Valid `device` values: `auto`, `cuda`, `cpu`. When the device is changed, the API forwards the change to the NER service so the model is moved immediately.

### Trigger Reanalysis

Queue all files in a share for NER reprocessing. By default, only files without existing results are processed. Pass `force=true` to reanalyze everything.

```bash
# Analyze files that are missing NER results
curl -s -X POST "$NEO_URL/ner/shares/{share_id}/reanalyze" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Force reanalysis of all files
curl -s -X POST "$NEO_URL/ner/shares/{share_id}/reanalyze?force=true" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Delete NER Results

```bash
# Delete results for a single file
curl -s -X DELETE "$NEO_URL/ner/files/{file_id}" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Delete all results for a share
curl -s -X DELETE "$NEO_URL/ner/shares/{share_id}/results" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

### Check Pending Files

```bash
curl -s "$NEO_URL/ner/pending?share_id={share_id}&limit=50" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

## GPU Acceleration

The NER service supports GPU acceleration through NVIDIA CUDA and AMD ROCm. GPU variants are built as separate container images (`netapp-neo-ner-cuda` and `netapp-neo-ner-rocm`).

### Device Selection

Set `NER_DEVICE=auto` (the default) to let the engine detect available hardware. It checks for CUDA availability via PyTorch and falls back to CPU if no GPU is found.

### Text Chunking

GLiNER2 is based on DeBERTa-v3-base with a 2048-token context window. For documents longer than the context window, the engine splits text into chunks of up to `NER_MAX_TEXT_LENGTH` characters with `NER_CHUNK_OVERLAP` characters of overlap between adjacent chunks. Entity spans detected across chunk boundaries are deduplicated in post-processing.

### Adaptive Batch Sizing

On GPU, the engine probes available VRAM at startup and computes an initial batch size. During inference:

- Successful batches gradually increase the batch size up to `NER_MAX_BATCH_SIZE`.
- An OOM error halves the batch size and retries.
- After `NER_MAX_CONSECUTIVE_OOMS` consecutive OOM errors, the engine falls back to CPU automatically.
- After `NER_CUDA_RETRY_COOLDOWN` successful CPU inferences, the engine attempts to move back to CUDA (up to `NER_MAX_CUDA_RETRIES` times).

### VRAM Requirements

The GLiNER2 base model requires approximately 500 MB of VRAM. Each inference chunk uses an estimated `NER_ESTIMATED_MB_PER_CHUNK` MB (default 1500 MB) for activations and gradients. A GPU with 4 GB of VRAM can comfortably run batch size 1--2; 8 GB or more is recommended for larger batch sizes.

## Troubleshooting

### Model Download Fails on First Startup

The NER service downloads the GLiNER2 model from Hugging Face on first launch. If the container has no internet access, pre-download the model and mount it into the container:

```bash
# On a machine with internet access
python3 -c "from gliner2 import GLiNER2; GLiNER2.from_pretrained('fastino/gliner2-base-v1')"

# The model is cached in ~/.cache/huggingface/hub/
# Mount that directory into the container
docker run -v ~/.cache/huggingface:/root/.cache/huggingface ...
```

Alternatively, set `NER_MODEL_NAME` to a local path where the model weights are mounted.

### CUDA Out-of-Memory (OOM) Errors

Symptoms: log messages containing `CUDA out of memory` or `RuntimeError: CUDA error`.

Actions:
- Reduce `NER_CUDA_MAX_TEXT_LENGTH` to send smaller chunks (try `4000`).
- Reduce `NER_MAX_BATCH_SIZE` to `1`.
- Increase `NER_MAX_CONSECUTIVE_OOMS` if you want the engine to tolerate more OOMs before falling back.
- If the GPU has limited VRAM (less than 4 GB), set `NER_DEVICE=cpu` to avoid OOM entirely.

The engine automatically falls back to CPU after repeated OOMs and will attempt to return to CUDA after a cooldown period.

### Tokenizer Deadlock

The Hugging Face `tokenizers` library uses Rust-based parallelism that can deadlock when called from multiple Python threads inside a forked process. Symptoms: the NER service hangs during inference with no log output.

Workaround: Set the environment variable `TOKENIZERS_PARALLELISM=false` on the NER container. This disables tokenizer-level parallelism and prevents the deadlock. The Neo container images set this by default.

### NER Results Are Empty

Check that:
1. The share has `enable_ner_analysis: true` in its rules.
2. The file has completed text extraction (status = `completed`).
3. The confidence threshold is not set too high -- try lowering `ner_confidence_threshold` to `0.5` temporarily.
4. The NER service is running and reachable from the worker service (check `GET /ner/status`).

### Reprocessing After Schema Change

If you change a share's NER schema or entity types, existing results are not automatically updated. Use the reanalyze endpoint with `force=true` to reprocess all files with the new configuration:

```bash
curl -s -X POST "$NEO_URL/ner/shares/{share_id}/reanalyze?force=true" \
  -H "Authorization: Bearer $TOKEN"
```
