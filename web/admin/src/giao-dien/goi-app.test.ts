import { describe, expect, it } from 'vitest';
import { laGoiPro } from './goi-app';

describe('laGoiPro (M2)', () => {
  it('nhận gói Pro + flavor, không nhầm gói miễn phí / gói lạ', () => {
    expect(laGoiPro('com.tsudev.laban.pro')).toBe(true);
    expect(laGoiPro('com.tsudev.laban.pro.stg')).toBe(true);
    expect(laGoiPro('com.tsudev.laban')).toBe(false);
    expect(laGoiPro('com.tsudev.laban.dev')).toBe(false);
    expect(laGoiPro('com.tsudev.laban.prox')).toBe(false);
    expect(laGoiPro(null)).toBe(false);
  });
});
