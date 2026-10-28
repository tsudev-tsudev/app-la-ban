export type SucKhoe = { ok: true; moiTruong: string; build: string };

export function sucKhoe(moiTruong: string, build: string | undefined): SucKhoe {
  return { ok: true, moiTruong, build: build ?? 'local' };
}
