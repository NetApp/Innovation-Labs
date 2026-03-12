# Hybrid RAG with NetApp

**Graph + Vector Retrieval with Governance Built In**

## 1. Introduction

This project highlights a **Hybrid Retrieval-Augmented Generation (Hybrid RAG)** architecture developed and validated by **NetApp**.

The design combines **GraphRAG** for explicit truth grounding with **vector embeddings** for semantic context. In practice, the system extracts **entities and relationships (triplets)** from source documents into a **Knowledge Graph**, while also storing chunk embeddings for semantic retrieval. The result is a retrieval architecture that balances **governance, explainability, and contextual completeness** without relying on opaque vector similarity alone.

This page provides a NetApp-focused overview of the architecture and its enterprise implications.
The full open source reference implementation lives here:
👉 **[https://github.com/NetApp/hybrid-rag-graph-with-ai-governance](https://github.com/NetApp/hybrid-rag-graph-with-ai-governance)**

## 2. Why Hybrid RAG

Pure vector RAG is good at "semantic vibes" but weak at answering hard questions like:

* Why did this result match?
* Which facts actually grounded the answer?
* Can we reproduce this result next week?
* Can we defend it to auditors?

Graph-based Hybrid RAG addresses those gaps by **grounding retrieval in a Knowledge Graph first**, then using vectors as **supporting semantic context**, not the source of truth.

![Hybrid RAG with Graph Truth Grounding](https://raw.githubusercontent.com/NetApp/hybrid-rag-graph-with-ai-governance/main/images/rag-hybrid-graph.png)

Key reasons Graph-based Hybrid RAG works:

* **Deterministic fact traceability**: facts are grounded as explicit entities and relationships rather than inferred only from similarity scores.

* **Audit-ready provenance**: triplets, nodes, and edges can carry source lineage and metadata so evidence remains inspectable.

* **Reduced semantic drift**: the graph constrains grounding to extracted relationships, while vectors add supporting narrative context.

* **Operational explainability**: retrieval can be shown as a subgraph of entities, edges, chunks, and metadata rather than as opaque ANN rankings.

* **Contextual completeness**: vectors still help retrieve surrounding detail and nuance so answers are not limited to terse graph facts.

This architecture also uses explicit **HOT** and **Long-Term (LT)** memory tiers. New or unverified facts can live in HOT memory first, while promotion into LT memory is treated as a controlled event driven by reinforcement or trusted human validation.

## 3. How NetApp Enhances This Architecture

NetApp extends Graph-based Hybrid RAG with an **enterprise storage overlay** that makes the design operational at scale.

Key NetApp contributions include:

* **Dual-tier graph truth store**

  * **Long-Term (LT)**: authoritative Neo4j graph store for curated document, chunk, and entity evidence
  * **HOT**: low-latency Neo4j working set for new, user-specific, or unvetted graph evidence
  * **Vector context store**: OpenSearch for semantic chunk retrieval alongside graph grounding

* **Long-term durability and cost optimization**

  * **FabricPool / auto-tiering** helps move colder Neo4j and OpenSearch data to lower-cost tiers while keeping retrieval transparent
  * **NetApp XCP** supports large-scale ingestion from legacy HDFS/NFS sources with integrity verification

* **Low-latency HOT operations**

  * **FlexCache** keeps the active HOT graph working set close to inference compute
  * **Storage QoS** protects HOT query/update paths from noisy-neighbor ingest and rebuild workloads
  * **FlexClone** enables safe rebuild, migration, and test workflows without destabilizing production HOT memory

* **Enterprise resilience and compliance**

  * **MetroCluster** protects Long-Term graph and vector stores with synchronous replication and zero-RPO posture
  * **SnapCenter** captures application-consistent snapshots of Neo4j and OpenSearch state
  * **SnapLock** adds WORM protection for environments that require immutable evidence and audit trails

* **Safe experimentation**

  * FlexClone allows instant, space-efficient copies of indices for testing new analyzers or embedding models without touching production

NetApp's role is not to change how Graph + Vector Hybrid RAG works logically, but to **make it reliable, governable, compliant, and operable in real enterprise environments**.

## 4. Visit the GitHub Project for More Details

This page is intentionally concise.

For full technical details, code, and deployment guidance, visit the open source project:

👉 **[https://github.com/NetApp/hybrid-rag-graph-with-ai-governance](https://github.com/NetApp/hybrid-rag-graph-with-ai-governance)**

There you'll find:

* A complete **Graph + Vector Hybrid RAG** reference implementation
* Separate **community** and **enterprise** deployment paths
* Supporting guides for **Hybrid Graph Search for Better AI Governance**, the **Community Version**, and the **Enterprise Version**
* Detailed explanations of **truth grounding**, **vector support**, and **HOT/LT operational workflows**

If you're building RAG systems that need to be **accurate, explainable, and defensible**, that repository is the place to start.
