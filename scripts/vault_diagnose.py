# -*- coding: utf-8 -*-
"""密码保险箱解密诊断脚本

用法:
    python scripts/vault_diagnose.py <导出JSON路径> <主密码>

说明:
    读取完整导出 JSON（须含 vault_master 与 vault_entries），
    用主密码 + salt 派生 Argon2id 密钥，逐条尝试 AES-256-GCM 解密，
    输出每条密码条目是否可解密，帮助定位「解密后密码为空」的问题。
"""
import json
import sys
from cryptography.hazmat.primitives.kdf.argon2 import Argon2id
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

VERIFY_PLAINTEXT = "VAULT_VERIFIED_OK"
KDF_MEMORY = 65536   # 64 MB
KDF_ITER = 3
KDF_LANES = 1
KDF_LEN = 32


def derive_key(master_password: str, salt_hex: str) -> bytes:
    salt = bytes.fromhex(salt_hex)
    kdf = Argon2id(
        salt=salt,
        length=KDF_LEN,
        memory_cost=KDF_MEMORY,
        iterations=KDF_ITER,
        lanes=KDF_LANES,
    )
    return kdf.derive(master_password.encode("utf-8"))


def aes_gcm_decrypt(cipher_hex: str, iv_hex: str, key: bytes) -> str:
    aesgcm = AESGCM(key)
    data = bytes.fromhex(cipher_hex)
    iv = bytes.fromhex(iv_hex)
    return aesgcm.decrypt(iv, data, None).decode("utf-8")


def main() -> None:
    if len(sys.argv) != 3:
        print("用法: python scripts/vault_diagnose.py <导出JSON路径> <主密码>")
        sys.exit(1)

    json_path, master_password = sys.argv[1], sys.argv[2]
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 兼容两种结构：顶层 vault_master 或 data.vault_master
    if "vault_master" not in data and isinstance(data.get("data"), dict):
        data = data["data"]
    master = data.get("vault_master")
    if master is None:
        print("[-] 导出 JSON 中未找到 vault_master（缺少 salt，无法派生密钥）")
        sys.exit(1)

    salt = master.get("salt", "")
    verify_cipher = master.get("verify_cipher", "")
    verify_iv = master.get("verify_iv", "")

    key = derive_key(master_password, salt)
    print("[*] 已用主密码派生密钥 (salt 前8位: %s)" % salt[:8])

    # 1) 验证主密码
    try:
        result = aes_gcm_decrypt(verify_cipher, verify_iv, key)
        if result == VERIFY_PLAINTEXT:
            print("[OK] 主密码验证通过 (verify_cipher 解密成功)")
        else:
            print("[!!] 主密码验证失败: 解密结果不匹配 (%r)" % result)
    except Exception as e:
        print("[!!] 主密码验证失败: %s" % e)

    # 2) 逐条解密
    entries = data.get("vault_entries", [])
    if not entries:
        print("[-] 导出 JSON 中未找到 vault_entries")
    for entry in entries:
        title = entry.get("title", "")
        cipher = entry.get("encrypted_password", "")
        iv = entry.get("password_iv", "")
        try:
            plain = aes_gcm_decrypt(cipher, iv, key)
            print("[OK] 可解密: %s -> %s" % (title, plain))
        except Exception as e:
            print("[失败] 无法解密: %s (密钥不匹配或数据损坏)" % title)


if __name__ == "__main__":
    main()

