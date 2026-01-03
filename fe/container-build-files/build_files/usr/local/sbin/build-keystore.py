#!/usr/bin/env python3
"""
Build a minimal CA truststore from /etc/grid-security/certificates

Accepted issuers are defined in the git repository:
  - /C=US/O=Let's Encrypt/CN=R*
  - /C=US/O=Internet2/CN=InCommon RSA Server CA 2
  - /C=US/O=Internet2/CN=InCommon RSA IGTF Server CA 3
  - CERN Grid CAs
"""

import os
import re
import shutil
import warnings
from datetime import timezone
from typing import Dict, List, Optional, Set, Tuple

import yaml
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.utils import CryptographyDeprecationWarning

warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

GRID_CA_DIR = "/etc/grid-security/certificates"
OUT_DIR = "/etc/grid-security/truststore"

ALLOWED_ISSUER_PATTERNS = []

ALLOWED_TRUSTSTORE_FILE = "/etc/grid-security/allowed_truststore.yaml"
if os.path.exists(ALLOWED_TRUSTSTORE_FILE):
    with open(ALLOWED_TRUSTSTORE_FILE, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
        for pattern in data.get("allowed_issuers", []):
            ALLOWED_ISSUER_PATTERNS.append(re.compile(pattern))
else:
    print(f"Allowed truststore file {ALLOWED_TRUSTSTORE_FILE} does not exist, using default patterns.")
    ALLOWED_ISSUER_PATTERNS = [
        re.compile(r"^/C=US/O=Let's Encrypt/CN=R\d+$"),
        re.compile(r"^/C=US/O=Internet2/CN=InCommon RSA Server CA 2$"),
        re.compile(r"^/C=US/O=Internet2/CN=InCommon RSA IGTF Server CA 3$"),
        re.compile(r"^/DC=ch/DC=cern/CN=CERN Grid Certification Authority$"),
        re.compile(r"^/C=ch/O=CERN/CN=CERN Root Certification Authority 2$"),
    ]
print(f"Using allowed issuer patterns: {ALLOWED_ISSUER_PATTERNS}")

OID_SHORT_NAMES = {
    NameOID.COUNTRY_NAME: "C",
    NameOID.STATE_OR_PROVINCE_NAME: "ST",
    NameOID.LOCALITY_NAME: "L",
    NameOID.ORGANIZATION_NAME: "O",
    NameOID.ORGANIZATIONAL_UNIT_NAME: "OU",
    NameOID.COMMON_NAME: "CN",
    NameOID.DOMAIN_COMPONENT: "DC",
}


def name_to_openssl(name: x509.Name) -> str:
    """Convert x509.Name to OpenSSL-style DN string."""
    parts = []
    for attr in name:
        short = OID_SHORT_NAMES.get(attr.oid, attr.oid._name)
        parts.append(f"{short}={attr.value}")
    return "/" + "/".join(parts)


def dn_allowed(dn: str) -> bool:
    """Check DN against allow-list."""
    return any(p.match(dn) for p in ALLOWED_ISSUER_PATTERNS)


def fmt_time(ts):
    """Format datetime consistently in UTC."""
    return ts.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def is_ca_cert(cert: x509.Certificate) -> bool:
    """Return True if BasicConstraints CA:TRUE."""
    try:
        bc = cert.extensions.get_extension_for_class(x509.BasicConstraints).value
        return bool(bc.ca)
    except Exception:
        return False


def build_ca_index() -> Dict[str, Tuple[str, x509.Certificate]]:
    """
    Return map: subject_dn -> (path, cert)
    Only includes CA certificates.
    """
    idx: Dict[str, Tuple[str, x509.Certificate]] = {}
    for fname in sorted(os.listdir(GRID_CA_DIR)):
        if not fname.endswith(".pem"):
            continue
        path = os.path.join(GRID_CA_DIR, fname)
        try:
            with open(path, "rb") as fd:
                cert = x509.load_pem_x509_certificate(fd.read())
            if not is_ca_cert(cert):
                continue
            subject_dn = name_to_openssl(cert.subject)
            idx.setdefault(subject_dn, (path, cert))
        except Exception:
            continue
    return idx


def is_self_signed(cert: x509.Certificate) -> bool:
    """Heuristic: subject == issuer."""
    return cert.subject == cert.issuer


def chain_close(
    start_subject_dn: str,
    ca_index: Dict[str, Tuple[str, x509.Certificate]],
    selected_paths: Set[str],
    debug: bool = True,
) -> None:
    """
    Starting from a CA cert subject DN, include it and walk up issuer chain
    by matching issuer DN to another CA cert subject DN in ca_index.
    """
    cur_subject_dn = start_subject_dn
    seen_dns: Set[str] = set()

    while True:
        if cur_subject_dn in seen_dns:
            if debug:
                print(f"    [CHAIN] Loop detected at {cur_subject_dn} (stopping)")
            return
        seen_dns.add(cur_subject_dn)

        entry = ca_index.get(cur_subject_dn)
        if not entry:
            if debug:
                print(f"    [CHAIN] Missing cert for subject {cur_subject_dn} (stopping)")
            return

        path, cert = entry
        if path not in selected_paths:
            selected_paths.add(path)
            if debug:
                print(f"    [CHAIN] + {cur_subject_dn}")

        if is_self_signed(cert):
            if debug:
                print(f"    [CHAIN] Reached self-signed root {cur_subject_dn}")
            return

        issuer_dn = name_to_openssl(cert.issuer)
        cur_subject_dn = issuer_dn


def build_truststore():
    os.makedirs(OUT_DIR, exist_ok=True)

    ca_index = build_ca_index()
    if not ca_index:
        print(f"[ERROR] No CA certs found in {GRID_CA_DIR}")
        return

    allowed_subjects: List[str] = []
    rejected_subjects: List[Tuple[str, str, object, object]] = []

    for subject_dn, (path, cert) in sorted(ca_index.items()):
        issuer_dn = name_to_openssl(cert.issuer)
        nb = cert.not_valid_before_utc
        na = cert.not_valid_after_utc
        if dn_allowed(subject_dn):
            allowed_subjects.append(subject_dn)
        else:
            rejected_subjects.append((subject_dn, issuer_dn, nb, na))

    selected_paths: Set[str] = set()

    print("[INFO] Allowed CA subjects selected (will chain-close each):")
    for subject_dn in allowed_subjects:
        path, cert = ca_index[subject_dn]
        print(f"[ALLOWED] {subject_dn}")
        print(f"    Issuer     : {name_to_openssl(cert.issuer)}")
        print(f"    Valid from : {fmt_time(cert.not_valid_before_utc)}")
        print(f"    Valid until: {fmt_time(cert.not_valid_after_utc)}")
        chain_close(subject_dn, ca_index, selected_paths, debug=True)

    # Copy selected files
    copied = 0
    for path in sorted(selected_paths):
        shutil.copy2(path, OUT_DIR)
        copied += 1

    print(f"\nCopied {copied} CA certificates into {OUT_DIR}")

    # Helpful diagnostics
    if rejected_subjects:
        print("\n[INFO] Some CA subjects were not directly allowed (fine), but may still be included via chain closure.")
        # Print a small sample (not everything) to keep logs sane
        sample = rejected_subjects[:25]
        for subject_dn, issuer_dn, nb, na in sample:
            print(f"  Subject : {subject_dn}")
            print(f"  Issuer  : {issuer_dn}")
            print(f"    Valid from : {fmt_time(nb)}")
            print(f"    Valid until: {fmt_time(na)}")
        if len(rejected_subjects) > len(sample):
            print(f"  ... ({len(rejected_subjects) - len(sample)} more omitted)")


if __name__ == "__main__":
    build_truststore()
