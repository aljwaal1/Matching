# Windows activation service

Deployment is separate from the public application repository. Never commit signing keys, activation codes, database files, or deployment credentials.

- Issue 1000 cryptographically random single-use codes, each with at least 128 bits of entropy.
- Store SHA-256 digests of canonical codes in a private SQLite database, outside the web root.
- HTTPS POST /activate accepts only a code and pseudonymous device fingerprint.
- Bind each code atomically to one device. Repeated requests from that device are idempotent; other devices are rejected.
- Return a signed versioned license containing product ID, device fingerprint and license ID. Use Ed25519 with a server-only private key.
- The client embeds only the public verification key, verifies the signature and device binding on every startup, and stores the signed license locally. No expiry for perpetual licenses.
- Rate limit activation attempts and avoid recording codes or raw hardware IDs in logs.
- Device replacement requires an authenticated administrative reset; offline licenses cannot be remotely revoked.
- No financial files, names, email addresses or transaction data are transmitted.
- Do not enable mandatory activation until server deployment, client verification and recovery tests pass.
