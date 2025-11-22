# Use standard Python image (not Lambda base image when using Web Adapter)
FROM python:3.11-slim

# Install AWS Lambda Web Adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

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

# Set environment variables
ENV PYTHONUNBUFFERED=1
# Tell Lambda Web Adapter to forward requests to port 8000
ENV PORT=8000

# Use gunicorn as production WSGI server
# --bind 0.0.0.0:8000: Bind to all interfaces on port 8000
# --workers 1: Use 1 worker (Lambda containers are single-threaded)
# --timeout 60: Set request timeout to 60 seconds
# src.app:create_app(): Use application factory pattern
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--timeout", "60", "src.app:create_app()"]
