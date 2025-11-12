FROM python:3.11-slim

# Workdir
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app.py .

# Expose Flask port
EXPOSE 5000

# Run the app
CMD ["python", "app.py"]
