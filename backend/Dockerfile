# Use Python 3.11 slim image for smaller size and Lambda compatibility
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
# This allows pip install to be cached if requirements haven't changed
COPY requirements.txt .

# Install Python dependencies
# --no-cache-dir reduces image size by not caching pip packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY src/ ./src/

# Expose port 8000 for the application
EXPOSE 8000

# Set environment variable for Python
ENV PYTHONUNBUFFERED=1

# Use gunicorn as production WSGI server
# --bind 0.0.0.0:8000: Bind to all interfaces on port 8000
# --workers 4: Use 4 worker processes for handling requests
# --timeout 60: Set request timeout to 60 seconds
# src.app:create_app(): Use application factory pattern
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--timeout", "60", "src.app:create_app()"]
