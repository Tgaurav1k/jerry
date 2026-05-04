/** Stable uint for Agora from UUID string (fits Agora uid rules). */
export function agoraUidFromString(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) {
    h = Math.imul(31, h) + id.charCodeAt(i);
  }
  const n = Math.abs(h) % 2147483646;
  return n === 0 ? 1 : n;
}
