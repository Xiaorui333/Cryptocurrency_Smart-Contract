# Blockchain & AI Full-Stack Portfolio

## Abstract

This repository documents a progressive, hands-on journey through blockchain engineering and AI integration, spanning cryptographic primitives, Bitcoin node operations, Ethereum smart contract development, decentralized finance (DeFi) protocol implementation, large language model (LLM) serving, and natural language interfaces for on-chain data.

The work follows a deliberate **bottom-up** learning arc: starting from the raw mathematics of hashing and digital signatures, ascending through real-world Bitcoin infrastructure, bridging into Ethereum smart contracts and DeFi protocols, and culminating in a full-stack application that lets users interact with Uniswap V2 pools using plain English — powered by self-hosted LLMs.

### Workstream Overview

```
Step 1  Cryptographic Foundations
        ├── SHA-256 Puzzle Solver (Java)
        └── ECDSA Digital Signatures (Rust)

Step 2  Bitcoin Infrastructure
        ├── Bitcoin Core Node (Docker + Modal)
        ├── Chainstack RPC Data Sync
        └── SQLite Blockchain Database (~12 GB)

Step 3  AI-Powered Blockchain Analytics
        ├── Text-to-SQL v1 — Fixed Schema, GPT-3.5
        └── Text-to-SQL v2 — Dynamic Schema Extraction + Live Query Execution

Step 4  Cloud-Native LLM Serving
        ├── Modal Serverless Computing
        └── vLLM + LLaMA 3.1-8B Inference Server

Step 5  Ethereum & DeFi Smart Contracts
        ├── Scaffold-ETH 2 — Hardhat + Next.js
        └── Uniswap V2 Core & Periphery (Foundry)

Step 6  Full-Stack DeFi Application
        └── Uniswap V2 Scaffold — Swap, Liquidity, Pool Analytics,
            Natural Language Interface, and Task Evaluation
```

---

## Projects

### 1. SHA-256 Puzzle Solver

**Directory:** `SHA256/`

**Description:**
A Java program that brute-forces a cryptographic puzzle: find an input `x` such that `SHA256(x || ID)` contains the byte `0x2F`. The solver generates random 32-byte inputs, concatenates them with a fixed identity hash, and checks the digest until it finds a valid solution.

**Skillsets:**
- Java — `MessageDigest`, `ByteBuffer`, byte-level manipulation
- Cryptographic hashing (SHA-256)
- Proof-of-work style computation

**Impact:**
Builds intuition for how mining puzzles work. Demonstrates the one-way nature of hash functions and the computational cost of finding specific hash patterns — the same principle underpinning Bitcoin's Proof of Work.

---

### 2. ECDSA Digital Signatures

**Directory:** `digital_signatures/`

**Description:**
A Rust program that generates an ECDSA P-256 key pair, signs the message `"hello, world"`, and verifies the signature using the public key. Built with the `ring` cryptography library.

**Skillsets:**
- Rust — ownership model, error handling with `Result`
- Elliptic Curve Cryptography (ECDSA P-256 SHA-256)
- PKCS#8 key serialization
- The `ring` cryptographic library

**Impact:**
Demonstrates the end-to-end digital signature workflow used in every blockchain transaction: key generation, signing, and verification. Solidifies understanding of public-key infrastructure at the code level.

---

### 3. Blockchain Explorer Docker

**Directory:** `blockchain_explorer_docker/`

**Description:**
A minimal Docker container (Python 3.9-slim) serving as a starting point for containerized blockchain tooling.

**Skillsets:**
- Docker image authoring (`Dockerfile`)
- Container basics and image layering

**Impact:**
Entry point into containerization, setting the stage for more complex Docker and Docker Compose deployments used throughout the later projects.

---

### 4. Bitcoin Data Ingestion

**Directory:** `bitcoin_data_ingestion/`

**Description:**
Builds Bitcoin Core v24.0 from source inside a Docker container, runs a full node with JSON-RPC enabled, and persists blockchain data on a Modal Volume for cloud-native operation. Includes both `docker-compose.yml` for local runs and `modal_app.py` for serverless deployment.

**Skillsets:**
- Docker — multi-step builds, C/C++ toolchain, port exposure
- Docker Compose — service orchestration, volume mounts
- Modal — serverless GPU/CPU functions, persistent volumes, long-running tasks
- Bitcoin Core — `bitcoind`, RPC configuration, peer-to-peer networking

**Impact:**
Enables direct interaction with the Bitcoin network. Running a full node is the most trustless way to verify transactions — this setup provides the RPC backbone for all downstream data pipelines and analytics.

---

### 5. Bitcoin Blockchain Sync (Chainstack RPC → SQLite)

**Directory:** `Text_to_SQL_2/bitcoin_sync.py`, `homework_submission/homework_3_bitcoin_sync/`

**Description:**
A continuous sync daemon that fetches Bitcoin block and transaction data from a Chainstack-hosted node via JSON-RPC and stores it in a normalized SQLite database. The schema covers blocks, transactions, inputs (vin), outputs (vout), script public keys, and addresses. The sync loop polls for new blocks every 5 minutes.

**Skillsets:**
- Python — `requests`, `sqlite3`, JSON-RPC protocol
- Relational database design — normalized schema with 6 tables
- Chainstack — managed Bitcoin node, RPC authentication
- ETL pipeline — extract from RPC, transform JSON, load into SQLite
- Error handling and retry logic

**Impact:**
Produces a ~12 GB queryable Bitcoin blockchain database — the foundation for the Text-to-SQL projects. Transforms raw blockchain data into a structured, analyst-friendly format that supports arbitrary SQL queries over the entire transaction history.

---

### 6. Text-to-SQL v1 — AI Block Explorer

**Directory:** `Text-to-SQL/`

**Description:**
An interactive CLI that accepts natural language questions about blockchain data and generates SQL queries using OpenAI's GPT-3.5-turbo. Uses a hardcoded `blocks` table schema as context.

**Skillsets:**
- OpenAI Chat Completions API
- Prompt engineering — schema-augmented system prompts
- Python CLI development

**Impact:**
Proof of concept showing that LLMs can bridge the gap between non-technical users and structured blockchain data. Eliminates the need to write SQL manually, making on-chain analytics accessible to a wider audience.

---

### 7. Text-to-SQL v2 — Dynamic Schema + Live Execution

**Directory:** `Text_to_SQL_2/text_to_sql.py`, `homework_submission/homework_4_text-to-SQL/`

**Description:**
An advanced version that dynamically extracts the database schema from any SQLite file, runs an integrity check, constructs a schema-aware prompt, sends it to GPT-3.5-turbo, cleans the generated SQL (strips markdown fences), executes it against the live database, and returns the results. Includes structured logging.

**Skillsets:**
- Dynamic schema extraction (`sqlite_master`)
- Database integrity validation (`PRAGMA integrity_check`)
- LLM output post-processing (regex-based SQL extraction)
- End-to-end query pipeline: NL → SQL → execution → results
- Logging and error handling

**Impact:**
A production-grade pipeline that can query the 12 GB Bitcoin database using plain English. Users ask questions like *"What is the total number of transactions in the last 1000 blocks?"* and receive real query results — no SQL knowledge required.

---

### 8. Modal Serverless Computing

**Directory:** `Modal/`

**Description:**
A collection of Modal examples demonstrating serverless Python execution in the cloud: a Hello World parallel mapper, a FastAPI web endpoint with authentication and lifecycle management, and a web scraper that extracts links from URLs.

**Skillsets:**
- Modal — `@app.function`, `@modal.web_endpoint`, `@modal.asgi_app`, `modal.Cls`
- Serverless architecture — auto-scaling, container lifecycle
- FastAPI — ASGI web framework, query params, request bodies, Swagger docs
- Parallel computing — `f.map()` across hundreds of containers

**Impact:**
Establishes proficiency with Modal's serverless platform, which is used as the deployment substrate for the Bitcoin node, vLLM inference server, and other compute-intensive workloads throughout the portfolio.

---

### 9. vLLM + LLaMA 3.1-8B Inference Server

**Directory:** `vllm_serving/`

**Description:**
Deploys Meta's LLaMA 3.1-8B-Instruct (4-bit quantized by Neural Magic) as an OpenAI-compatible API server using vLLM on Modal with H100 GPUs. Includes model weight downloading via Hugging Face Hub, CORS configuration, bearer token authentication, and support for 1000 concurrent inputs.

**Skillsets:**
- vLLM — `AsyncLLMEngine`, OpenAI-compatible serving, tensor parallelism
- Modal — GPU functions (H100), volumes, `@modal.asgi_app`
- Model quantization — W4A16 "Machete" weight layout
- Hugging Face Hub — `snapshot_download`, model versioning
- FastAPI — middleware, authentication, CORS
- LLM inference optimization — `gpu_memory_utilization`, `max_model_len`, CUDA graph capture

**Impact:**
Provides a self-hosted, cost-effective alternative to commercial LLM APIs. The OpenAI-compatible interface means any application expecting the OpenAI API can seamlessly switch to this self-hosted endpoint — enabling private, low-latency inference for the Uniswap natural language interface.

---

### 10. Scaffold-ETH 2 — Ethereum dApp Framework

**Directory:** `scaffold-eth-2/`

**Description:**
A full-stack Ethereum development environment built on Scaffold-ETH 2, featuring Hardhat for smart contract compilation/deployment and a Next.js frontend with a block explorer, debug UI, and Uniswap V2 pool management interface (swap, add/remove liquidity, pool analytics, and swap price distribution charts).

**Skillsets:**
- Solidity — smart contract development (`YourContract.sol`)
- Hardhat — compilation, deployment, local blockchain
- Next.js + React — server components, app router
- wagmi + viem — type-safe Ethereum interactions
- RainbowKit — wallet connection UI
- Block explorer — transaction/address inspection

**Impact:**
Full development environment for rapid Ethereum prototyping. The integrated block explorer and debug UI accelerate the smart contract development cycle, while the pool management pages provide a user-facing interface for DeFi operations.

---

### 11. Uniswap V2 — Foundry Implementation

**Directory:** `UniswapV2_Foundry/`

**Description:**
A complete Solidity re-implementation of the Uniswap V2 protocol using the Foundry toolchain. Includes the core contracts (Factory, Pair, ERC-20 LP token) and periphery contracts (Router02 with all swap and liquidity variants). Accompanied by comprehensive Foundry tests covering factory operations, pair mechanics, router interactions, liquidity provision, swaps, and ERC-20 permit signatures.

**Skillsets:**
- Solidity ^0.8.20 — AMM mechanics, constant-product formula, flash swaps
- Foundry — `forge build`, `forge test`, deployment scripts, Sepolia RPC
- DeFi protocol design — Factory/Pair pattern, fee calculation, LP token math
- Fixed-point arithmetic — UQ112x112 library
- Testing — full coverage tests, fuzz-friendly structure
- CREATE2 — deterministic pair deployment

**Impact:**
Deep, line-by-line understanding of the most influential DeFi protocol. Implementing Uniswap V2 from scratch builds fluency in AMM design, liquidity pool math, and the security patterns that protect billions of dollars in on-chain value.

---

### 12. Uniswap V2 Scaffold — Full-Stack DeFi with Natural Language Interface

**Directory:** `uniswap-scaffold/`

**Description:**
The capstone project: a full-stack DeFi application that combines Uniswap V2 smart contracts (deployed via Foundry) with a Next.js frontend featuring four major capabilities:

1. **Smart Contract Interactions** — Approve tokens, add/remove liquidity, and swap tokens through a polished UI
2. **Pool Analytics** — Visualize the constant-product curve (x * y = k), track reserve movements, and analyze swap price distributions
3. **Natural Language Interface** — Users type instructions like *"Swap 0.1 ETH for USDC"* and the system translates them into contract calls using OpenAI or a custom LLM
4. **Task Evaluation** — Compare LLM responses, generate and execute SQL queries, and render relevant contract operation interfaces

Deployed on Vercel with Tenderly Sepolia testnet integration.

**Skillsets:**
- Solidity — Uniswap V2 core + periphery contracts
- Foundry — build, test, deploy
- Next.js + TypeScript — app router, server components
- React — component architecture (PoolSelector, AddLiquidity, RemoveLiquidity, Swap, PoolAnalytics, SwapPriceDistribution, TaskEvaluation)
- wagmi + viem — type-safe contract reads/writes
- RainbowKit — wallet connection
- LLM integration — OpenAI API + custom LLM endpoints
- NLP-to-transaction pipeline — natural language → intent parsing → contract call
- Data visualization — reserves curve, price distribution charts
- Vercel deployment — CI/CD, environment variables
- Tenderly — virtual testnet, forked Sepolia

**Impact:**
Bridges the gap between DeFi and everyday users. By wrapping complex smart contract interactions behind a natural language interface, this application demonstrates a future where interacting with DeFi protocols is as easy as sending a text message. The pool analytics provide institutional-grade visibility into AMM mechanics, while the task evaluation system enables systematic benchmarking of LLM accuracy for DeFi operations.

---

## Technology Stack Summary

| Category | Technologies |
|---|---|
| **Languages** | Python, JavaScript/TypeScript, Solidity, Java, Rust |
| **Blockchain — Bitcoin** | Bitcoin Core v24.0, JSON-RPC, Chainstack |
| **Blockchain — Ethereum** | Hardhat, Foundry (forge/anvil/cast), Sepolia, Tenderly |
| **Smart Contracts** | Uniswap V2 (Factory, Pair, Router02), ERC-20, CREATE2 |
| **Frontend** | Next.js, React, RainbowKit, wagmi, viem |
| **AI / LLM** | OpenAI GPT-3.5-turbo, vLLM, LLaMA 3.1-8B (quantized) |
| **Infrastructure** | Docker, Docker Compose, Modal (serverless), Vercel |
| **Databases** | SQLite (12 GB blockchain DB) |
| **Cryptography** | SHA-256, ECDSA P-256, ring (Rust) |

---

## Repository Structure

```
INFO7500/
├── SHA256/                        # SHA-256 puzzle solver (Java)
├── digital_signatures/            # ECDSA P-256 signing & verification (Rust)
├── blockchain_explorer_docker/    # Docker basics
├── bitcoin_data_ingestion/        # Bitcoin Core node (Docker + Modal)
├── Text-to-SQL/                   # Text-to-SQL v1 — fixed schema
├── Text_to_SQL_2/                 # Text-to-SQL v2 — dynamic schema + 12 GB DB
├── Modal/                         # Modal serverless examples
├── vllm_serving/                  # vLLM + LLaMA inference server
├── scaffold-eth-2/                # Scaffold-ETH 2 (Hardhat + Next.js)
├── UniswapV2_Foundry/             # Uniswap V2 Foundry implementation + tests
├── uniswap-scaffold/              # Full-stack Uniswap V2 + NL interface (capstone)
└── homework_submission/           # Course homework snapshots
    ├── homework_2/                #   HW2: Text-to-SQL
    ├── homework_3_bitcoin_sync/   #   HW3: Bitcoin sync (Docker + Modal)
    └── homework_4_text-to-SQL/    #   HW4: Text-to-SQL with Bitcoin DB
```
