#!/usr/bin/env python3
"""Read-only Secure Boot / TPM-unlock readiness check for Debian, SWARM OS and Recovery OS.

Changes NOTHING. It reads the firmware's Secure Boot state and keys, the TPM, every EFI program on the three EFI system
partitions and the kernels, and the two LUKS volumes, and says which would boot with Secure Boot ON and who signed them.

    python3 70-scripts/secureboot_preflight.py            as a normal user: whatever is readable
    sudo python3 70-scripts/secureboot_preflight.py       full report (mounts the EFI partitions read-only, reads LUKS headers)
    python3 70-scripts/secureboot_preflight.py --files A.efi B.efi vmlinuz   just check these files

"Signed by a key in the firmware db" is judged by certificate NAMES (the real check is cryptographic and done by the
firmware), so treat "likely trusted" as strong evidence, not a guarantee. The firmware is the final judge.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

EFIVARS = "/sys/firmware/efi/efivars/"
GUID_GLOBAL = "8be4df61-93ca-11d2-aa0d-00e098032b8c"
GUID_DB = "d719b2cb-3d3a-4596-a3bc-dad00e67656f"
X509_GUID = bytes.fromhex("a159c0a5e494a74a87b5ab155c2bf072")  # EFI_CERT_X509_GUID, mixed-endian as stored

# The three machines' EFI system partitions (CLAUDE.md / MOUNTS.md). Looked up by UUID, never by /dev/sdX.
ESPS = {
    "Debian": "362A-E48F",
    "SWARM OS": "FE19-A70F",
    "Recovery OS": "A367-87E3",
}
LUKS = {"lucy-master (T7)": "a24202ce-4d76-4eb7-8923-8e8ddbacdaa7", "slick (NVMe)": "019a3cd8-46c5-4a19-a760-8e0c1096b248"}


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=30, **kw)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def say(msg=""):
    print(msg, flush=True)


# ------------------------------------------------------------------------------------------------ firmware
def efivar(name, guid=GUID_GLOBAL):
    try:
        with open(f"{EFIVARS}{name}-{guid}", "rb") as fh:
            return fh.read()[4:]  # first 4 bytes are the attributes
    except OSError:
        return None


def x509_certs_from_siglist(data):
    out, i = [], 0
    while data and i + 28 <= len(data):
        sig_type = data[i:i + 16]
        size, _hdr, esz = struct.unpack("<III", data[i + 16:i + 28])
        if size == 0:
            break
        body = data[i + 28 + _hdr:i + size]
        if sig_type == X509_GUID and esz > 16:
            for j in range(0, len(body) - esz + 1, esz):
                out.append(body[j + 16:j + esz])  # skip the 16-byte owner GUID
        i += size
    return out


def cert_names(der):
    p = subprocess.run(["openssl", "x509", "-inform", "DER", "-noout", "-subject", "-issuer", "-fingerprint", "-sha256"],
                       input=der, capture_output=True)
    text = p.stdout.decode("utf-8", "replace")
    subj = re.search(r"subject=\s*(.*)", text)
    iss = re.search(r"issuer=\s*(.*)", text)
    fp = re.search(r"Fingerprint=([0-9A-F:]+)", text)
    cn = lambda s: (re.search(r"CN\s*=\s*([^,/]+)", s).group(1).strip() if s and re.search(r"CN\s*=\s*([^,/]+)", s) else (s or "?").strip())
    return {"subject": subj.group(1).strip() if subj else "", "issuer": iss.group(1).strip() if iss else "",
            "cn": cn(subj.group(1) if subj else ""), "sha256": fp.group(1).replace(":", "").lower() if fp else ""}


def firmware_report():
    say("== FIRMWARE")
    if not os.path.isdir("/sys/firmware/efi"):
        say("  Not booted via UEFI: Secure Boot does not apply.")
        return {}
    sb = efivar("SecureBoot")
    setup = efivar("SetupMode")
    say(f"  Secure Boot:  {'ON' if sb and sb[-1] == 1 else 'OFF'}")
    say(f"  Setup Mode:   {'YES (firmware will accept new keys)' if setup and setup[-1] == 1 else 'no (User Mode: keys are enrolled)'}")
    db_names = {}
    for label, var, guid in (("PK", "PK", GUID_GLOBAL), ("KEK", "KEK", GUID_GLOBAL), ("db", "db", GUID_DB), ("dbx", "dbx", GUID_DB)):
        data = efivar(var, guid)
        if data is None:
            say(f"  {label:4} not readable / not set")
            continue
        certs = x509_certs_from_siglist(data)
        if label == "dbx":
            say(f"  dbx  revocation list present ({len(data)} bytes)")
            continue
        names = [cert_names(c) for c in certs]
        say(f"  {label:4} {len(names)} certificate(s): " + "; ".join(n['cn'] for n in names)[:230])
        if label == "db":
            db_names = {n["subject"]: n for n in names}
    return db_names


def tpm_report():
    say("\n== TPM")
    base = "/sys/class/tpm/tpm0"
    if not os.path.isdir(base):
        say("  No TPM found.")
        return
    ver = open(f"{base}/tpm_version_major").read().strip() if os.path.exists(f"{base}/tpm_version_major") else "?"
    banks = [d[4:] for d in sorted(os.listdir(base)) if d.startswith("pcr-")]
    say(f"  TPM {ver}.0, PCR banks: {', '.join(banks)}")
    for bank in ("sha256",):
        try:
            say(f"  PCR 7 ({bank}) in this boot: {open(f'{base}/pcr-{bank}/7').read().strip()}")
        except OSError:
            pass
    say("  (PCR 7 reflects Secure Boot state, the keys, and the certificate that approved each program that started.")
    say("   A TPM unlock sealed to PCR 7 only works for the same boot path, so each OS you want to auto-unlock must enroll its own.)")


# ------------------------------------------------------------------------------------------------ EFI programs
def pe_signatures(path):
    """Return None if the file is not a PE image, [] if unsigned, else a list of PKCS#7 DER blobs."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(0x400)
            if head[:2] != b"MZ":
                return None
            pe = struct.unpack_from("<I", head, 0x3C)[0]
            fh.seek(pe)
            hdr = fh.read(0x200)
            if hdr[:4] != b"PE\0\0":
                return None
            magic = struct.unpack_from("<H", hdr, 24)[0]
            dd = 24 + (112 if magic == 0x20B else 96)  # start of the data directories
            off, size = struct.unpack_from("<II", hdr, dd + 4 * 8)  # entry 4 = certificate table (a file offset)
            if off == 0 or size == 0:
                return []
            fh.seek(off)
            blob = fh.read(size)
    except (OSError, struct.error, ValueError):
        return None  # unreadable or malformed: not a usable EFI program
    out, i = [], 0
    while i + 8 <= len(blob):
        length, _rev, ctype = struct.unpack_from("<IHH", blob, i)
        if length < 8:
            break
        if ctype == 2:  # WIN_CERT_TYPE_PKCS_SIGNED_DATA
            out.append(blob[i + 8:i + length])
        i += (length + 7) & ~7
    return out


def pkcs7_chain(der):
    p = subprocess.run(["openssl", "pkcs7", "-inform", "DER", "-print_certs", "-noout"], input=der, capture_output=True)
    text = p.stdout.decode("utf-8", "replace")
    subs = re.findall(r"subject=\s*(.*)", text)
    iss = re.findall(r"issuer=\s*(.*)", text)
    return list(zip(subs, iss))


FW, DEBIAN, OTHER, UNSIGNED, NOTPE = "fw", "debian", "other", "unsigned", "notpe"


def judge(path, db_names):
    """-> (category, signer, text). Categories:
    fw        chain reaches a certificate in the firmware db: the FIRMWARE accepts it (e.g. Microsoft-signed shim)
    debian    signed by a Debian Secure Boot key: accepted by Debian's shim (which carries that key), not by the firmware itself
    other     signed, but by a key neither the firmware nor Debian's shim knows (needs your own key enrolled)
    unsigned  no signature at all"""
    sigs = pe_signatures(path)
    if sigs is None:
        return (NOTPE, "", "not an EFI/PE program")
    if not sigs:
        return (UNSIGNED, "", "UNSIGNED")
    best = (OTHER, "", "signed, but the signature could not be read")
    for der in sigs:
        chain = pkcs7_chain(der)
        if not chain:
            continue
        signer = re.search(r"CN\s*=\s*([^,/]+)", chain[0][0])
        signer = signer.group(1).strip() if signer else chain[0][0]
        subjects = {s for s, _ in chain}
        issuers = {i for _, i in chain}
        if db_names and (subjects | issuers) & set(db_names):
            return (FW, signer, f"signed by '{signer}': in the firmware db")
        if re.search(r"Debian Secure Boot", " ".join(subjects | issuers)):
            best = (DEBIAN, signer, f"signed by '{signer}': trusted by Debian's shim, not by the firmware")
        elif best[0] != DEBIAN:
            best = (OTHER, signer, f"signed by '{signer}': unknown to the firmware and to Debian's shim")
    return best


def os_verdict(files, db_names):
    """Judge one OS's boot chain: firmware -> first stage (shim, or GRUB itself) -> GRUB -> kernel."""
    has_shim = {os.path.dirname(f) for f in files if re.search(r"(?i)^shim[^/]*\.efi$", os.path.basename(f))}
    first_stage = [f for f in files if re.search(r"(?i)/EFI/BOOT/BOOT[^/]*\.EFI$", f)
                   or re.search(r"(?i)^shim[^/]*\.efi$", os.path.basename(f))
                   or (re.search(r"(?i)^(grub|BOOT)[^/]*\.efi$", os.path.basename(f)) and os.path.dirname(f) not in has_shim)]
    kernels_ = [f for f in files if "/vmlinuz" in f]
    rest = [f for f in files if f not in first_stage and f not in kernels_]
    res = {f: judge(f, db_names) for f in files}
    shim_ok = any(res[f][0] == FW and re.search(r"(?i)shim|BOOTX64", f) for f in first_stage)
    direct_ok = any(res[f][0] == FW and re.search(r"(?i)grub", f) for f in first_stage)
    problems = []
    if not first_stage:
        problems.append("no first-stage EFI program found")
    elif not (shim_ok or direct_ok):
        problems.append("nothing the firmware itself would start: no Microsoft-signed shim and no GRUB signed with a key in the firmware db")
    accepted = {FW, DEBIAN} if shim_ok else {FW}
    for f in rest + kernels_:
        if res[f][0] in (NOTPE,):
            continue
        if res[f][0] not in accepted:
            problems.append(f"{os.path.basename(f)}: {res[f][2]}")
    if not kernels_:
        problems.append("kernel not checked")
    return res, problems


# ------------------------------------------------------------------------------------------------ firmware boot entries
def parse_boot_entries(text):
    """`efibootmgr -v` -> [{'num','label','partuuid','file'}] for entries that start an EFI file on a GPT partition."""
    out = []
    for line in text.splitlines():
        m = re.match(r"^Boot([0-9A-Fa-f]{4})\*?\s+(.*?)\t.*?HD\(\d+,GPT,([0-9a-fA-F-]{36}),[^)]*\)/File\(([^)]*)\)", line)
        if m:
            out.append({"num": m.group(1), "label": m.group(2).strip(), "partuuid": m.group(3).lower(), "file": m.group(4)})
    return out


def judge_entry(entry, esp_roots, db_names):
    """What Secure Boot does with one firmware entry: the FIRMWARE itself must be able to verify the file the entry starts."""
    root = esp_roots.get(entry["partuuid"])
    if not root:
        return ("unknown", "its EFI partition was not read")
    path = os.path.join(root, entry["file"].replace("\\", "/").lstrip("/"))
    if not os.path.exists(path):
        # FAT is case-insensitive; try a case-insensitive walk before giving up
        d, f = os.path.split(path)
        hit = next((x for x in os.listdir(d) if x.lower() == f.lower()), None) if os.path.isdir(d) else None
        if not hit:
            return ("missing", "the file this entry starts does not exist")
        path = os.path.join(d, hit)
    cat, signer, text = judge(path, db_names)
    if cat == FW:
        return ("ok", text)
    if cat == DEBIAN:
        return ("FAIL", "starts a program signed only by Debian's key: the firmware refuses it. Point the entry at the shim (shimx64.efi) in the same folder")
    return ("FAIL", "starts a program the firmware cannot verify (" + text + ")")


# ------------------------------------------------------------------------------------------------ mounting
class Mounts:
    def __init__(self):
        self.dirs = []

    def ro(self, uuid_or_dev):
        dev = uuid_or_dev
        if re.fullmatch(r"[0-9A-Fa-f-]{8,}", uuid_or_dev):
            r = run(["blkid", "-U", uuid_or_dev])
            dev = r.stdout.strip()
            if not dev:
                return None
        existing = run(["findmnt", "-rn", "-S", dev, "-o", "TARGET"]).stdout.split()
        if existing:
            return existing[0]
        if os.geteuid() != 0:
            return None
        d = tempfile.mkdtemp(prefix="sbpre.")
        r = run(["mount", "-o", "ro,noexec,nosuid,nodev", dev, d])
        if r.returncode != 0:
            os.rmdir(d)
            return None
        self.dirs.append(d)
        return d

    def cleanup(self):
        for d in self.dirs:
            run(["umount", d])
            try:
                os.rmdir(d)
            except OSError:
                pass


def efi_files(root):
    out = []
    for base, _dirs, files in os.walk(os.path.join(root, "EFI")):
        for f in files:
            if f.lower().endswith(".efi"):
                out.append(os.path.join(base, f))
    return sorted(out)


def kernels(*dirs):
    out = []
    for d in dirs:
        if d and os.path.isdir(d):
            out += [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.startswith("vmlinuz")]
    return out


# ------------------------------------------------------------------------------------------------ LUKS
def parse_luks_dump(text):
    """`cryptsetup luksDump` output -> {'version', 'keyslots', 'tokens'} (LUKS1 and LUKS2)."""
    version = re.search(r"^Version:\s+(\d+)", text, re.M)
    v = int(version.group(1)) if version else 0
    if v == 1:
        slots = len(re.findall(r"^Key Slot \d+: ENABLED", text, re.M))
        tokens = []
    else:
        slots = len(re.findall(r"^\s+\d+: luks2\s*$", text.split("Keyslots:")[1].split("Tokens:")[0], re.M)) if "Keyslots:" in text else 0
        tok = text.split("Tokens:")[1].split("Digests:")[0] if "Tokens:" in text else ""
        tokens = re.findall(r"^\s+\d+: (\S+)\s*$", tok, re.M)
    return {"version": v, "keyslots": slots, "tokens": tokens}


def luks_report():
    say("\n== ENCRYPTED VOLUMES")
    have = {t: shutil.which(t) for t in ("cryptsetup", "systemd-cryptenroll", "sbctl", "tpm2_getcap")}
    say("  tools: " + ", ".join(f"{t}={'yes' if p else 'MISSING'}" for t, p in have.items()))
    if not have["cryptsetup"]:
        say("  cryptsetup is not installed here: sudo apt install cryptsetup  (needed to read LUKS headers and add a TPM key)")
        return
    if os.geteuid() != 0:
        say("  Run with sudo to read the LUKS headers.")
        return
    for label, uuid in LUKS.items():
        dev = run(["blkid", "-U", uuid]).stdout.strip()
        if not dev:
            say(f"  {label}: not attached")
            continue
        info = parse_luks_dump(run(["cryptsetup", "luksDump", dev]).stdout)
        tpm = any("tpm2" in t for t in info["tokens"])
        say(f"  {label}: LUKS{info['version']}, {info['keyslots']} key slot(s), tokens: {', '.join(info['tokens']) or 'none'}"
            f"{'  (already has a TPM key)' if tpm else ''}")


# ------------------------------------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--files", nargs="+", help="check only these files")
    args = ap.parse_args()
    if not shutil.which("openssl"):
        say("openssl is needed to read signatures: sudo apt install openssl")
        return 1
    db = firmware_report()
    if args.files:
        say("\n== FILES")
        for f in args.files:
            say(f"  {judge(f, db)[2]:<98} {f}")
        return 0
    tpm_report()

    mounts = Mounts()
    verdict = {}
    esp_roots = {}
    entry_problems = []
    try:
        say("\n== BOOT PROGRAMS (what each OS starts with)")
        targets = {
            "Debian": (ESPS["Debian"], ["/boot"]),
            "SWARM OS": (ESPS["SWARM OS"], ["/mnt/swarm/@/boot"]),
            "Recovery OS": (ESPS["Recovery OS"], []),
        }
        for osname, (esp_uuid, kdirs) in targets.items():
            say(f"\n  -- {osname} (EFI partition {esp_uuid})")
            root = mounts.ro(esp_uuid)
            if root:
                dev = run(["blkid", "-U", esp_uuid]).stdout.strip()
                pu = run(["blkid", "-s", "PARTUUID", "-o", "value", dev]).stdout.strip().lower() if dev else ""
                if pu:
                    esp_roots[pu] = root
            files = []
            if root and os.access(os.path.join(root, "EFI"), os.R_OK):
                files += efi_files(root)
            else:
                say("     (cannot read this EFI partition: run with sudo)")
            if osname == "Recovery OS":
                t7 = mounts.ro("71287bbf-81bf-4074-9619-4180b5a15742")  # the installed Recovery OS root (btrfs)
                if t7:
                    kdirs = [os.path.join(t7, "boot"), os.path.join(t7, "@/boot")]
                else:
                    say("     (Recovery OS root not mounted: its kernel was not checked)")
            files += kernels(*kdirs)
            esp_read = bool(root and os.access(os.path.join(root, "EFI"), os.R_OK))
            res, problems = os_verdict(files, db)
            for f in files:
                cat, _signer, text = res[f]
                mark = {FW: "OK ", DEBIAN: "ok ", UNSIGNED: "!! ", OTHER: "!! "}.get(cat, "   ")
                rel = f.replace(root + "/", "") if root and f.startswith(root) else f
                say(f"     {mark}{rel}: {text}")
            unsigned_kernel = [f for f in files if "/vmlinuz" in f and res[f][0] == UNSIGNED]
            if unsigned_kernel:
                verdict[osname] = "WOULD NOT BOOT with Secure Boot on: the kernel is unsigned" + ("" if esp_read else " (EFI partition not read: run with sudo for the rest)")
            elif not files:
                verdict[osname] = "cannot tell (nothing could be read: run with sudo)"
            elif not esp_read:
                verdict[osname] = "INCOMPLETE: EFI partition not read (run with sudo); the kernels that were read are signed"
            else:
                real = [p for p in problems if p != "kernel not checked"]
                verdict[osname] = ("WOULD NOT BOOT with Secure Boot on: " + "; ".join(real)) if real else (
                    "looks bootable with Secure Boot on" + (" (kernel not checked)" if problems else ""))
        say("\n== FIRMWARE BOOT ENTRIES (what the firmware starts: this is what Secure Boot judges first)")
        if shutil.which("efibootmgr"):
            entries = parse_boot_entries(run(["efibootmgr", "-v"]).stdout)
            order = re.search(r"BootOrder:\s*(\S+)", run(["efibootmgr"]).stdout)
            say(f"  BootOrder: {order.group(1) if order else '?'}")
            for e in entries:
                state, why = judge_entry(e, esp_roots, db)
                say(f"  {'OK  ' if state == 'ok' else 'FAIL' if state == 'FAIL' else '??  '} Boot{e['num']} {e['label']:<22} {e['file']}: {why}")
                if state == "FAIL":
                    entry_problems.append(e["label"])
        else:
            say("  efibootmgr is not installed.")
        luks_report()
    finally:
        mounts.cleanup()
    say("\n== VERDICT (from the files above; the firmware is the final judge)")
    for k, v in verdict.items():
        say(f"  {k:12} {v}")
    if entry_problems:
        say(f"  FIRMWARE ENTRIES that would fail with Secure Boot on: {', '.join(entry_problems)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
