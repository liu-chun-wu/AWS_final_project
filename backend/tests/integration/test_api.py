"""
Integration tests for all API endpoints.

Tests the complete API surface without mocking, verifying that
all endpoints exist and respond appropriately.
"""

import pytest
from src.app import create_app


@pytest.fixture
def client():
    """Create a test client for the Flask application."""
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_all_endpoints_exist(client):
    """Test that all expected endpoints exist and are routable."""
    # Test health endpoint (should always work)
    response = client.get('/health')
    assert response.status_code == 200

    # Test generate-image endpoint exists
    response = client.post('/generate-image', json={})
    assert response.status_code != 404

    # Test generate-audio endpoint exists
    response = client.post('/generate-audio', json={})
    assert response.status_code != 404

    # Test audio-callback endpoint exists
    response = client.post('/audio-callback', json={})
    assert response.status_code != 404

    # Test history endpoint exists
    response = client.get('/history')
    # May be 200 or 400 depending on validation, but not 404
    assert response.status_code != 404


def test_health_check_integration(client):
    """Integration test for health check endpoint."""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'ok'
    assert data['service'] == 'production-backend'


def test_invalid_http_methods(client):
    """Test that endpoints reject invalid HTTP methods."""
    # Health should only accept GET
    assert client.post('/health').status_code == 405
    assert client.put('/health').status_code == 405
    assert client.delete('/health').status_code == 405

    # Generate endpoints should only accept POST
    assert client.get('/generate-image').status_code == 405
    assert client.get('/generate-audio').status_code == 405
    assert client.get('/audio-callback').status_code == 405

    # History should only accept GET
    assert client.post('/history').status_code == 405
    assert client.put('/history').status_code == 405
    assert client.delete('/history').status_code == 405


def test_json_response_format(client):
    """Test that all endpoints return proper JSON responses."""
    # Health endpoint
    response = client.get('/health')
    assert response.content_type == 'application/json'
    assert response.get_json() is not None

    # Generate-image with missing data (should return JSON error)
    response = client.post('/generate-image', json={})
    assert response.content_type == 'application/json'
    assert response.get_json() is not None

    # History endpoint
    response = client.get('/history')
    assert response.content_type == 'application/json'
    assert response.get_json() is not None


def test_error_handling(client):
    """Test that endpoints return appropriate error responses."""
    # Generate-image with missing prompt
    response = client.post('/generate-image', json={"user_id": "test"})
    assert response.status_code == 400
    data = response.get_json()
    assert 'success' in data
    assert data['success'] == False
    assert 'error' in data

    # Generate-audio with missing prompt
    response = client.post('/generate-audio', json={"user_id": "test"})
    assert response.status_code == 400
    data = response.get_json()
    assert 'success' in data
    assert data['success'] == False
