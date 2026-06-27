# shipshape review lenses (fallback when /crew is unavailable)

Apply these lenses to the diff before the gate. For each, list concrete findings
(file:line + issue + suggested fix) or "none". Keep it proportional to diff size.

1. **Engineering** — correctness, edge cases, error handling, data flow, test coverage.
2. **Security** — secrets in diff, injection, auth/authz, unsafe input trust, supply chain. Anchor any host check: `host == d || host endsWith "."+d`, never `d in host`.
3. **Scope/product** — does the change match the stated intent? Anything missing or gold-plated?
4. **DX (if API/CLI/lib/docs touched)** — naming, ergonomics, docs/examples accuracy.
5. **Adversarial QA** — inputs/sequences that break it; what isn't tested that should be.

Fix what's clearly correct to fix; surface judgment calls to the user.
