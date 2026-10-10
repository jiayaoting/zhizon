import { describe, it, expect } from '@ohos/hypium';
import { NewsNowAuth, HotLoginCallback } from '../main/ets/service/NewsNowAuth';

// 构造仅用于解析校验的假 JWT（payload 不含真实签名）
function fakeJwt(payloadJson: string): string {
  const b64: string = base64Url(payloadJson);
  return 'header.' + b64 + '.signature';
}

function base64Url(text: string): string {
  const bytes: number[] = [];
  for (let i: number = 0; i < text.length; i++) {
    bytes.push(text.charCodeAt(i) & 0xFF);
  }
  let binary: string = '';
  for (let i: number = 0; i < bytes.length; i++) {
    binary = binary + String.fromCharCode(bytes[i]);
  }
  let b64: string = '';
  const table: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let i: number = 0;
  while (i < binary.length) {
    const c1: number = binary.charCodeAt(i++);
    const c2: number = i < binary.length ? binary.charCodeAt(i++) : NaN;
    const c3: number = i < binary.length ? binary.charCodeAt(i++) : NaN;
    const e1: number = c1 >> 2;
    const e2: number = ((c1 & 3) << 4) | (isNaN(c2) ? 0 : c2 >> 4);
    const e3: number = isNaN(c2) ? 64 : (((c2 & 15) << 2) | (isNaN(c3) ? 0 : c3 >> 6));
    const e4: number = isNaN(c3) ? 64 : (c3 & 63);
    b64 = b64 + table.charAt(e1) + table.charAt(e2) +
      (e3 === 64 ? '' : table.charAt(e3)) + (e4 === 64 ? '' : table.charAt(e4));
  }
  return b64.replace(/\+/g, '-').replace(/\//g, '_');
}

export default function NewsNowClientTest() {
  describe('NewsNowAuthTest', () => {
    it('parses the login callback url into jwt and user', 0, () => {
      const jwt: string = fakeJwt('{"id":"12345","type":"github","exp":4102444800}');
      const user: string = encodeURIComponent('{"avatar":"https://avatars.example/u.png","name":"tester"}');
      const url: string = 'https://newsnow.example.com/?login=github&jwt=' + jwt + '&user=' + user;
      const cb: HotLoginCallback = NewsNowAuth.parseCallback(url);
      expect(cb.matched).assertTrue();
      expect(cb.jwt).assertEqual(jwt);
      expect(cb.user !== null).assertTrue();
    });

    it('ignores urls without jwt', 0, () => {
      const cb: HotLoginCallback = NewsNowAuth.parseCallback('https://newsnow.example.com/');
      expect(cb.matched).assertFalse();
      expect(cb.jwt).assertEqual('');
    });

    it('reads exp and subject from the jwt payload', 0, () => {
      const jwt: string = fakeJwt('{"id":"999","type":"github","exp":4102444800}');
      expect(NewsNowAuth.expiryOf(jwt)).assertEqual(4102444800);
      expect(NewsNowAuth.subjectOf(jwt)).assertEqual('999');
      expect(NewsNowAuth.isExpired(jwt)).assertFalse();
      expect(NewsNowAuth.isExpiringSoon(jwt)).assertFalse();
    });

    it('detects an expired jwt', 0, () => {
      const jwt: string = fakeJwt('{"id":"1","exp":1000000000}');
      expect(NewsNowAuth.isExpired(jwt)).assertTrue();
    });

    it('malformed tokens degrade to zero/empty instead of throwing', 0, () => {
      expect(NewsNowAuth.expiryOf('not-a-jwt')).assertEqual(0);
      expect(NewsNowAuth.subjectOf('')).assertEqual('');
      expect(NewsNowAuth.isExpired('a.b')).assertFalse();
    });
  });
}
