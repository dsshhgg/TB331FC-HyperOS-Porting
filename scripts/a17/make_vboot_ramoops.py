"""Repack a vendor_boot v4 image with ramoops console logging enabled.

Usage: python make_vboot_ramoops.py <src vendor_boot.img> <out.img>
Steps: parse v4 header -> extract vendor_ramdisk + dtb blob -> extract first FDT,
dtc decompile (WSL) -> patch ramoops_region (console-size/record-size) -> dtc compile
-> rebuild dtb blob keeping the trailing opaque blob at its original offset ->
repackage with dtb/mkv4.py -> pad to 100663296.
"""
import struct, os, subprocess, sys

DTB_DIR = r'E:\rom\release\tmp\tb331fc-linux\TB331FC-Linux-main\dtb'
sys.path.insert(0, DTB_DIR)
from mkv4 import mk_vendor_boot

SRC, OUT = sys.argv[1], sys.argv[2]
WORK = r'E:\rom\release\tmp\vboot_work'
os.makedirs(WORK, exist_ok=True)
PAGE = 4096
PART_SIZE = 100663296


# BUG FIX: the distro was hard-coded to 'UbuntuTB', so the script died with a
# cryptic "There is no distribution with the supplied name" on any machine where
# that name is absent, even though dtc exists in the default distro. Now pick the
# first installed distro that actually has dtc, and let WSL_DISTRO override.
def _wsl_text(args):
    """WSL emits UTF-16LE for `wsl -l`; Python's text=True decodes it as cp936 and
    yields 'U\\x00b\\x00u\\x00...' (verified on this machine). Decode bytes ourselves."""
    r = subprocess.run(args, capture_output=True)
    out = r.stdout or b''
    if b'\x00' in out[:64]:
        try:
            out = out.decode('utf-16-le', 'replace')
        except Exception:
            out = out.decode('utf-8', 'replace')
    else:
        out = out.decode('utf-8', 'replace')
    return r.returncode, out.replace('\ufeff', '')


def _pick_distro():
    want = os.environ.get('WSL_DISTRO')
    if want:
        return want
    try:
        rc, out = _wsl_text(['wsl', '-l', '-q'])
    except Exception:
        raise SystemExit('cannot run wsl; device-tree-compiler needed on Windows?')
    names = [l.strip() for l in out.splitlines() if l.strip()]
    for n in names:
        try:
            rc2, o2 = _wsl_text(['wsl', '-d', n, '--', 'bash', '-lc', 'command -v dtc'])
            if rc2 == 0 and o2.strip():
                return n
        except Exception:
            continue
    raise SystemExit('no WSL distro with dtc found (tried: ' + ', '.join(names) +
                     '); install device-tree-compiler or set WSL_DISTRO')


DISTRO = _pick_distro()


def wsl(cmd):
    r = subprocess.run(['wsl', '-d', DISTRO, '--', 'bash', '-lc', cmd],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f'wsl failed (distro={DISTRO}): {cmd}\n{r.stdout}\n{r.stderr}')
    return r.stdout


def win(path):
    return '/mnt/' + path[0].lower() + path[2:].replace('\\', '/')


d = open(SRC, 'rb').read()
hs = struct.unpack_from('<I', d, 0x830)[0]
vr_sz = struct.unpack_from('<I', d, 0x18)[0]
dk = struct.unpack_from('<I', d, 0x834)[0]
tb_sz, tb_num, tb_es, bc_sz = struct.unpack_from('<4I', d, 0x840)
dtb_addr = struct.unpack_from('<Q', d, 0x838)[0]
cmdline = d[0x1c:0x1c + 2048].split(b'\0')[0].decode()

base = ((hs + PAGE - 1) // PAGE) * PAGE
off_vr = base
off_dtb = off_vr + ((vr_sz + PAGE - 1) // PAGE) * PAGE
off_tb = off_dtb + ((dk + PAGE - 1) // PAGE) * PAGE
off_bc = off_tb + ((tb_sz + PAGE - 1) // PAGE) * PAGE
vr = d[off_vr:off_vr + vr_sz]
dtb_blob = d[off_dtb:off_dtb + dk]
bootconfig = d[off_bc:off_bc + bc_sz]

# locate first FDT inside the dtb blob
magic, total = struct.unpack_from('>II', dtb_blob, 0)
assert magic == 0xd00dfeed, hex(magic)
first = dtb_blob[:total]
tail_off = (total + PAGE - 1) // PAGE * PAGE
tail = dtb_blob[tail_off:]
print(f'src={SRC}\n  vr={vr_sz} dtb_blob={dk} fdt0={total} tail_off={tail_off} tail={len(tail)}')

f0 = os.path.join(WORK, 'fdt0.dtb')
open(f0, 'wb').write(first)
dts = os.path.join(WORK, 'fdt0.dts')
wsl(f'dtc -I dtb -O dts -o {win(dts)} {win(f0)} 2>/dev/null')
src_dts = open(dts, encoding='utf-8', errors='replace').read()

needle = 'compatible = "ramoops";'
i = src_dts.find(needle)
assert i > 0, 'ramoops node not found'
start = src_dts.rfind('{', 0, i)
start = src_dts.rfind('\n', 0, start) + 1
end = src_dts.find('};', i) + 2
block = src_dts[start:end]
print('  original ramoops block:\n' + block)

props = [l for l in block.splitlines() if l.strip() and 'ramoops_region' not in l]
props = [l for l in props if not l.strip().startswith('}')]
new_props = []
saw_pmsg = False
for line in props:
    s = line.strip()
    if s.startswith('size ='):
        new_props.append('\t\t\tsize = <0x00 0x600000>;')
    elif s.startswith('pmsg-size'):
        new_props.append('\t\t\trecord-size = <0x00 0x100000>;')
        new_props.append('\t\t\tconsole-size = <0x00 0x200000>;')
        new_props.append('\t\t\tpmsg-size = <0x00 0x200000>;')
        saw_pmsg = True
    else:
        new_props.append(line)
assert saw_pmsg, 'pmsg-size line not found'
new_block = '\t\tramoops_region {\n' + '\n'.join(new_props) + '\n\t\t};'
print('  new ramoops block:\n' + new_block)

patched = src_dts[:start] + new_block + src_dts[end:]
pdts = os.path.join(WORK, 'fdt0_patched.dts')
open(pdts, 'w', encoding='utf-8', newline='\n').write(patched)
pdtb = os.path.join(WORK, 'fdt0_patched.dtb')
wsl(f'dtc -I dts -O dtb -o {win(pdtb)} {win(pdts)} 2>/dev/null')
new0 = open(pdtb, 'rb').read()
assert b'__symbols__' in new0, 'lost __symbols__'
assert len(new0) <= tail_off, f'patched fdt {len(new0)} > tail_off {tail_off}'
new_dtb = new0 + b'\0' * (tail_off - len(new0)) + tail
assert len(new_dtb) == len(dtb_blob), (len(new_dtb), len(dtb_blob))

img = mk_vendor_boot(vendor_ramdisk=vr, dtb=new_dtb, cmdline=cmdline,
                     bootconfig=bootconfig, dtb_addr=dtb_addr, out=OUT)
if len(img) < PART_SIZE:
    img = img + b'\0' * (PART_SIZE - len(img))
    open(OUT, 'wb').write(img)

# verify
d2 = open(OUT, 'rb').read()
assert d2[:8] == b'VNDRBOOT'
hs2 = struct.unpack_from('<I', d2, 0x830)[0]
vr2 = struct.unpack_from('<I', d2, 0x18)[0]
dk2 = struct.unpack_from('<I', d2, 0x834)[0]
tb2 = struct.unpack_from('<4I', d2, 0x840)
base2 = ((hs2 + PAGE - 1) // PAGE) * PAGE
o_dtb = base2 + ((vr2 + PAGE - 1) // PAGE) * PAGE
o_vr = base2
print(f'  out={OUT} size={len(d2)} vr={vr2} dtb={dk2} table={tb2} cmdline={cmdline!r}')
print('  fdt magic', d2[o_dtb:o_dtb + 4].hex(), 'ramdisk ok', d2[o_vr:o_vr + vr2] == vr)
import hashlib
print('  sha256', hashlib.sha256(d2).hexdigest())
