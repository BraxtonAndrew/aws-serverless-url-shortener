import app 
import json
from unittest.mock import MagicMock


def test_unknown_route_returns_404():
    # Arrange a fake request
    event = {"routeKey": "DELETE /banana"}

    # Act by running the real handler
    response = app.lambda_handler({"routeKey": event}, None)

    # Assert the result
    assert response["statusCode"] == 404



def test_create_link_returns_201(monkeypatch):
    fake_table = MagicMock()
    monkeypatch.setattr(app, "table", fake_table)

    event = {
        "routeKey": "POST /links",
        "body": json.dumps({"url": "https://github.com"})
    }

    response = app.lambda_handler(event, None)

    assert response["statusCode"] == 201
    fake_table.put_item.assert_called_once()


def test_create_link_invalid_body_returns_400():
    event = {
        "routeKey": "POST /links",
        "body": "banana"
    }

    response = app.lambda_handler(event, None)

    assert response["statusCode"] == 400


def test_redirect_existing_code_returns_301(monkeypatch):
    fake_table = MagicMock()
    fake_table.get_item.return_value = {"Item": {"short_code": "abc123", "long_url": "https://github.com"}}
    monkeypatch.setattr(app, "table", fake_table)

    event = {
        "routeKey": "GET /{code}",
        "pathParameters": {"code": "abc123"}
    }

    response = app.lambda_handler(event, None)

    assert response["statusCode"] == 301
    assert response["headers"]["Location"] == "https://github.com" #might be long_url instead of Location tho


def test_redirect_missing_code_returns_404(monkeypatch):
    fake_table = MagicMock()
    fake_table.get_item.return_value = {}
    monkeypatch.setattr(app, "table", fake_table)

    event = {
        "routeKey": "GET /{code}",
        "pathParameters": {"code": "abc123"}
    }

    response = app.lambda_handler(event, None)

    assert response["statusCode"] == 404
    