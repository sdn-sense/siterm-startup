#!/usr/bin/env python3
"""Install the JWT signing key pair into RSA_DIR: split frontends share it through the database, else generated once."""
import grp
import os
import pwd
import sys
import time

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from SiteRMLibs.DBState import getStateDB, loadOrCreateJWTKey

# Get UID and GID for Apache user and group (as long as we use apache)
APACHE_USER = os.getenv("APACHE_USER", "apache")
APACHE_GROUP = os.getenv("APACHE_GROUP", "apache")
uid = pwd.getpwnam(APACHE_USER).pw_uid
gid = grp.getgrnam(APACHE_GROUP).gr_gid

# Read environment variables for all key and save directory parameters
key_size = int(os.getenv("RSA_KEY_SIZE", "3072"))
public_exponent = int(os.getenv("RSA_PUBLIC_EXPONENT", "65537"))
save_dir = os.getenv("RSA_DIR", "/opt/siterm/jwt_secrets")
private_key_path = os.path.join(save_dir, "private_key.pem")
public_key_path = os.path.join(save_dir, "public_key.pem")


def generatePrivatePem():
    """Return a new RSA private key as PKCS8 PEM text."""
    key = rsa.generate_private_key(public_exponent=public_exponent, key_size=key_size)
    return key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")


def writeFile(path, data, mode):
    """Atomically write data to path, owned by the apache user."""
    tmpPath = path + ".tmp"
    with open(tmpPath, "wb") as fd:
        fd.write(data)
    os.chown(tmpPath, uid, gid)
    os.chmod(tmpPath, mode)
    os.replace(tmpPath, path)


def installKeyPair(privatePem):
    """Write the private key, then its public key, into RSA_DIR."""
    key = serialization.load_pem_private_key(privatePem.encode("utf-8"), password=None)
    # Private first: Auth refuses to start until both exist, so a present public key means a complete pair.
    print("Saving private key to:", private_key_path)
    writeFile(private_key_path, privatePem.encode("utf-8"), 0o600)
    print("Saving public key to:", public_key_path)
    publicPem = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    writeFile(public_key_path, publicPem, 0o644)


def sharedPrivatePem():
    """Return the key shared by all frontend replicas; the first frontend to start stores it in the database."""
    attempt = 0
    while True:
        attempt += 1
        try:
            return loadOrCreateJWTKey(getStateDB(), generatePrivatePem)
        except Exception as ex:  # pylint: disable=broad-except
            # The frontend cannot serve without the key or the database: keep waiting, like httpd.sh does.
            # Log only the driver error: SQLAlchemy errors embed the statement parameters (the key) in their text.
            reason = getattr(ex, "orig", None) or type(ex).__name__
            print(f"Unable to load JWT signing key from the database (attempt {attempt}): {reason}. Retrying in 10s.")
            time.sleep(10)


os.makedirs(save_dir, exist_ok=True)
os.chown(save_dir, uid, gid)
os.chmod(save_dir, 0o700)

# Split frontends (any number of replicas) sign with one key that lives in the database; RSA_DIR is only a local copy.
if os.getenv("SITERM_COMPONENT") == "frontend":
    print("Loading JWT signing key shared through the database.")
    installKeyPair(sharedPrivatePem())
    sys.exit(0)

# Check if private key or public key already exists
if os.path.exists(private_key_path) and os.path.exists(public_key_path):
    print("Private key and public key already exist. Skipping key generation.")
    sys.exit(0)

if os.path.exists(private_key_path) != os.path.exists(public_key_path):
    raise RuntimeError("Key material incomplete; manual intervention required")

print("Generating new RSA key pair...")
installKeyPair(generatePrivatePem())
print("RSA key pair generation completed.")
