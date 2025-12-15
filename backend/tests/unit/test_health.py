"""
Unit tests for the /health endpoint.

Tests the health check endpoint in isolation using Flask test client.
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


def test_health_endpoint_returns_200(client):
    """Test that /health returns HTTP 200 status code."""
    response = client.get('/health')
    assert response.status_code == 200


def test_health_endpoint_returns_json(client):
    """Test that /health returns JSON content type."""
    response = client.get('/health')
    assert response.content_type == 'application/json'


def test_health_endpoint_returns_expected_structure(client):
    """Test that /health returns correct JSON structure with required fields."""
    response = client.get('/health')
    data = response.get_json()

    # Verify required fields exist
    assert 'status' in data
    assert 'service' in data


def test_health_endpoint_returns_correct_values(client):
    """Test that /health returns expected values."""
    response = client.get('/health')
    data = response.get_json()

    # Verify field values
    assert data['status'] == 'ok'


def test_health_endpoint_only_accepts_get(client):
    """Test that /health only accepts GET requests."""
    # POST should not be allowed
    response = client.post('/health')
    assert response.status_code == 405  # Method Not Allowed

    # PUT should not be allowed
    response = client.put('/health')
    assert response.status_code == 405

    # DELETE should not be allowed
    response = client.delete('/health')
    assert response.status_code == 405
