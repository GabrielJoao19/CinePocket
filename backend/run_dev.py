"""HTTPS local. O certificado gerado precisa ser confiado no cliente/dispositivo."""
import os
import secrets
import subprocess
from pathlib import Path

import uvicorn
from backend.app import create_app

if __name__ == '__main__':
    directory = Path('backend/.certs')
    directory.mkdir(parents=True, exist_ok=True)
    key, cert, signing = (directory / name for name in ('key.pem', 'cert.pem', 'jwt.key'))
    if not cert.exists() or not key.exists():
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
            '-keyout', str(key), '-out', str(cert), '-days', '30', '-subj', '/CN=localhost',
            '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1,IP:10.0.2.2',
            '-addext', 'basicConstraints=critical,CA:TRUE'], check=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        key.chmod(0o600)
    if not signing.exists():
        signing.write_text(secrets.token_urlsafe(48))
        signing.chmod(0o600)
    app = create_app(jwt_secret=os.environ.get('JWT_SECRET') or signing.read_text().strip())
    print('API HTTPS local: https://localhost:8443. Confie no certificado backend/.certs/cert.pem no cliente.')
    uvicorn.run(app, host='127.0.0.1', port=8443, ssl_keyfile=str(key), ssl_certfile=str(cert),
                proxy_headers=False, access_log=False)
