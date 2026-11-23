"""API didática: identidade pelo JWT e favoritos persistentes por usuário."""
import os
import sqlite3
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4

import httpx
import jwt
from fastapi import Depends, FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pwdlib import PasswordHash


class Credentials(BaseModel):
    model_config = ConfigDict(extra='forbid')
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)

    @field_validator('email')
    @classmethod
    def normalize_email(cls, value):
        value = value.strip().lower()
        if value.count('@') != 1 or '.' not in value.split('@')[1] or any(c.isspace() for c in value):
            raise ValueError('E-mail inválido')
        return value


class Registration(Credentials):
    name: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=8, max_length=128)

    @field_validator('name')
    @classmethod
    def clean_name(cls, value):
        value = value.strip()
        if len(value) < 2:
            raise ValueError('Nome inválido')
        return value


class User(BaseModel):
    id: str
    name: str
    email: str


class AccessToken(BaseModel):
    access_token: str
    token_type: str = 'bearer'
    expires_in: int


class Film(BaseModel):
    id: str
    title: str = Field(min_length=1)
    year: int = Field(ge=1800, le=2200)
    rating: float = Field(ge=0, le=10)
    director: str
    description: str
    original_title: str
    duration: str
    genres: list[str]


class FavoriteInput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    movie_id: UUID


class GhibliCatalog:
    """Origem HTTPS fixa. Não envia JWT ao provedor público."""
    def __init__(self):
        self.cache = None
        self.updated = 0
        self.lock = threading.Lock()

    def __call__(self):
        with self.lock:
            if self.cache is not None and time.monotonic() - self.updated < 300:
                return self.cache
            try:
                with httpx.Client(timeout=8, follow_redirects=False) as client:
                    response = client.get('https://ghibliapi.vercel.app/films')
                    response.raise_for_status()
                    raw = response.json()
                if not isinstance(raw, list):
                    raise ValueError('Catálogo inválido')
                films = [Film(
                    id=str(UUID(row['id'])), title=row['title'],
                    year=int(row['release_date']), rating=float(row['rt_score']) / 10,
                    director=row['director'], description=row['description'],
                    original_title=row['original_title'],
                    duration=f"{int(row['running_time'])} min", genres=['Animação'],
                ).model_dump() for row in raw]
            except httpx.TimeoutException as error:
                raise HTTPException(504, 'Tempo esgotado ao consultar o catálogo') from error
            except httpx.HTTPError as error:
                raise HTTPException(503, 'Catálogo de filmes indisponível') from error
            except (ValueError, KeyError, TypeError) as error:
                raise HTTPException(502, 'Resposta inválida do catálogo de filmes') from error
            self.cache, self.updated = films, time.monotonic()
            return films


def create_app(*, db_path=None, jwt_secret=None, token_seconds=None, catalog=None):
    secret = jwt_secret if jwt_secret is not None else os.environ.get('JWT_SECRET', '')
    if len(secret.encode()) < 32:
        raise RuntimeError('Configure JWT_SECRET com pelo menos 32 bytes aleatórios no servidor.')
    ttl = token_seconds if token_seconds is not None else int(os.environ.get('JWT_TTL_SECONDS', '900'))
    if not 1 <= ttl <= 86400:
        raise RuntimeError('JWT_TTL_SECONDS deve estar entre 1 e 86400.')
    database = Path(db_path or os.environ.get('DATABASE_PATH', 'backend/data/cinepocket.sqlite3'))
    database.parent.mkdir(parents=True, exist_ok=True)
    app = FastAPI(title='CinePocket API', docs_url=None, redoc_url=None, openapi_url=None)
    origins = [x.strip() for x in os.environ.get('CORS_ORIGINS', 'http://localhost:8080').split(',') if x.strip()]
    if '*' in origins:
        raise RuntimeError('Configure origens CORS explícitas.')
    app.add_middleware(CORSMiddleware, allow_origins=origins,
                       allow_methods=['GET', 'POST', 'DELETE'],
                       allow_headers=['Authorization', 'Content-Type'], allow_credentials=False)
    passwords = PasswordHash.recommended()
    dummy_hash = passwords.hash(str(uuid4()))
    source = catalog or GhibliCatalog()

    @contextmanager
    def db():
        connection = sqlite3.connect(database, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute('PRAGMA foreign_keys = ON')
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    with db() as connection:
        connection.executescript('''
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY, name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS favorites (
                user_id TEXT NOT NULL REFERENCES users(id), movie_id TEXT NOT NULL,
                PRIMARY KEY(user_id, movie_id)
            );
        ''')
    database.chmod(0o600)

    def unauthorized():
        return HTTPException(401, 'Sessão inválida ou expirada', headers={'WWW-Authenticate': 'Bearer'})

    bearer = HTTPBearer(auto_error=False)

    def current_user(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        if credentials is None or credentials.scheme.lower() != 'bearer':
            raise unauthorized()
        try:
            claims = jwt.decode(credentials.credentials, secret, algorithms=['HS256'],
                                issuer='cinepocket-api', audience='cinepocket-app',
                                options={'require': ['sub', 'exp', 'iat', 'iss', 'aud', 'jti']})
            uid = str(UUID(claims['sub']))
        except (jwt.InvalidTokenError, ValueError, TypeError, KeyError) as error:
            raise unauthorized() from error
        with db() as connection:
            row = connection.execute('SELECT id, name, email FROM users WHERE id = ?', (uid,)).fetchone()
        if row is None:
            raise unauthorized()
        return User(**dict(row))

    AuthUser = Annotated[User, Depends(current_user)]

    @app.middleware('http')
    async def response_headers(request, call_next):
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        return response

    @app.post('/auth/register', response_model=User, status_code=201)
    def register(body: Registration):
        user = User(id=str(uuid4()), name=body.name, email=body.email)
        hashed = passwords.hash(body.password)
        try:
            with db() as connection:
                connection.execute('INSERT INTO users VALUES (?, ?, ?, ?)',
                                   (user.id, user.name, user.email, hashed))
        except sqlite3.IntegrityError as error:
            raise HTTPException(409, 'E-mail já cadastrado') from error
        return user

    @app.post('/auth/login', response_model=AccessToken)
    def login(body: Credentials):
        with db() as connection:
            row = connection.execute('SELECT id, password_hash FROM users WHERE email = ?', (body.email,)).fetchone()
        valid = passwords.verify(body.password, row['password_hash'] if row else dummy_hash)
        if row is None or not valid:
            raise HTTPException(401, 'E-mail ou senha inválidos', headers={'WWW-Authenticate': 'Bearer'})
        now = datetime.now(timezone.utc)
        token = jwt.encode({'sub': row['id'], 'iat': now, 'exp': now + timedelta(seconds=ttl),
                            'iss': 'cinepocket-api', 'aud': 'cinepocket-app', 'jti': str(uuid4())},
                           secret, algorithm='HS256')
        return AccessToken(access_token=token, expires_in=ttl)

    @app.get('/me', response_model=User)
    def me(user: AuthUser):
        return user

    @app.get('/movies', response_model=list[Film])
    def movies(user: AuthUser, q: str = Query(default='', max_length=150)):
        return [film for film in source() if q.casefold() in film['title'].casefold()]

    @app.get('/favorites', response_model=list[Film])
    def favorites(user: AuthUser):
        with db() as connection:
            ids = {row['movie_id'] for row in connection.execute(
                'SELECT movie_id FROM favorites WHERE user_id = ?', (user.id,))}
        if not ids:
            return []
        return [film for film in source() if film['id'] in ids]

    @app.post('/favorites', status_code=204)
    def add_favorite(body: FavoriteInput, user: AuthUser):
        movie_id = str(body.movie_id)
        if not any(film['id'] == movie_id for film in source()):
            raise HTTPException(404, 'Filme não encontrado')
        with db() as connection:
            connection.execute('INSERT OR IGNORE INTO favorites VALUES (?, ?)', (user.id, movie_id))
        return Response(status_code=204)

    @app.delete('/favorites/{movie_id}', status_code=204)
    def remove_favorite(movie_id: UUID, user: AuthUser):
        with db() as connection:
            connection.execute('DELETE FROM favorites WHERE user_id = ? AND movie_id = ?',
                               (user.id, str(movie_id)))
        return Response(status_code=204)

    return app
