#!/usr/bin/env python3
"""Generate a new RSA key pair"""
import os
import pwd
import grp
import sys
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization

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

os.makedirs(save_dir, exist_ok=True)
os.chown(save_dir, uid, gid)
os.chmod(save_dir, 0o700)

# A private key supplied by a mounted secret (shared by all frontend replicas) wins: install it, derive the public key.
source_private = os.path.join(os.getenv("RSA_SOURCE_DIR", "/etc/siterm-jwt"), "private_key.pem")
if os.path.isfile(source_private):
    with open(source_private, "rb") as f:
        source_pem = f.read()
    source_key = serialization.load_pem_private_key(source_pem, password=None)
    print("Installing JWT signing key from:", source_private)
    with open(private_key_path, "wb") as f:
        f.write(source_pem)
    os.chown(private_key_path, uid, gid)
    os.chmod(private_key_path, 0o600)
    with open(public_key_path, "wb") as f:
        f.write(source_key.public_key().public_bytes(encoding=serialization.Encoding.PEM, format=serialization.PublicFormat.SubjectPublicKeyInfo))
    os.chown(public_key_path, uid, gid)
    os.chmod(public_key_path, 0o644)
    sys.exit(0)

# Check if private key or public key already exists
if os.path.exists(private_key_path) and os.path.exists(public_key_path):
    print("Private key and public key already exist. Skipping key generation.")
    sys.exit(0)

if os.path.exists(private_key_path) != os.path.exists(public_key_path):
    raise RuntimeError("Key material incomplete; manual intervention required")

print("Generating new RSA key pair...")
key = rsa.generate_private_key(public_exponent=public_exponent, key_size=key_size)

private_pem = key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
)

public_pem = key.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)

os.chmod(save_dir, 0o700)
print("Saving private key to:", private_key_path)
with open(private_key_path, "wb") as f:
    f.write(private_pem)
os.chown(private_key_path, uid, gid)
os.chmod(private_key_path, 0o600)


print("Saving public key to:", public_key_path)
with open(public_key_path, "wb") as f:
    f.write(public_pem)
os.chown(public_key_path, uid, gid)
os.chmod(public_key_path, 0o644)

print("RSA key pair generation completed.")