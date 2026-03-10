# Search

This guide covers the search capabilities in NetApp Project Neo, including full-text search across file content, named entity search, entity aggregation, and AI assistant integration via MCP.

---

## Table of Contents

1. [Full-Text Search](#full-text-search)
2. [Entity Search](#entity-search)
3. [Entity Aggregation](#entity-aggregation)
4. [File Search via MCP](#file-search-via-mcp)
5. [Search Tips](#search-tips)

---

## Full-Text Search

**Endpoint:** `POST /api/v1/search`

Full-text search queries the extracted content of all indexed files across one or more shares. The search engine uses database-native full-text indexing for high performance, returning ranked results with relevance scoring and content snippets.

### Request Body

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `query` | string | Yes | -- | Search query (1-500 characters) |
| `share_ids` | string[] | No | all shares | Restrict results to specific shares |
| `file_types` | string[] | No | all types | Filter by file extension (e.g., `pdf`, `docx`, `txt`) |
| `modified_after` | datetime | No | -- | Only files modified after this date |
| `modified_before` | datetime | No | -- | Only files modified before this date |
| `page` | integer | No | 1 | Page number (starting from 1) |
| `page_size` | integer | No | 100 | Results per page (1-1000) |
| `sort_by` | string | No | `relevance` | Sort by: `relevance`, `modified_time`, `filename`, `size` |
| `sort_order` | string | No | `desc` | Sort order: `asc` or `desc` |
| `search_mode` | string | No | `natural` | MySQL only: `natural` (OR-based) or `boolean` (AND-based) |

### Example: Basic Search

```bash
curl -X POST http://localhost:8000/api/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "quarterly revenue report"
  }'
```

### Example: Filtered Search

```bash
curl -X POST http://localhost:8000/api/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "security audit findings",
    "share_ids": ["share-uuid-1", "share-uuid-2"],
    "file_types": ["pdf", "docx"],
    "modified_after": "2025-01-01T00:00:00Z",
    "page": 1,
    "page_size": 25,
    "sort_by": "relevance"
  }'
```

### Response

```json
{
  "results": [
    {
      "id": "file-uuid",
      "share_id": "share-uuid",
      "filename": "Q4-Security-Audit.pdf",
      "file_path": "/reports/2025/Q4-Security-Audit.pdf",
      "unc_path": "\\\\server\\share\\reports\\2025\\Q4-Security-Audit.pdf",
      "size": 245760,
      "modified_time": "2025-11-15T09:30:00Z",
      "file_type": "pdf",
      "indexed_at": "2025-12-01T14:22:00Z",
      "relevance_score": 0.847,
      "snippet": "...the <b>security</b> <b>audit</b> <b>findings</b> indicate three critical...",
      "share_name": "/mnt/reports",
      "resolved_principals": ["user@company.com"]
    }
  ],
  "total_count": 42,
  "page": 1,
  "page_size": 25,
  "total_pages": 2,
  "has_next": true,
  "has_previous": false,
  "query": "security audit findings",
  "search_time_ms": 23,
  "database_type": "postgresql"
}
```

### How It Works

#### PostgreSQL (Recommended)

Neo uses PostgreSQL's GIN-indexed `search_vector` column on the `file_metadata` table for full-text search. This provides:

- **GIN Index**: A pre-built Generalized Inverted Index over tsvector data, enabling sub-millisecond lookups even on millions of rows.
- **Phrase Matching**: Use double-quoted phrases to match exact word sequences.
- **Prefix Wildcards**: Partial word matching via `websearch_to_tsquery`.
- **Boolean Operators**: `AND`, `OR`, `NOT` logic supported in natural language queries.
- **Relevance Ranking**: Results are scored using `ts_rank_cd` (cover density ranking) which considers proximity of matching terms.
- **Content Snippets**: `ts_headline` generates contextual snippets around matching terms with HTML `<b>` highlighting, returning approximately 25-50 words of context per match.
- **Chunk Deduplication**: Large files are split into chunks for extraction. The search automatically deduplicates chunks by `parent_file_id`, returning only the highest-scoring snippet per original file.
- **Performance**: 20-42x speedup over basic `LIKE` queries, measured on real-world datasets.

#### MySQL

For MySQL deployments, Neo uses `FULLTEXT` indexes with two search modes:

- **Natural Language Mode** (`search_mode: "natural"`): OR-based matching ranked by relevance. Best for general queries.
- **Boolean Mode** (`search_mode: "boolean"`): AND-based matching with operators (`+`, `-`, `*`, `""`). Best for precise queries.

---

## Entity Search

**Endpoint:** `GET /api/v1/ner/entities/search`

Search for files that contain specific named entities (people, organizations, locations, dates, etc.) identified by the NER (Named Entity Recognition) service.

### Query Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `q` | string | Yes | -- | Entity value to search for (case-insensitive substring match) |
| `entity_type` | string | No | all types | Filter by entity type (e.g., `PERSON`, `ORG`, `GPE`, `DATE`) |
| `share_id` | string | No | all shares | Restrict to a specific share |
| `limit` | integer | No | 100 | Maximum results (1-1000) |

### Example: Search for a Person

```bash
curl -X GET "http://localhost:8000/api/v1/ner/entities/search?q=John%20Smith&entity_type=PERSON" \
  -H "Authorization: Bearer $TOKEN"
```

### Example: Cross-Share Entity Correlation

Find all files mentioning a specific organization across all shares:

```bash
curl -X GET "http://localhost:8000/api/v1/ner/entities/search?q=NetApp&entity_type=ORG&limit=500" \
  -H "Authorization: Bearer $TOKEN"
```

### Response

```json
{
  "query": "John Smith",
  "results": [
    {
      "file_id": "file-uuid",
      "filename": "meeting-notes-2025-q4.docx",
      "file_path": "/documents/meetings/meeting-notes-2025-q4.docx",
      "matches": [
        { "type": "PERSON", "value": "John Smith" },
        { "type": "PERSON", "value": "John Smith Jr." }
      ]
    }
  ],
  "count": 1
}
```

---

## Entity Aggregation

**Endpoint:** `GET /api/v1/ner/entities/aggregate`

Get aggregated entity statistics grouped by entity type with counts. Useful for understanding what kinds of entities appear across your file estate.

### Query Parameters

| Parameter | Type | Required | Default | Description |
|---|---|---|---|---|
| `entity_type` | string | No | all types | Filter to a specific entity type |
| `share_id` | string | No | all shares | Restrict to a specific share |
| `limit` | integer | No | 100 | Maximum aggregation entries (1-1000) |

### Example

```bash
curl -X GET "http://localhost:8000/api/v1/ner/entities/aggregate?share_id=share-uuid" \
  -H "Authorization: Bearer $TOKEN"
```

### Response

```json
{
  "aggregates": [
    { "entity_type": "PERSON", "count": 1247 },
    { "entity_type": "ORG", "count": 893 },
    { "entity_type": "GPE", "count": 456 },
    { "entity_type": "DATE", "count": 2341 }
  ],
  "count": 4
}
```

---

## File Search via MCP

When Neo is configured as an MCP (Model Context Protocol) server, AI assistants such as Claude and ChatGPT Enterprise can search your file shares programmatically. Two MCP tools are available:

### `search_files`

Searches file metadata (filenames, paths, types) with optional filtering. Returns file listings that the AI assistant can reference or retrieve content from.

### `full_text_search`

Performs the same full-text content search as the `POST /api/v1/search` endpoint, but through the MCP protocol. Results are ACL-filtered so each user only sees files they have permission to access.

AI assistants use these tools automatically when users ask questions like:

- "Find the Q4 financial reports"
- "Search for documents mentioning the Azure migration"
- "What files were updated last week about compliance?"

See the [MCP User Guide](m-mcp.md) for setup and configuration details.

---

## Search Tips

### Constructing Effective Queries

| Technique | Example Query | Description |
|---|---|---|
| Natural language | `quarterly revenue report` | Matches files containing any of these terms, ranked by relevance |
| Exact phrase | `"annual security audit"` | Matches the exact phrase in sequence |
| Multiple terms | `budget 2025 forecast` | Matches files containing all or some terms (PostgreSQL ranks by match quality) |
| File type filter | Use `file_types: ["pdf"]` | Narrow results to specific document types |
| Date range | Use `modified_after` / `modified_before` | Find recently updated or historical documents |

### Performance Considerations

- **Use `share_ids` when possible**: Filtering by share reduces the search space and improves response time.
- **Use `file_types` for targeted searches**: Restricting to specific file types avoids scanning irrelevant content.
- **Keep `page_size` reasonable**: The default of 100 is suitable for most use cases. Requesting 1000 results per page increases response time and payload size.
- **Sort by relevance for content queries**: Relevance sorting (the default) returns the most pertinent results first. Switch to `modified_time` when looking for recent documents regardless of content match quality.
- **Prefer entity search for structured data**: If you are looking for specific people, organizations, or locations, entity search is more precise than full-text search because it uses NER-extracted structured data rather than raw text matching.
