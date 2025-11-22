# Production Backend Application
#
# Replace this placeholder with your actual service implementation.
#
# Requirements:
# - Must be containerizable (works in Docker)
# - Should listen on port 8000
# - Must have tests that pass
# - Recommended: Stateless design for Lambda compatibility

from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint - required for monitoring"""
    return jsonify({
        "status": "ok",
        "service": "production-backend"
    }), 200

# Add your production endpoints here

if __name__ == '__main__':
    # For local development only
    # In production, gunicorn is used (see Dockerfile)
    app.run(host='0.0.0.0', port=8000, debug=True)
