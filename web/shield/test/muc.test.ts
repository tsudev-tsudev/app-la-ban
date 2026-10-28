import { describe, expect, it } from 'vitest';
import { chuanHoaMuc } from '../src/index';

describe('chuanHoaMuc', () => {
  it('giữ giá trị hợp lệ', () => expect(chuanHoaMuc('nhe')).toBe('nhe'));
  it('giá trị lạ -> chat (đóng khi lỗi)', () => expect(chuanHoaMuc('xyz')).toBe('chat'));
});
