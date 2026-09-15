/**
 * Deterministic illustrated portraits via DiceBear — keyless, stable per user,
 * and clearly illustrations rather than photorealistic faces of people who
 * don't exist.
 */
const STYLES = ['notionists', 'avataaars', 'lorelei', 'adventurer'] as const;

const BACKGROUNDS = ['6FE3C4', 'F2A65A', 'B08CF0', 'CFE36F', '8E8A9C'];

export function avatarFor(seedId: string, name: string): string {
  const hash = [...`${seedId}${name}`].reduce((a, c) => a + c.charCodeAt(0), 0);
  const style = STYLES[hash % STYLES.length];
  const background = BACKGROUNDS[hash % BACKGROUNDS.length];
  const seed = encodeURIComponent(name || seedId);

  return `https://api.dicebear.com/9.x/${style}/png?seed=${seed}&size=400&backgroundColor=${background}&backgroundType=gradientLinear`;
}
