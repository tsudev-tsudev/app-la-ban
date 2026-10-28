// Kiểu tối thiểu cho vài API Node mà test chạy trong vitest (Node) dùng. Không cài @types/node: kiểu của nó xung đột
// với @cloudflare/workers-types (Request / Response toàn cục) mà mã Worker cần.
declare module 'node:fs' {
  export function readFileSync(duongDan: string, maHoa: 'utf8'): string;
  export function writeFileSync(duongDan: string, noiDung: string): void;
  export function existsSync(duongDan: string): boolean;
  export function readdirSync(duongDan: string): string[];
}
declare module 'node:path' {
  export function join(...phan: string[]): string;
}
declare const __dirname: string;
declare const process: { env: Record<string, string | undefined> };
