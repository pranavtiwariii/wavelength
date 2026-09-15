import { describe, expect, it } from 'vitest';
import { generateNarrative } from './index.js';

// No ANTHROPIC_API_KEY in tests, so these exercise the local fallback - which
// is the path most installs will actually run.
describe('local compatibility narrative', () => {
  it('agrees in number with a named person', async () => {
    const text = await generateNarrative({
      viewerName: 'Pranav',
      otherName: 'Maya',
      overallScore: 12,
      shared: [],
      divergences: [],
    });
    expect(text).toContain("Maya doesn't");
    expect(text).not.toContain("Maya don't");
  });

  it('agrees in number with the anonymous fallback', async () => {
    const text = await generateNarrative({
      viewerName: 'Pranav',
      otherName: null,
      overallScore: 12,
      shared: [],
      divergences: [],
    });
    expect(text).toContain("They don't");
    expect(text).not.toContain("They doesn't");
  });

  it('names the actual shared titles rather than speaking in genres', async () => {
    const text = await generateNarrative({
      viewerName: 'Pranav',
      otherName: 'Arjun',
      overallScore: 61,
      shared: [
        { domain: 'music', label: 'Phoebe Bridgers' },
        { domain: 'movie', label: 'In the Mood for Love' },
      ],
      divergences: [{ domain: 'movie', label: 'Hereditary', heldByOther: true }],
    });
    expect(text).toContain('Phoebe Bridgers');
    expect(text).toContain('In the Mood for Love');
    expect(text).toContain('Hereditary');
  });

  it('phrases a divergence differently depending on who holds it', async () => {
    const base = { viewerName: 'P', otherName: 'A', overallScore: 50, shared: [{ domain: 'music', label: 'Radiohead' }] };
    const theirs = await generateNarrative({
      ...base,
      divergences: [{ domain: 'movie', label: 'Hereditary', heldByOther: true }],
    });
    const mine = await generateNarrative({
      ...base,
      divergences: [{ domain: 'movie', label: 'Stalker', heldByOther: false }],
    });
    expect(theirs).toContain("They're into Hereditary");
    expect(mine).toContain("You're into Stalker");
  });
});
