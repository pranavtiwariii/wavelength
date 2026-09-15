import { config } from '../../config.js';
import { TtlCache } from '../../lib/cache.js';

export interface NarrativeInput {
  viewerName: string | null;
  otherName: string | null;
  overallScore: number;
  shared: Array<{ domain: string; label: string }>;
  divergences: Array<{ domain: string; label: string; heldByOther: boolean }>;
}

const cache = new TtlCache<string>(1000 * 60 * 60 * 24, 2000);

function cacheKey(input: NarrativeInput): string {
  // The narrative names the people involved, so the names are part of its
  // identity. Leaving them out would serve one person's narrative to another
  // with the same overlap.
  return [
    input.viewerName ?? '',
    input.otherName ?? '',
    input.overallScore,
    input.shared.map((s) => `${s.domain}:${s.label}`).join('|'),
    input.divergences.map((d) => `${d.domain}:${d.label}:${d.heldByOther}`).join('|'),
  ].join('::');
}

const DOMAIN_WORD: Record<string, string> = {
  music: 'music',
  movie: 'films',
  book: 'books',
};

/**
 * A written-in-code narrative used when no Anthropic key is configured. It is
 * deliberately specific - it names real shared items - so the feature is
 * genuinely useful without an API key, rather than a placeholder.
 */
function localNarrative(input: NarrativeInput): string {
  const shared = input.shared;
  // A name takes a singular verb ("Maya doesn't"); the fallback pronoun takes a
  // plural one ("They don't"). Getting this wrong reads as broken software.
  const subject = input.otherName ?? 'They';
  const doesNot = input.otherName ? "doesn't" : "don't";

  if (shared.length === 0) {
    return `${subject} ${doesNot} share a single favourite with you yet — which is its own kind of interesting. Ask what they'd put on first.`;
  }

  const top = shared[0]!;
  const byDomain = new Map<string, string[]>();
  for (const item of shared) {
    byDomain.set(item.domain, [...(byDomain.get(item.domain) ?? []), item.label]);
  }

  const parts: string[] = [];
  if (shared.length === 1) {
    parts.push(`You both have ${top.label} in your favourites.`);
  } else {
    const domains = [...byDomain.keys()].map((d) => DOMAIN_WORD[d] ?? d);
    const spread =
      domains.length > 1
        ? `across ${domains.slice(0, -1).join(', ')} and ${domains.at(-1)}`
        : `in ${domains[0]}`;
    parts.push(
      `You share ${shared.length} favourites ${spread} — including ${top.label}${
        shared[1] ? ` and ${shared[1].label}` : ''
      }.`,
    );
  }

  if (input.overallScore >= 75) {
    parts.push('That is a lot of overlap for two people who have never spoken.');
  } else if (input.overallScore >= 45) {
    parts.push('Enough common ground to start somewhere real.');
  } else {
    parts.push('Not a huge overlap — but the overlap you do have is specific.');
  }

  const divergence = input.divergences[0];
  if (divergence) {
    parts.push(
      divergence.heldByOther
        ? `They're into ${divergence.label} and you've never touched it — worth asking why.`
        : `You're into ${divergence.label} and they aren't — see if you can sell it.`,
    );
  }

  return parts.join(' ');
}

/**
 * Spec 3.5: a short, warm, specific narrative naming real shared artifacts.
 * Cached per input, and only called when a breakdown is opened - never
 * per-swipe.
 */
export async function generateNarrative(input: NarrativeInput): Promise<string> {
  const key = cacheKey(input);
  const cached = cache.get(key);
  if (cached) return cached;

  if (!config.anthropicApiKey) {
    const local = localNarrative(input);
    cache.set(key, local);
    return local;
  }

  const sharedList = input.shared.map((s) => `- ${s.label} (${s.domain})`).join('\n') || '- none';
  const divergenceList =
    input.divergences
      .map((d) => `- ${d.label} (${d.domain}, loved by ${d.heldByOther ? 'them' : 'the reader'})`)
      .join('\n') || '- none';

  const prompt = `Two people matched ${input.overallScore}% on a taste-compatibility app.

Favourites they share:
${sharedList}

Notable differences:
${divergenceList}

Write 2-3 sentences, addressed to the reader, about why these two might click.
Name the actual titles above - never invent one, never speak in genres alone.
Warm and specific, not breathless. No greeting, no sign-off, no emoji.`;

  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': config.anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-5',
        max_tokens: 220,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!res.ok) throw new Error(`Anthropic responded ${res.status}`);
    const body = (await res.json()) as { content?: Array<{ type: string; text?: string }> };
    const text = body.content?.find((c) => c.type === 'text')?.text?.trim();
    if (!text) throw new Error('empty completion');

    cache.set(key, text);
    return text;
  } catch {
    // A narrative is a nicety - never fail the breakdown over it.
    const local = localNarrative(input);
    cache.set(key, local);
    return local;
  }
}
