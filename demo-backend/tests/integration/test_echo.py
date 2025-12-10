"""
Integration tests for the /echo endpoint.

Tests the full request/response cycle for the echo endpoint,
including valid payloads, invalid JSON, and error handling.
"""

import pytest
import json
from src.app import create_app


@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_echo_returns_200_with_valid_json(client):
    """Test that /echo returns HTTP 200 with valid JSON payload."""
    test_payload = {"message": "hello", "count": 42}
    response = client.post('/echo', json=test_payload)
    assert response.status_code == 200


def test_echo_returns_json_content_type(client):
    """Test that /echo returns JSON content type."""
    test_payload = {"test": "data"}
    response = client.post('/echo', json=test_payload)
    assert response.content_type == 'application/json'


def test_echo_returns_same_payload(client):
    """Test that /echo echoes back the exact request body."""
    test_payload = {"test": "data", "nested": {"key": "value"}}
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    # Verify response has 'body' field containing the payload
    assert 'body' in data
    assert data['body'] == test_payload


def test_echo_with_simple_payload(client):
    """Test /echo with a simple string payload."""
    test_payload = {"message": "hello world"}
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    assert data['body']['message'] == "hello world"


def test_echo_with_nested_payload(client):
    """Test /echo with nested JSON structures."""
    test_payload = {
        "user": {
            "name": "John Doe",
            "email": "john@example.com",
            "preferences": {
                "theme": "dark",
                "notifications": True
            }
        }
    }
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    assert data['body'] == test_payload


def test_echo_with_array_payload(client):
    """Test /echo with array in payload."""
    test_payload = {"items": [1, 2, 3, 4, 5], "total": 5}
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    assert data['body']['items'] == [1, 2, 3, 4, 5]


def test_echo_with_empty_json_object(client):
    """Test /echo with empty JSON object."""
    test_payload = {}
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    assert data['body'] == {}


def test_echo_handles_missing_content_type(client):
    """Test that /echo returns 400 when Content-Type is missing or invalid."""
    # Send raw data without proper Content-Type header
    response = client.post('/echo', data='{"test": "data"}')
    assert response.status_code == 400


def test_echo_handles_invalid_json(client):
    """Test that /echo returns 400 with malformed JSON."""
    # Send invalid JSON with correct Content-Type
    response = client.post('/echo',
                          data='invalid json',
                          content_type='application/json')
    assert response.status_code == 400

    # Verify error message is present
    data = response.get_json()
    assert 'error' in data


def test_echo_handles_malformed_json_structure(client):
    """Test that /echo handles various malformed JSON payloads."""
    # Missing closing brace
    response = client.post('/echo',
                          data='{"test": "data"',
                          content_type='application/json')
    assert response.status_code == 400

    # Invalid syntax
    response = client.post('/echo',
                          data='{test: data}',
                          content_type='application/json')
    assert response.status_code == 400


def test_echo_only_accepts_post(client):
    """Test that /echo only accepts POST requests."""
    # GET should not be allowed
    response = client.get('/echo')
    assert response.status_code == 405  # Method Not Allowed

    # PUT should not be allowed
    response = client.put('/echo', json={"test": "data"})
    assert response.status_code == 405

    # DELETE should not be allowed
    response = client.delete('/echo')
    assert response.status_code == 405


def test_echo_with_large_payload(client):
    """Test /echo with a reasonably large JSON payload."""
    # Create a payload with 100 items
    test_payload = {
        "items": [{"id": i, "value": f"item_{i}"} for i in range(100)],
        "count": 100
    }
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    assert len(data['body']['items']) == 100
    assert data['body']['count'] == 100


def test_echo_preserves_data_types(client):
    """Test that /echo preserves different JSON data types."""
    test_payload = {
        "string": "text",
        "integer": 42,
        "float": 3.14,
        "boolean": True,
        "null": None,
        "array": [1, 2, 3],
        "object": {"nested": "value"}
    }
    response = client.post('/echo', json=test_payload)
    data = response.get_json()

    assert response.status_code == 200
    # Verify each data type is preserved
    assert data['body']['string'] == "text"
    assert data['body']['integer'] == 42
    assert data['body']['float'] == 3.14
    assert data['body']['boolean'] is True
    assert data['body']['null'] is None
    assert data['body']['array'] == [1, 2, 3]
    assert data['body']['object'] == {"nested": "value"}
