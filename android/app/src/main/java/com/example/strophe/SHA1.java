package com.example.strophe;

/**
 * Created by andre on 27/03/18.
 */

public class SHA1 {
    /*
* Calculate the SHA-1 of an array of big-endian words, and a bit length
*/
    static int[] core_sha1(int[] x, int len) {

  /* append padding */
        int[] temp = x;
        if ((x.length <= (len >> 5))) {
            temp = new int[(len >> 5) + 1];
            for (int i = 0; i < x.length; i++) {
                temp[i] = x[i];
            }
            temp[len >> 5] = 0x80 << (24 - len % 32);
        } else
            temp[len >> 5] |= 0x80 << (24 - len % 32);
        if (temp.length <= ((((len + 64) >> 9) << 4) + 15) + 1) {
            int[] temp2 = temp;
            temp = new int[((((len + 64) >> 9) << 4) + 15) + 1];
            for (int i = 0; i < temp2.length; i++) {
                temp[i] = temp2[i];
            }
            temp[((len + 64 >> 9) << 4) + 15] = len;
        } else
            temp[((len + 64 >> 9) << 4) + 15] = len;

        x = temp;
        int[] w = new int[80];
        int a = 1732584193;
        int b = -271733879;
        int c = -1732584194;
        int d = 271733878;
        int e = -1009589776;

        int t, olda, oldb, oldc, oldd, olde;
        for (int i = 0; i < x.length; i += 16) {
            olda = a;
            oldb = b;
            oldc = c;
            oldd = d;
            olde = e;

            for (int j = 0; j < 80; j++) {
                if (j < 16) {
                    w[j] = x[i + j];
                } else {
                    w[j] = rol(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);
                }
                t = safe_add(safe_add(rol(a, 5), sha1_ft(j, b, c, d)),
                        safe_add(safe_add(e, w[j]), sha1_kt(j)));
                e = d;
                d = c;
                c = rol(b, 30);
                b = a;
                a = t;
            }

            a = safe_add(a, olda);
            b = safe_add(b, oldb);
            c = safe_add(c, oldc);
            d = safe_add(d, oldd);
            e = safe_add(e, olde);
        }
        return new int[]{a, b, c, d, e};
    }

    /*
     * Perform the appropriate triplet combination function for the current
     * iteration
     */
    static int sha1_ft(int t, int b, int c, int d) {
        if (t < 20) {
            return (b & c) | ((~b) & d);
        }
        if (t < 40) {
            return b ^ c ^ d;
        }
        if (t < 60) {
            return (b & c) | (b & d) | (c & d);
        }
        return b ^ c ^ d;
    }

    /*
     * Determine the appropriate additive constant for the current iteration
     */
    static int sha1_kt(int t) {
        return (t < 20) ? 1518500249 : (t < 40) ? 1859775393 :
                (t < 60) ? -1894007588 : -899497514;
    }

    /*
     * Calculate the HMAC-SHA1 of a key and some data
     */
    static int[] core_hmac_sha1(String key, String data) {
        int[] bkey = str2binb(key);
        if (bkey.length > 16) {
            bkey = core_sha1(bkey, key.length() * 8);
        }
        int[] ipad = new int[16];
        int[] opad = new int[16];
        int bCle;
        for (int i = 0; i < 16; i++) {
            if (bkey.length <= i) bCle = 0;
            else bCle = bkey[i];
            ipad[i] = bCle ^ 0x36363636;
            opad[i] = bCle ^ 0x5C5C5C5C;
        }

        int[] hash = core_sha1(combine(ipad, str2binb(data)), 512 + data.length() * 8);
        return core_sha1(combine(opad, hash), 512 + 160);
    }

    static private int[] combine(int[] a, int[] b) {
        int length = a.length + b.length;
        int[] result = new int[length];
        System.arraycopy(a, 0, result, 0, a.length);
        System.arraycopy(b, 0, result, a.length, b.length);
        return result;
    }

    /*
     * Add integers, wrapping at 2^32. This uses 16-bit operations internally
     * to work around bugs in some JS interpreters.
     */
    static int safe_add(int x, int y) {
        int lsw = (x & 0xFFFF) + (y & 0xFFFF);
        int msw = (x >> 16) + (y >> 16) + (lsw >> 16);
        return (msw << 16) | (lsw & 0xFFFF);
    }

    /*
     * Bitwise rotate a 32-bit number to the left.
     */
    static int rol(int num, int cnt) {
        return (num << cnt) | (num >>> (32 - cnt));
    }

    /*
     * Convert an 8-bit or 16-bit string to an array of big-endian words
     * In 8-bit function, characters >255 have their hi-byte silently ignored.
     */
    static int[] str2binb(String str) {
        int[] bin = {};
        int mask = 255;
        int index;
        int[] temp;
        for (int i = 0; i < str.length() * 8; i += 8) {
            index = i >> 5;
            if (bin.length <= index) {
                temp = bin;
                bin = new int[index + 1];
                for (int j = 0; j < temp.length; j++) {
                    bin[j] = temp[j];
                }
            }
            bin[i >> 5] |= (str.codePointAt(i / 8) & mask) << (24 - i % 32);
        }
        return bin;
    }

    /*
     * Convert an array of big-endian words to a string
     */
    static String binb2str(int[] bin) {
        String str = "";
        int mask = 255;
        for (int i = 0; i < bin.length * 32; i += 8) {

            str += Character.toString((char) ((bin[i >> 5] >>> (24 - i % 32)) & mask));
        }
        return str;
    }

    /*
     * Convert an array of big-endian words to a base-64 string
     */
    static String binb2b64(int[] binarray) {
        String[] tab = new String[]{"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "/"};
        String str = "";
        int triplet;
        int bin, bin2, bin3;
        for (int i = 0; i < binarray.length * 4; i += 3) {
            bin = (i >> 2) < binarray.length ? binarray[i >> 2] : 0;
            bin2 = (i + 1 >> 2) < binarray.length ? binarray[i + 1 >> 2] : 0;
            bin3 = (i + 2 >> 2) < binarray.length ? binarray[i + 2 >> 2] : 0;
            triplet = (((bin >> 8 * (3 - i % 4)) & 0xFF) << 16) |
                    (((bin2 >> 8 * (3 - (i + 1) % 4)) & 0xFF) << 8) |
                    ((bin3 >> 8 * (3 - (i + 2) % 4)) & 0xFF);
            for (int j = 0; j < 4; j++) {
                if (i * 8 + j * 6 > binarray.length * 32) {
                    str += "=";
                } else {
                    str += tab[(triplet >> 6 * (3 - j)) & 0x3F];
                }
            }
        }
        return str;
    }

    static String b64_hmac_sha1(String key, String data) {
        return binb2b64(core_hmac_sha1(key, data));
    }

    static String b64_sha1(String s) {
        return binb2b64(core_sha1(str2binb(s), s.length() * 8));
    }

    static String str_hmac_sha1(String key, String data) {
        return binb2str(core_hmac_sha1(key, data));
    }

    static String str_sha1(String s) {
        return binb2str(core_sha1(str2binb(s), s.length() * 8));
    }

    static int[] forEachBinaryXor(int[] tab1, int[] tab2, int length) {
        for (int k = 0; k < length; k++) {
            if (k < length)
                tab1[k] ^= tab2[k];
        }
        return tab1;
    }
}
