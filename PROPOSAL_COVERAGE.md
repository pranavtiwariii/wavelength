# MATES — proposal coverage

Mapped against *MATES: Taste-Based Social Discovery Platform* (UCS503P).
Tulika Jain · Mukul · Pranav Tiwari.

## 4.1 Proposed solution — components

| Proposal component | Status | Where |
| --- | --- | --- |
| **Taste Signature** — interest profile spanning music, movies, books | Built | Taste tab; live search across three providers, stored per domain |
| **Content Drops** — lightweight posts sharing/tagging content, by domain | Built | Drops tab; compose from your own taste, like + save, optional community |
| **Taste-based matching engine** — per-category and overall score | Built | `server/src/services/compatibility/`, isolated and unit tested |
| **Find My People** — ranked, explainable list | Built | Discover tab; every card names the shared favourites behind its score |
| **Connection system** — opt-in, bidirectional request/accept | Built | A like sends a *request*; the recipient accepts or declines. Chat unlocks only on accept |
| **Communities** — niche tag-based groups | Built | Rooms tab; 12 seeded communities, suggestions ranked by your own taste tags |

## 4.2 Core workflow

| Step | Status |
| --- | --- |
| 1. Sign up, create profile, select interests | Built — OTP auth, onboarding, taste import |
| 2. Explore and engage via likes, saves, Drops | Built — Drops feed with like/save |
| 3. System computes per-category and overall scores | Built — verified live: 61% / 5% spread across seeded users |
| 4. "Find My People" with explainable *why you matched* | Built — breakdown screen: per-domain scores, shared artifacts, Taste DNA radar, narrative |
| 5. Connection request; accepted → profile and chat unlock | Built — request/accept, then threaded chat |

## 5.1 Taste-matching algorithm

Matches the proposal's heuristic approach — no embedding models.

- Weighted keyword/vector representation per category
- `0.45 × cosine` + `0.35 × rarity-weighted Jaccard` + `0.20 × era/mood alignment`
- Inverse-popularity weighting, so a shared obscure film outranks a shared blockbuster
- Domain weights scale with data completeness and stated priority — an unconnected
  domain cannot drag a score toward zero
- Every score carries the concrete items that produced it

## 6 Evaluation criteria — what is measurable today

| Metric | Supported |
| --- | --- |
| Match-to-connection rate (MCR) | Yes — `swipes` and `connection_requests` are timestamped, so impressions → requests is a query |
| Connection acceptance rate | Yes — `connection_requests.status` + `responded_at` |
| Taste Signature completion rate | Yes — `users.taste_profile_completeness` |
| Match explanation density | Yes — `compatibility_scores.shared_highlights` per pair |
| Explainability satisfaction (1–5) | Not built — needs an in-app rating prompt |
| Reliability / uptime | Not built — needs deployment + monitoring |

## 6.3 Pilot validation

> "supplement real signups with a curated set of synthetic profiles carrying
> deliberately overlapping taste keywords"

Built, and it's the **Add a profile** screen plus a 20-person seed. Synthetic rows are
flagged `is_synthetic`, carry no credentials, and their favourites resolve through the
*same* providers real users search — so a seeded person and a real user who both add
Radiohead share an identical item key and genuinely overlap.

## 7 Scalability

| Proposal | Status |
| --- | --- |
| Matching decoupled from the API | Done — `services/compatibility` has no DB or HTTP dependency |
| Precompute / cache scores rather than recompute per request | Partial — scores are cached in `compatibility_scores` on read; the nightly job is not built |
| Indexed queries on keyword/category fields | Done — indexes on discovery, drops, memberships, request inbox |

## Deviations from the proposal

Agreed with you, recorded here so the report matches the build.

| Proposal | Built | Why |
| --- | --- | --- |
| FastAPI (Python) | Fastify (Node + TypeScript) | One language across the API and the shared contract |
| MongoDB Atlas | PostgreSQL | The data is relational — pairs, requests, memberships. Constraints catch real bugs (ordered pairs, no self-swipe, no orphan drops) |
| Firebase Authentication | Own OTP + JWT | Runs with zero third-party accounts or keys |
| Cloudinary | Generated portraits (DiceBear) | No upload pipeline needed yet; the schema has `user_photos` for when there is |

## Not built

- **Notification service** (proposal 5.2) — in-app notifications for connections, likes, matches
- **Explainability satisfaction survey** (6.2)
- **CI/CD pipeline** (5.3)
- **Deployment** — runs locally only, so no uptime metric
- **Spotify OAuth** — the sonic-fingerprint half of the music vector
- **Photo upload** — portraits are generated, not uploaded
