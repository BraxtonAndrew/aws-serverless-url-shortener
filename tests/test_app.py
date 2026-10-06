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



def test_create_link_returns_201():