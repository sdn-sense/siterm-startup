#!/usr/bin/env python3
"""
Build a minimal CA truststore from /etc/grid-security/certificates

Accepted issuers are defined in the git repository:
  - /C=US/O=Let's Encrypt/CN=R*
  - /C=US/O=Internet2/CN=InCommon RSA Server CA 2
  - /C=US/O=Internet2/CN=InCommon RSA IGTF Server CA 3
  - CERN Grid CAs

Site's can override it by placing allowed_truststore.yaml in the container's /etc/grid-security/ directory.
"""

import os
import re
import shutil
import warnings
from datetime import timezone
import yaml
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.utils import CryptographyDeprecationWarning

# Silence legacy Grid CA warnings (negative serials, etc.)
warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

GRID_CA_DIR = "/etc/grid-security/certificates"
OUT_DIR = "/etc/grid-security/truststore/"

# -------------------------------
# Allowed issuer DN patterns
# -------------------------------
ALLOWED_ISSUER_PATTERNS = [
    re.compile(r"^/C=US/O=Let's Encrypt/CN=R\d+$"),
    re.compile(r"^/C=US/O=Internet2/CN=InCommon RSA Server CA 2$"),
    re.compile(r"^/C=US/O=Internet2/CN=InCommon RSA IGTF Server CA 3$"),
    re.compile(r"^/DC=ch/DC=cern/CN=CERN Grid Certification Authority$"),
    re.compile(r"^/C=ch/O=CERN/CN=CERN Root Certification Authority 2$"),
]
ALLOWED_TRUSTSTORE_FILE = "/etc/grid-security/allowed_truststore.yaml"
if os.path.exists(ALLOWED_TRUSTSTORE_FILE):
    with open(ALLOWED_TRUSTSTORE_FILE, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
        for pattern in data.get("allowed_issuers", []):
            ALLOWED_ISSUER_PATTERNS.append(re.compile(pattern))

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


def issuer_allowed(issuer_dn: str) -> bool:
    """Check issuer DN against allow-list."""
    return any(p.match(issuer_dn) for p in ALLOWED_ISSUER_PATTERNS)


def fmt_time(ts):
    """Format datetime consistently in UTC."""
    return ts.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def build_truststore():
    os.makedirs(OUT_DIR, exist_ok=True)

    copied = 0
    unmatched = []

    for fname in sorted(os.listdir(GRID_CA_DIR)):
        if not fname.endswith(".pem"):
            continue
        path = os.path.join(GRID_CA_DIR, fname)
        try:
            with open(path, "rb") as fd:
                cert = x509.load_pem_x509_certificate(fd.read())
            try:
                bc = cert.extensions.get_extension_for_class(
                    x509.BasicConstraints
                ).value
                if not bc.ca:
                    continue
            except Exception:
                continue

            issuer_dn = name_to_openssl(cert.subject)
            not_before = cert.not_valid_before_utc
            not_after = cert.not_valid_after_utc

            if issuer_allowed(issuer_dn):
                shutil.copy2(path, OUT_DIR)
                copied += 1
                print(f"[ACCEPTED] {issuer_dn}")
                print(f"    Valid from : {fmt_time(not_before)}")
                print(f"    Valid until: {fmt_time(not_after)}")
            else:
                unmatched.append((issuer_dn, not_before, not_after))

        except Exception as exc:
            print(f"Skipping {fname}: {exc}")

    if unmatched:
        print("\n[REJECTED] Unmatched CA issuers (review & add if needed):")
        for issuer_dn, nb, na in sorted(unmatched):
            print(f"  {issuer_dn}")
            print(f"      Valid from : {fmt_time(nb)}")
            print(f"      Valid until: {fmt_time(na)}")

    print(f"\nCopied {copied} CA certificates into {OUT_DIR}")


if __name__ == "__main__":
    build_truststore()
