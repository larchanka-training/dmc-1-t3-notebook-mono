# Project

## 1. Summary

This project is a web-based `JavaScript notebook`.

The product combines text, executable code, outputs, local persistence, backend synchronization, and AI-assisted code generation inside a single notebook document.

The main user experience is a vertical document made of ordered blocks. A user writes notes, writes or generates `JavaScript`, runs code step by step, and sees the results directly in context.

## 2. Product Definition

The product is an offline-capable, block-based `JavaScript notebook` for executable technical documents.

It is designed for:

- writing technical notes
- running `JavaScript` in steps
- exploring APIs and data
- visualizing results
- using AI to generate or refine code inside the notebook workflow

## 3. Product Goals

The product should allow a user to:

- create and edit notebook documents
- mix text and code in one place
- run code block by block
- preserve execution state across blocks
- inspect outputs near the code that produced them
- work locally without constant server availability
- manually sync notebook state with the backend
- use AI to generate or refine code from descriptions

## 4. Core Principles

1. `Notebook first`
The main object is a notebook made of ordered blocks.

2. `JavaScript first`
Version 1 is centered on `JavaScript`.

3. `Block-based model`
The system is modeled around notebook blocks, not around a generic widget platform.

4. `Vertical reading flow`
The main interface is a top-to-bottom notebook document, not a free-form canvas.

5. `Offline first`
Local work must remain possible without backend availability.

6. `Manual sync`
Synchronization is an explicit product feature.

7. `Execution isolation`
User code must run in an isolated environment.

8. `AI inside the workflow`
AI should support block creation and refinement inside the notebook, not act only as a detached chat interface.

9. `Scope discipline`
The product should solve the notebook problem well before expanding into adjacent categories.

## 5. Canonical Concepts

| Term | Meaning |
|---|---|
| `Notebook` | A document made of ordered blocks |
| `Block` | A unit of notebook content such as text or code |
| `Text Block` | A block containing plain text or Markdown |
| `Code Block` | A block containing executable `JavaScript` |
| `Output` | The result of running a block |
| `Execution Session` | The runtime context that preserves variables and state across block executions |
| `Runtime` | The isolated execution environment |
| `Sync` | Explicit synchronization between local state and backend state |
| `AI Request` | A user instruction intended to generate or refine code |

Preferred terminology:

- use `block`, not `widget`, for core notebook units
- use `notebook`, not `page builder`, for the main content model
- use `execution session` when referring to preserved runtime state

## 6. Primary Use Cases

### 6.1 Exploratory Coding

The user writes `JavaScript` in small steps, runs selected blocks, and reuses previous results.

### 6.2 Executable Technical Notes

The user combines explanations, code, and outputs in one technical document.

### 6.3 API and Data Exploration

The user fetches data, transforms it, and visualizes the result as text, tables, or charts.

### 6.4 Lightweight Internal Dashboards

The user builds a notebook that loads data and presents a readable operational view through code.

### 6.5 AI-Assisted Prototyping

The user describes a task, receives generated code, edits it, and executes it inside the notebook.

### 6.6 Education and Onboarding

The user creates materials that combine explanations, examples, and execution results.

## 7. Target Users

Primary users:

- software engineers
- technical leads
- frontend developers
- backend developers
- QA engineers
- technical analysts
- internal tool builders

Secondary users:

- students
- mentors
- JavaScript users working with data
- developers who need executable runbooks

## 8. Version 1 Scope

Version 1 should deliver a strong `JavaScript notebook` core.

The user should be able to:

- sign in
- create notebooks
- browse a notebook list
- open and edit notebooks
- add, edit, delete, and reorder blocks
- work with text blocks
- work with `JavaScript` code blocks
- run a single block
- run all blocks or run from a selected point
- preserve shared execution state inside an `execution session`
- see outputs directly near the executed block
- work with text, table, and chart-like outputs
- save notebooks locally in `IndexedDB`
- continue working offline
- manually sync notebook state with the backend
- export notebook content
- generate code from descriptions using AI
- regenerate code after editing the request

## 9. Out of Scope for Version 1

The following capabilities are intentionally outside the first version:

- real-time collaborative editing
- inline review comments
- Git diff and commit workflows inside the product
- `Python` support
- general multi-language kernel support
- full `TypeScript` execution
- heavy IDE features such as `LSP`, rename refactor, and symbol intelligence
- free-form dashboard canvas
- advanced access models based on `PIN` or per-document passwords
- alerting and notification platform features
- plugin marketplace
- hidden blocks or opaque widgets with concealed implementation
- enterprise-grade data connector platform

## 10. Functional Requirements

### 10.1 Notebook Management

The system must allow users to:

- create notebooks
- open notebooks
- rename notebooks
- delete notebooks
- browse notebook lists
- find notebooks through basic search or filtering

### 10.2 Block Editing

The editor must support:

- adding a block above or below another block
- deleting a block
- moving a block up or down
- editing block content
- collapsing and expanding blocks where useful

Minimum supported block types:

- `Text / Markdown Block`
- `JavaScript Code Block`

### 10.3 Code Execution

The execution model must support:

- running one selected block
- running all blocks
- running from a selected block downward
- preserving shared state across blocks in one `execution session`
- maintaining a clear relationship between a block and its output

### 10.4 Outputs and Visualization

The product must support notebook-friendly outputs.

Priority output forms:

- plain text output
- structured object output
- table output
- chart output

### 10.5 AI-Assisted Workflow

The AI workflow must support:

1. the user writes a description
2. the user requests code generation
3. the system returns code suitable for a new or updated code block
4. the user edits the request if needed
5. the user regenerates and then executes the result

Generated code must remain editable.

### 10.6 Local Storage and Offline Work

The system must:

- persist notebook data in `IndexedDB`
- allow local editing when the backend is unavailable
- allow local execution when the runtime is available
- preserve unsynced work until explicit synchronization

### 10.7 Synchronization

Synchronization must be:

- explicit
- notebook-aware
- robust to temporary offline usage

### 10.8 Authentication and Access

Version 1 must support:

- user authentication
- private notebooks by default

### 10.9 Export

The system should support export in at least one portable format.

Valid directions include:

- structured JSON-based notebook format
- Markdown-oriented export
- another project-specific portable format

## 11. Non-Functional Requirements

### 11.1 Security

The system must:

- execute user code in isolation
- prevent privileged access from notebook code to sensitive resources
- treat generated code as untrusted
- keep control paths separated from user content

### 11.2 Reliability

The system should:

- avoid silent data loss
- preserve local changes when sync is unavailable
- make synchronization state understandable
- degrade gracefully when backend or AI services are unavailable

### 11.3 Performance

The system should:

- open notebooks quickly
- keep editing responsive
- provide clear feedback during execution
- avoid unnecessary full-document recomputation

### 11.4 Maintainability

The architecture should favor:

- clear component boundaries
- predictable data models
- limited hidden coupling
- isolated responsibilities
- testable logic

### 11.5 Reproducibility

Notebook behavior should remain understandable and reproducible through:

- clear execution order
- clear runtime state transitions
- traceable connection between block content and output

## 12. High-Level Architecture

The product should be organized around the following major parts:

| Component | Responsibility |
|---|---|
| `Frontend` | Notebook editor, block rendering, local persistence integration, sync UI, output presentation |
| `Backend` | Authentication, notebook storage, sync API, access control, optional AI broker responsibilities |
| `Database` | Persistent storage for users, notebooks, metadata, and synchronization state |
| `LLM Layer` | Code generation support, browser-side, backend-side, or hybrid |
| `Execution Runtime` | Isolated `JavaScript` execution and session state |
| `Execution Orchestrator` | Execution lifecycle management and coordination with UI/backend |

## 13. Recommended Domain Model

The product should revolve around these entities:

| Entity | Purpose |
|---|---|
| `User` | Account owner |
| `Notebook` | Top-level document |
| `Block` | Ordered notebook unit |
| `BlockContent` | The payload of a block, such as text or code |
| `ExecutionSession` | The boundary of runtime state |
| `BlockOutput` | Output produced by block execution |
| `SyncState` | Local/server synchronization metadata |
| `ExportArtifact` | Portable representation prepared for export |

Modeling guidance:

- model notebook content as structured blocks
- keep durable content separate from execution state where possible
- avoid designing the core model as a generic widget system

## 14. Guidance for Humans and AI Agents

When contributing to this project, assume the following:

1. The canonical product model is `notebook -> ordered blocks -> execution session -> outputs`.
2. Version 1 is `JavaScript-first`.
3. The main UI is a vertical notebook flow.
4. Local persistence and offline support are mandatory.
5. Manual sync is a real product feature.
6. Runtime isolation is a hard requirement.
7. AI must support notebook work, not replace the notebook with a detached chat paradigm.
8. Prefer `block` terminology over `widget` terminology.
9. Prefer the simpler design when it strengthens the notebook core.
10. Avoid adding architecture that only makes sense for out-of-scope features.

When proposing a change, classify it as:

- `Version 1`
- `Post-Version 1`
- `Out of Scope`

## 15. Success Criteria

The first release is successful if a user can:

- sign in
- create a notebook
- add text and code blocks
- run code reliably in steps
- reuse state across blocks
- see meaningful outputs, including tables and charts
- continue working offline
- manually sync notebook state with the backend
- ask AI to generate code from a description

If these flows are strong, the project has a solid foundation.

