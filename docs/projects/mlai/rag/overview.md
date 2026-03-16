# RAG Projects

This folder groups together NetApp's Retrieval-Augmented Generation (RAG) project patterns under a single location:

- `document-rag`
- `graph-rag`
- `hybrid-rag-bm25`
- `hybrid-rag-graph`

These four projects are related, but they are **not interchangeable**. Each one uses a different grounding model and retrieval strategy, which changes how the system behaves in areas like explainability, governance, semantic recall, and operational complexity.

## At a Glance

| Project | Primary Grounding Model | Supporting Retrieval | Best Fit | Main Tradeoff |
|---|---|---|---|---|
| `document-rag` | Documents + BM25 lexical search | Optional entity enrichment / vectors as augmentation | Deterministic document retrieval with strong auditability | Less semantic flexibility than hybrid approaches |
| `graph-rag` | Knowledge graph (nodes + relationships) | Graph traversals across entities and concepts | Multi-hop reasoning, lineage, and explainable fact paths | Higher modeling and operational complexity |
| `hybrid-rag-bm25` | BM25 lexical grounding | Vector search for semantic expansion | Balanced precision + recall without graph overhead | More complex than pure document RAG |
| `hybrid-rag-graph` | Knowledge graph for truth grounding | Vector search for contextual detail | Fact-traceable retrieval with richer semantic context | Highest implementation and operational complexity |

## How These Projects Differ

### 1. `document-rag`

**What it is**

`document-rag` is the most document-centric and deterministic option of the four. It treats retrieval as an **auditable search problem**, centered on **BM25 lexical search** over documents and explicit fields, with entity extraction used to enrich the retrieval pipeline. Its emphasis is explainability, reproducibility, and governance-ready behavior. citeturn468422view0

**How it works**

- Uses **BM25 lexical search** as the primary retrieval mechanism.
- Grounds answers in retrieved documents and explicit terms rather than semantic similarity alone.
- May use vectors as augmentation, but **not as the authoritative retrieval layer**. citeturn468422view0

**Use this when**

- You need highly deterministic retrieval behavior.
- You want to explain exactly **why** a document matched.
- You care about audit trails, compliance, and stable reproducibility.
- You do not need graph traversal or heavy semantic expansion.

**Strengths**

- Strong explainability.
- Repeatable results over the same corpus.
- Clear governance boundaries around documents and metadata. citeturn468422view0

**Tradeoff**

Compared with the hybrid variants, `document-rag` gives up some semantic flexibility in exchange for tighter control and simpler reasoning about retrieval.

### 2. `graph-rag`

**What it is**

`graph-rag` is the most explicitly relational option. Instead of grounding answers only in retrieved documents or chunks, it uses a **knowledge graph** made of nodes and relationships. That makes it well suited for scenarios where the system must trace facts across entities, concepts, and linked evidence. citeturn468422view1

**How it works**

- Stores knowledge as **entities, nodes, and relationships**.
- Retrieves information through **graph traversals** rather than only keyword or semantic similarity search.
- Focuses on explicit provenance, multi-hop reasoning, and readable query paths. citeturn468422view1

**Use this when**

- You need **multi-step reasoning** across related entities.
- You want graph-based provenance and fact lineage.
- You need explainability that shows **how facts connect**, not only which documents matched.
- Your domain has meaningful entity relationships worth modeling explicitly.

**Strengths**

- Excellent fact traceability.
- Natural support for multi-hop reasoning.
- Strong governance and lineage through graph structure. citeturn468422view1

**Tradeoff**

`graph-rag` usually requires more data modeling, ontology discipline, and operational care than document-centric retrieval. It pays off when relationships matter; otherwise, it can be more machinery than the problem deserves.

### 3. `hybrid-rag-bm25`

**What it is**

`hybrid-rag-bm25` combines **BM25 lexical search** with **vector retrieval**. The architectural idea is clear: let BM25 provide deterministic, explainable grounding, then use vectors to broaden recall for paraphrases, related phrasing, and semantically similar content. The repo positions BM25 as the anchor and vectors as support. citeturn468422view2

**How it works**

- Uses **BM25 first** for lexical grounding.
- Uses **vector embeddings** to extend semantic coverage.
- Keeps retrieval explainable because lexical evidence remains visible and auditable. citeturn468422view2

**Use this when**

- You want better recall than pure BM25 can provide.
- You still need deterministic grounding and explainability.
- You want many of the governance benefits of advanced RAG without introducing graph infrastructure.
- You need a practical middle ground between classic search and semantic retrieval.

**Strengths**

- Strong balance of precision and recall.
- Better semantic coverage than `document-rag`.
- Lower overhead than graph-based architectures. citeturn468422view2

**Tradeoff**

This project is more operationally complex than pure document RAG, but it remains materially simpler than graph-based systems. Think of it as the “grown-up default” for teams that want semantic range without surrendering control.

### 4. `hybrid-rag-graph`

**What it is**

`hybrid-rag-graph` combines **graph-based truth grounding** with **vector-based semantic context**. It extracts entities and relationships from source material into a knowledge graph, while also storing chunk embeddings for narrative detail and semantic expansion. The graph carries the truth model; vectors add supporting context. citeturn468422view3

**How it works**

- Builds a **Knowledge Graph** from extracted entities and triplets.
- Uses the graph for explicit truth grounding and provenance.
- Uses **vector search** to retrieve surrounding detail, nuance, and semantically related context. citeturn468422view3

**Use this when**

- You need graph-level explainability **and** semantic context retrieval.
- You want fact grounding constrained by explicit relationships.
- You need richer answers than a graph alone might provide.
- Your environment requires strong governance, provenance, and operational controls.

**Strengths**

- Strongest blend of fact traceability and contextual completeness.
- Reduced semantic drift compared with vector-first pipelines.
- Best fit for high-governance, high-explainability RAG systems. citeturn468422view3

**Tradeoff**

This is the most sophisticated option in the set. It also comes with the most moving parts: graph modeling, vector infrastructure, memory tiering, operational governance, and promotion workflows. Great when you need it. Overkill when you do not.

## Choosing the Right Project

### Choose `document-rag` if:

- You want the most deterministic and document-auditable path.
- You care more about reproducibility and compliance than semantic breadth.
- Your corpus is well-structured enough for lexical retrieval to carry most of the workload.

### Choose `graph-rag` if:

- Your domain depends on explicit relationships between entities.
- You need multi-hop reasoning and graph-path explainability.
- You want retrieval grounded in connected facts rather than only documents or chunks.

### Choose `hybrid-rag-bm25` if:

- You want a strong production default for enterprise RAG.
- You need BM25 precision plus vector recall.
- You want governance and explainability without graph database overhead.

### Choose `hybrid-rag-graph` if:

- You need the strongest explainability and provenance model in this folder.
- Your system must combine explicit truth grounding with semantic context.
- You are building for environments where governance, traceability, and factual lineage are core requirements.

## Recommended Mental Model

A useful way to think about these projects is as a progression:

1. **`document-rag`**: retrieve from documents with deterministic lexical grounding.
2. **`graph-rag`**: retrieve from explicit relationships and connected facts.
3. **`hybrid-rag-bm25`**: keep lexical truth grounding, then add semantic recall.
4. **`hybrid-rag-graph`**: keep graph truth grounding, then add semantic recall.

That means the real design question is not “Which RAG project is best?”

It is:

- Do you want grounding centered on **documents** or **relationships**?
- Do you need **semantic expansion** or not?
- How much **governance, explainability, and operational complexity** are you prepared to carry?

That, as usual, is where architecture stops being marketing and starts being engineering.

## Source Projects

These summaries are based on the current project READMEs in the Innovation Labs repository:

- `document-rag` citeturn468422view0
- `graph-rag` citeturn468422view1
- `hybrid-rag-bm25` citeturn468422view2
- `hybrid-rag-graph` citeturn468422view3
