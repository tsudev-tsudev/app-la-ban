// Kiểu tối thiểu cho module Node dùng trong test (gói không cài @types/node).
declare module 'node:crypto' {
  export function generateKeyPairSync(t: 'ed25519'): { privateKey: unknown; publicKey: { export(o: { format: 'jwk' }): { x: string } } };
  export function sign(alg: null, data: Uint8Array, key: unknown): Uint8Array;
}
