# Large Fast Mode Sample

This placeholder documents the fast mode behavior for files larger than `MARKLOOK_FULL_RENDER_LIMIT_BYTES`.

Expected behavior for large files:

- show the file name
- show the file size
- avoid a blank Quick Look preview
- render only a bounded preview or source excerpt
- never freeze Finder

The large generated fixture and timing logs belong to the hardening PR.
