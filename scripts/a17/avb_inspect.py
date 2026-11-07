#!/usr/bin/env python3
"""Read an AVB footer + vbmeta + hash descriptor from an Android image, so the
parameters (salt, digest, flags, rollback index, key) can be inspected and
reproduced when re-signing after a content modification.

Layout per AOSP external/avb/libavb/avb_vbmeta_image.h (big-endian):
  0 magic 'AVB0', 4 required_major, 8 required_minor,
  12 auth_block_size, 16 auxiliary_block_size, 20 algorithm_type,
  24 hash_offset, 28 hash_size, 32 signature_offset, 36 signature_size,
  40 public_key_offset, 44 public_key_size,
  48 public_key_metadata_offset, 52 public_key_metadata_size,
  56 descriptors_offset, 60 descriptors_size,
  64 rollback_index(u64), 72 flags, 76 rollback_index_location,
  80 release_string[48]
"""
import hashlib
import struct
import sys

FOOTER_MAGIC = b"AVBf"
VBMETA_MAGIC = b"AVB0"


def u32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def u64(b, o):
    return struct.unpack_from(">Q", b, o)[0]


ALGS = {
    0: "NONE",
    1: "SHA256_RSA2048",
    2: "SHA256_RSA4096",
    3: "SHA256_RSA8192",
    4: "SHA512_RSA2048",
    5: "SHA512_RSA4096",
    6: "SHA512_RSA8192",
}


def main(path):
    with open(path, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(size - 64)
        footer = f.read(64)
        print("file      : %s  size=%d (0x%X)" % (path, size, size))
        if footer[:4] != FOOTER_MAGIC:
            sys.exit("not an AVB footer: %r" % footer[:4])
        ver_major, ver_minor = struct.unpack_from(">II", footer, 4)
        orig_size = u64(footer, 12)
        vbmeta_off = u64(footer, 20)
        vbmeta_size = u64(footer, 28)
        print("footer    : version=%d.%d orig_size=%d (0x%X) vbmeta_off=0x%X vbmeta_size=%d"
              % (ver_major, ver_minor, orig_size, orig_size, vbmeta_off, vbmeta_size))
        f.seek(vbmeta_off)
        vb = f.read(vbmeta_size)

    if vb[:4] != VBMETA_MAGIC:
        sys.exit("bad vbmeta magic %r" % vb[:4])
    auth_size = u32(vb, 12)
    aux_size = u32(vb, 16)
    alg = u32(vb, 20)
    pk_off, pk_size = u32(vb, 40), u32(vb, 44)
    desc_off, desc_size = u32(vb, 56), u32(vb, 60)
    rollback = u64(vb, 64)
    flags = u32(vb, 72)
    rollback_loc = u32(vb, 76)
    release = vb[80:128].split(b"\0")[0].decode("ascii", "replace")
    print("algorithm : %d (%s)" % (alg, ALGS.get(alg, "?")))
    print("blocks    : auth=%d aux=%d" % (auth_size, aux_size))
    print("rollback  : index=%d location=%d" % (rollback, rollback_loc))
    print("flags     : 0x%X" % flags)
    print("release   : %r" % release)

    pk = vb[pk_off:pk_off + pk_size]
    print("pubkey    : off=%d len=%d sha1(avb-blob)=%s" % (pk_off, pk_size, hashlib.sha1(pk).hexdigest()))

    desc = vb[desc_off:desc_off + desc_size]
    total = u64(desc, 0)
    off = 0
    while off < total:
        tag = u64(desc, off)
        nxt = u64(desc, off + 8)
        body = desc[off + 16:nxt]
        if tag == 0:
            k = u32(body, 0)
            key = body[4:4 + k].decode("ascii", "replace")
            v = u32(body, 4 + k)
            val = body[8 + k:8 + k + v].decode("ascii", "replace")
            print("  prop    : %s = %s" % (key, val))
        elif tag == 2:
            image_size = u64(body, 0)
            ha = body[16:48].split(b"\0")[0].decode("ascii", "replace")
            sa = body[48:80].split(b"\0")[0].decode("ascii", "replace")
            dsz = u32(body, 80)
            salt = body[84:84 + dsz]
            doff = 84 + dsz
            dsz2 = u32(body, doff)
            digest = body[doff + 4:doff + 4 + dsz2]
            f2 = u32(body, doff + 4 + dsz2)
            pname = body[doff + 8 + dsz2:].split(b"\0")[0].decode("ascii", "replace")
            print("  hash    : image_size=%d hash=%s salt_alg=%s" % (image_size, ha, sa))
            print("            salt=%s" % salt.hex())
            print("            digest=%s" % digest.hex())
            print("            flags=0x%X partition=%r" % (f2, pname))
        elif tag == 3:
            image_size = u64(body, 0)
            print("  hashtree: image_size=%d (hashtree descriptor)" % image_size)
        else:
            print("  tag %d len %d" % (tag, len(body)))
        off = nxt

    with open(path, "rb") as f:
        f.seek(0)
        h = hashlib.sha256()
        left = orig_size
        while left:
            chunk = f.read(min(1 << 20, left))
            if not chunk:
                break
            h.update(chunk)
            left -= len(chunk)
    print("  content : sha256(orig_size bytes)=%s" % h.hexdigest())


if __name__ == "__main__":
    main(sys.argv[1])
