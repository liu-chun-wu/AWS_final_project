"""
Flask REST API Demo Application

A simple Flask application with health check and echo endpoints,
designed for AWS Lambda container deployment with CloudWatch logging.

Endpoints:
- GET /health: Health check endpoint
- POST /echo: Echo endpoint that returns the request body
"""

from flask import Flask, request, jsonify
import logging
from datetime import datetime


# Configure logging for CloudWatch compatibility
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def create_app():
    """
    Application factory pattern for creating Flask app.

    Returns:
        Flask: Configured Flask application instance
    """
    app = Flask(__name__)

    @app.route('/health', methods=['GET'])
    def health():
        """
        Health check endpoint for monitoring and container orchestration.

        Returns:
            tuple: JSON response with status and service name, HTTP status code
        """
        logger.info("Health check requested")
        return jsonify({
            'status': 'ok',
            'service': 'demo-backend'
        }), 200

    @app.route('/echo', methods=['POST'])
    def echo():
        """
        Echo endpoint that returns the request body.

        Validates that the request has proper JSON content and returns
        the same payload wrapped in a 'body' field.

        Returns:
            tuple: JSON response with echoed body or error message, HTTP status code

        Error Responses:
            400: Invalid or missing JSON payload
        """
        try:
            # Validate JSON content type
            if not request.is_json:
                logger.warning(f"Invalid content type received: {request.content_type}")
                return jsonify({
                    'error': 'Content-Type must be application/json'
                }), 400

            # Parse JSON body
            body = request.get_json()

            if body is None:
                logger.warning("Failed to parse JSON from request")
                return jsonify({
                    'error': 'Invalid JSON payload'
                }), 400

            logger.info(f"Echo request received - payload size: {len(str(body))} chars")

            # Return echoed payload
            return jsonify({
                'body': body
            }), 200

        except Exception as e:
            logger.error(f"Error processing echo request: {str(e)}", exc_info=True)
            return jsonify({
                'error': 'Invalid JSON payload'
            }), 400

    @app.errorhandler(404)
    def not_found(e):
        """
        Handle 404 errors for non-existent endpoints.

        Args:
            e: The error object

        Returns:
            tuple: JSON error response, HTTP 404 status
        """
        logger.warning(f"404 error: {request.path}")
        return jsonify({
            'error': 'Endpoint not found'
        }), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        """
        Handle 405 errors for invalid HTTP methods.

        Args:
            e: The error object

        Returns:
            tuple: JSON error response, HTTP 405 status
        """
        logger.warning(f"405 error: {request.method} not allowed for {request.path}")
        return jsonify({
            'error': f'Method {request.method} not allowed'
        }), 405

    @app.errorhandler(500)
    def internal_error(e):
        """
        Handle 500 internal server errors.

        Args:
            e: The error object

        Returns:
            tuple: JSON error response, HTTP 500 status
        """
        logger.error(f"Internal server error: {str(e)}", exc_info=True)
        return jsonify({
            'error': 'Internal server error'
        }), 500

    @app.before_request
    def log_request():
        """Log incoming requests for monitoring."""
        logger.info(f"Request: {request.method} {request.path} from {request.remote_addr}")

    @app.after_request
    def log_response(response):
        """
        Log outgoing responses for monitoring.

        Args:
            response: The Flask response object

        Returns:
            Response: The unmodified response object
        """
        logger.info(f"Response: {response.status_code} for {request.method} {request.path}")
        return response

    logger.info("Flask application initialized successfully")
    return app


# For local development
if __name__ == '__main__':
    app = create_app()
    logger.info("Starting Flask development server on port 8000")
    app.run(host='0.0.0.0', port=8000, debug=True)
