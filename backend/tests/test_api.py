import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from backend.app import create_app

FILM_ID = '2baf70d1-42bb-4437-b551-e5fed5a87abe'
FILMS = [dict(id=FILM_ID, title='Castle in the Sky', year=1986, rating=9.5,
              director='Hayao Miyazaki', description='A flying castle.',
              original_title='天空の城ラピュタ', duration='124 min', genres=['Animação'])]


@pytest.fixture
def setup(tmp_path):
    secret = secrets.token_urlsafe(48)
    database = tmp_path / 'test.sqlite3'
    app = create_app(db_path=database, jwt_secret=secret, catalog=lambda: FILMS)
    with TestClient(app, base_url='https://testserver') as client:
        yield client, database, secret


def account(client, email):
    response = client.post('/auth/register', json={'name': email.split('@')[0], 'email': email, 'password': 'test-password-123'})
    assert response.status_code == 201
    assert 'password_hash' not in response.json()
    login = client.post('/auth/login', json={'email': email, 'password': 'test-password-123'})
    assert login.status_code == 200
    return response.json(), {'Authorization': 'Bearer ' + login.json()['access_token']}


def test_login_queries_and_favorites_are_isolated_and_persist(setup):
    client, database, secret = setup
    alice, a = account(client, 'alice@example.test')
    bob, b = account(client, 'bob@example.test')
    assert client.get('/me', headers=a).json()['id'] == alice['id']
    assert client.get('/me', headers=b).json()['id'] == bob['id']
    assert client.get('/movies', headers=a).json() == FILMS
    assert client.get('/movies?q=castle', headers=a).json() == FILMS
    assert client.get('/movies?q=missing', headers=a).json() == []
    assert client.post('/favorites', headers=a, json={'movie_id': FILM_ID}).status_code == 204
    assert client.post('/favorites', headers=a, json={'movie_id': FILM_ID}).status_code == 204
    assert client.get('/favorites', headers=a).json() == FILMS
    assert client.get('/favorites', headers=b).json() == []
    # B cannot remove A's relation, even when the movie ID is known.
    assert client.delete('/favorites/' + FILM_ID, headers=b).status_code == 204
    assert client.get('/favorites', headers=a).json() == FILMS
    # A fresh server instance and new login see the persisted collection.
    with TestClient(create_app(db_path=database, jwt_secret=secret, catalog=lambda: FILMS), base_url='https://testserver') as reopened:
        login = reopened.post('/auth/login', json={'email': alice['email'], 'password': 'test-password-123'})
        again = {'Authorization': 'Bearer ' + login.json()['access_token']}
        assert reopened.get('/favorites', headers=again).json() == FILMS
        assert reopened.delete('/favorites/' + FILM_ID, headers=again).status_code == 204
        assert reopened.get('/favorites', headers=again).json() == []
    with sqlite3.connect(database) as db:
        hashed = db.execute('SELECT password_hash FROM users WHERE id = ?', (alice['id'],)).fetchone()[0]
    assert hashed.startswith('$argon2id$') and 'test-password' not in hashed


@pytest.mark.parametrize('path', ['/me', '/movies', '/favorites'])
def test_no_token_is_401(setup, path):
    assert setup[0].get(path).status_code == 401


def test_expired_tampered_wrong_issuer_and_audience_tokens_are_rejected(setup):
    client, _, secret = setup
    user, _ = account(client, 'alice@example.test')
    now = datetime.now(timezone.utc)
    good = dict(sub=user['id'], iat=now, exp=now + timedelta(minutes=5),
                iss='cinepocket-api', aud='cinepocket-app', jti=str(uuid4()))
    variants = [({**good, 'exp': now - timedelta(minutes=1)}, secret),
                ({**good, 'iss': 'other'}, secret), ({**good, 'aud': 'other'}, secret),
                (good, secrets.token_urlsafe(48)), ({k: v for k, v in good.items() if k != 'exp'}, secret)]
    for claims, signing in variants:
        token = jwt.encode(claims, signing, algorithm='HS256')
        assert client.get('/favorites', headers={'Authorization': 'Bearer ' + token}).status_code == 401
    assert client.get('/movies', headers={'Authorization': 'Bearer invalid'}).status_code == 401


def test_invalid_credentials_and_registration(setup):
    client, _, _ = setup
    account(client, 'alice@example.test')
    assert client.post('/auth/login', json={'email': 'alice@example.test', 'password': 'wrong'}).status_code == 401
    assert client.post('/auth/login', json={'email': 'nobody@example.test', 'password': 'wrong'}).status_code == 401
    assert client.post('/auth/register', json={'name': 'Alice', 'email': 'ALICE@example.test', 'password': 'test-password-123'}).status_code == 409
    assert client.post('/auth/register', json={'name': 'Alice', 'email': 'alice2@example.test', 'password': 'short'}).status_code == 422
    assert client.post('/auth/login', content='not-json', headers={'Content-Type': 'application/json'}).status_code == 422


def test_client_cannot_choose_favorite_owner(setup):
    client, _, _ = setup
    alice, a = account(client, 'alice@example.test')
    _, b = account(client, 'bob@example.test')
    assert client.post('/favorites', headers=b, json={'movie_id': FILM_ID, 'user_id': alice['id']}).status_code == 422
    assert client.post('/favorites', headers=a, json={'movie_id': str(uuid4())}).status_code == 404
    assert client.post('/favorites', json={'movie_id': FILM_ID}).status_code == 401
    assert client.delete('/favorites/' + FILM_ID).status_code == 401


def test_catalog_unavailable_is_not_authentication_failure(tmp_path):
    def unavailable():
        raise HTTPException(503, 'Catálogo indisponível')
    app = create_app(db_path=tmp_path / 'error.sqlite3', jwt_secret=secrets.token_urlsafe(48), catalog=unavailable)
    with TestClient(app, base_url='https://testserver') as client:
        _, headers = account(client, 'alice@example.test')
        assert client.get('/movies', headers=headers).status_code == 503
        assert client.get('/me', headers=headers).status_code == 200
