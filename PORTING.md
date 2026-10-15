# Adapton port

Reference: `.repos/adapton`, Adapton Rust 0.3.31, commit
`ea903dd961bee3568c483a18a72983d9f4ef5ed2`.

This project ports the demand-driven incremental computation model to MoonBit.
The source reference is kept outside version control under `.repos/`.
The implementation retains the upstream MPL-2.0 license.

Implementation milestones:

1. Module setup and structural names.
2. Heterogeneous dependency graph, cells, lazy thunks, and change propagation.
3. Typed nominal and structural memoization, namespaces, and allocation tracking.
4. Incremental collection examples, regression tests, and public documentation.

MoonBit uses explicit engine instances and typed memo/cell tables instead of
Rust's thread-local engine and dynamically cast global location table.
