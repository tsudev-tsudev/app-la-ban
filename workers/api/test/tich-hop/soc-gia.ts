// Giả lập phía SOC cho test: IdP Access (ký JWT RS256 + JWKS) và authenticator passkey phần mềm (ES256, attestation none).
import { b64urlTuByte, byteTuB64url } from '../../src/thuan/ma-hoa';

type Cbor = number | string | Uint8Array | Cbor[] | Map<Cbor, Cbor> | boolean | null;

/** Mã hoá CBOR tối thiểu (chỉ dùng dựng dữ liệu thử). */
export function maHoaCbor(v: Cbor): Uint8Array {
  const ra: number[] = [];
  const dau = (loai: number, n: number) => {
    if (n < 24) ra.push((loai << 5) | n);
    else if (n < 256) ra.push((loai << 5) | 24, n);
    else if (n < 65536) ra.push((loai << 5) | 25, n >> 8, n & 0xff);
    else ra.push((loai << 5) | 26, (n >>> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff);
  };
  const ghi = (x: Cbor) => {
    if (x === null) ra.push(0xf6);
    else if (x === true) ra.push(0xf5);
    else if (x === false) ra.push(0xf4);
    else if (typeof x === 'number') dau(x >= 0 ? 0 : 1, x >= 0 ? x : -1 - x);
    else if (typeof x === 'string') {
      const b = new TextEncoder().encode(x);
      dau(3, b.length);
      ra.push(...b);
    } else if (x instanceof Uint8Array) {
      dau(2, x.length);
      ra.push(...x);
    } else if (Array.isArray(x)) {
      dau(4, x.length);
      x.forEach(ghi);
    } else {
      dau(5, x.size);
      for (const [k, val] of x) {
        ghi(k);
        ghi(val);
      }
    }
  };
  ghi(v);
  return new Uint8Array(ra);
}

// ---------------------------------------------------------------- Access
export class AccessGia {
  private constructor(
    private readonly khoa: CryptoKeyPair,
    readonly jwk: JsonWebKey,
    readonly team: string,
    readonly aud: string,
  ) {}

  static async tao(team = 'team.test', aud = 'aud-thu'): Promise<AccessGia> {
    const khoa = (await crypto.subtle.generateKey(
      { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
      true,
      ['sign', 'verify'],
    )) as CryptoKeyPair;
    const jwk = { ...((await crypto.subtle.exportKey('jwk', khoa.publicKey)) as JsonWebKey), kid: 'kid-1' } as JsonWebKey;
    return new AccessGia(khoa, jwk, team, aud);
  }

  jwks(): Response {
    return Response.json({ keys: [this.jwk] });
  }

  async jwt(claims: Record<string, unknown>, h: Record<string, unknown> = {}): Promise<string> {
    const bayGio = Math.floor(Date.now() / 1000);
    const dau = b64urlTuByte(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', kid: 'kid-1', typ: 'JWT', ...h })));
    const than = b64urlTuByte(
      new TextEncoder().encode(JSON.stringify({ iss: `https://${this.team}`, aud: [this.aud], iat: bayGio, exp: bayGio + 600, sub: 's', ...claims })),
    );
    const ky = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', this.khoa.privateKey, new TextEncoder().encode(`${dau}.${than}`));
    return `${dau}.${than}.${b64urlTuByte(ky)}`;
  }
}

// ---------------------------------------------------------------- passkey
async function sha256(b: Uint8Array | string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest('SHA-256', typeof b === 'string' ? new TextEncoder().encode(b) : b));
}

function noi(...ds: Uint8Array[]): Uint8Array {
  const kq = new Uint8Array(ds.reduce((a, b) => a + b.length, 0));
  let i = 0;
  for (const d of ds) {
    kq.set(d, i);
    i += d.length;
  }
  return kq;
}

/** Chữ ký WebCrypto r||s -> DER (định dạng authenticator trả cho ES256). */
function thoSangDer(tho: Uint8Array): Uint8Array {
  const so = (b: Uint8Array) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    const x = b.slice(i);
    return (x[0] as number) & 0x80 ? noi(new Uint8Array([0]), x) : x;
  };
  const r = so(tho.slice(0, 32));
  const s = so(tho.slice(32));
  return noi(new Uint8Array([0x30, r.length + s.length + 4, 0x02, r.length]), r, new Uint8Array([0x02, s.length]), s);
}

export class PasskeyGia {
  dem = 0;
  readonly id = crypto.getRandomValues(new Uint8Array(32));
  private constructor(private readonly khoa: CryptoKeyPair) {}

  static async tao(): Promise<PasskeyGia> {
    return new PasskeyGia((await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify'])) as CryptoKeyPair);
  }

  get idB64(): string {
    return b64urlTuByte(this.id);
  }

  private clientData(type: string, challenge: string, origin: string): Uint8Array {
    return new TextEncoder().encode(JSON.stringify({ type, challenge, origin, crossOrigin: false }));
  }

  async dangKy(tuyChon: { challenge: string; rp: { id: string } }, origin: string, flags = 0x45) {
    const jwk = (await crypto.subtle.exportKey('jwk', this.khoa.publicKey)) as JsonWebKey;
    const cose = maHoaCbor(
      new Map<Cbor, Cbor>([
        [1, 2],
        [3, -7],
        [-1, 1],
        [-2, byteTuB64url(jwk.x as string) as Uint8Array],
        [-3, byteTuB64url(jwk.y as string) as Uint8Array],
      ]),
    );
    const authData = noi(
      await sha256(tuyChon.rp.id),
      new Uint8Array([flags, 0, 0, 0, this.dem]),
      new Uint8Array(16),
      new Uint8Array([0, this.id.length]),
      this.id,
      cose,
    );
    const att = maHoaCbor(new Map<Cbor, Cbor>([['fmt', 'none'], ['attStmt', new Map()], ['authData', authData]]));
    return {
      clientDataJSON: b64urlTuByte(this.clientData('webauthn.create', tuyChon.challenge, origin)),
      attestationObject: b64urlTuByte(att),
    };
  }

  async xacThuc(tuyChon: { challenge: string; rpId: string }, origin: string, them = 1) {
    this.dem += them;
    const cd = this.clientData('webauthn.get', tuyChon.challenge, origin);
    const ad = noi(await sha256(tuyChon.rpId), new Uint8Array([0x05, 0, 0, 0, this.dem]));
    const ky = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, this.khoa.privateKey, noi(ad, await sha256(cd))));
    return {
      id: this.idB64,
      clientDataJSON: b64urlTuByte(cd),
      authenticatorData: b64urlTuByte(ad),
      signature: b64urlTuByte(thoSangDer(ky)),
    };
  }
}
