"""
Funções de autenticação: hash de senha e geração de token.

Uso só a biblioteca padrão do Python (hashlib, secrets) de propósito —
sem depender de libs como passlib/bcrypt, que têm partes compiladas e já
nos deram dor de cabeça de instalação antes (lembra do pydantic-core?).
Pra um app pessoal, isso é mais que suficiente.
"""
import hashlib
import secrets


def gerar_hash_senha(senha: str) -> str:
    sal = secrets.token_hex(16)
    hash_ = hashlib.pbkdf2_hmac("sha256", senha.encode(), bytes.fromhex(sal), 100_000)
    return f"{sal}${hash_.hex()}"


def verificar_senha(senha: str, hash_salvo: str) -> bool:
    try:
        sal, hash_hex = hash_salvo.split("$")
    except ValueError:
        return False
    hash_ = hashlib.pbkdf2_hmac("sha256", senha.encode(), bytes.fromhex(sal), 100_000)
    return secrets.compare_digest(hash_.hex(), hash_hex)


def gerar_token() -> str:
    return secrets.token_hex(32)
