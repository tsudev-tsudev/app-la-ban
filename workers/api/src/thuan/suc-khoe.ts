export type SucKhoe = { ok: true; moiTruong: string; build: string };

// `build` = mã commit gắn lúc deploy (`--var BAN_BUILD:<sha>`), dùng để đo bản đang phục vụ.
export function sucKhoe(moiTruong: string, build: string | undefined): SucKhoe {
  return { ok: true, moiTruong, build: build && build.length > 0 ? build : 'local' };
}
