"""
Unit tests for the /generate-audio endpoint.

Tests audio generation endpoint with mocked external dependencies.
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


def test_generate_audio_missing_prompt(client):
    """Test that /generate-audio returns 400 when prompt is missing."""
    response = client.post('/generate-audio', json={
        "user_id": "test_user"
    })
    assert response.status_code == 400
    data = response.get_json()
    assert data['success'] == False
    assert 'error' in data


def test_generate_audio_endpoint_exists(client):
    """Test that /generate-audio endpoint exists and accepts POST."""
    response = client.post('/generate-audio', json={})
    # Should not be 404 (Not Found) - endpoint exists
    # Will likely be 400 or 500 due to missing prompt/tokens
    assert response.status_code != 404


def test_generate_audio_only_accepts_post(client):
    """Test that /generate-audio only accepts POST requests."""
    # GET should not be allowed
    response = client.get('/generate-audio')
    assert response.status_code == 405  # Method Not Allowed

    # PUT should not be allowed
    response = client.put('/generate-audio')
    assert response.status_code == 405

    # DELETE should not be allowed
    response = client.delete('/generate-audio')
    assert response.status_code == 405
