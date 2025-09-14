# Use lightweight Python base image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Install system deps (for psycopg2 and other common libs)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files
COPY . .

EXPOSE 8000

# Run server (0.0.0.0 so container is reachable)
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
