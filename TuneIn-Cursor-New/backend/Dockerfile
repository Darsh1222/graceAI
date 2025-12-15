# Use Python 3.9 slim image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    curl \
    wget \
    musescore3 \
    openjdk-21-jre-headless \
    xvfb \
    git \
    build-essential \
    libasound2-dev \
    portaudio19-dev \
    libportaudio2 \
    libportaudiocpp0 \
    libffi-dev \
    libssl-dev \
    libgl1-mesa-dri \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Audiveris for sheet music processing (AWS compatible - ignore desktop menu errors)
RUN wget -O /tmp/audiveris.deb "https://github.com/Audiveris/audiveris/releases/download/5.6.2/Audiveris-5.6.2-ubuntu22.04-x86_64.deb" \
    && apt-get update \
    && (dpkg -i /tmp/audiveris.deb || true) \
    && apt-get install -f -y \
    && dpkg --configure -a || true \
    && rm /tmp/audiveris.deb \
    && apt-get clean \
    && find /opt -name "Audiveris" -type f -executable 2>/dev/null | head -1 | xargs -I {} ln -sf {} /usr/bin/audiveris || true \
    && find /usr -name "Audiveris" -type f -executable 2>/dev/null | head -1 | xargs -I {} ln -sf {} /usr/bin/audiveris || true \
    && ln -sf /usr/bin/musescore3 /usr/bin/musescore || true

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir -r requirements.txt

# Note: TensorFlow will be installed automatically as a dependency of basic-pitch

# Copy application code
COPY . .

# Copy environment file
COPY env.aws .env

# Create necessary directories
RUN mkdir -p /tmp/uploads /app/uploads /app/generated_files

# Create startup script (AWS compatible)
RUN echo '#!/bin/bash\n\
set -e\n\
# Start virtual display for headless GUI apps\n\
Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset &\n\
export DISPLAY=:99\n\
# Set tool paths\n\
export MUSESCORE_PATH=/usr/bin/musescore3\n\
export AUDIVERIS_PATH=/usr/bin/audiveris\n\
# Wait for X server to be ready\n\
sleep 2\n\
# Verify environment and tools\n\
echo "Starting TuneIn backend server..."\n\
echo "Python version: $(python --version)"\n\
echo "Working directory: $(pwd)"\n\
echo "Display: $DISPLAY"\n\
echo "MuseScore: $(which musescore3 || echo not found)"\n\
echo "Audiveris: $(which audiveris || echo not found)"\n\
# Start the application\n\
exec python real_music_server.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app /tmp/uploads

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8000

# Health check with extended startup time for heavy dependencies
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

# Run the application
CMD ["/app/start.sh"]
