FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create a simple brands.yaml fallback
RUN mkdir -p /app/packages/shared/dictionaries && \
    echo "version: '1.0.0'" > /app/packages/shared/dictionaries/brands.yaml && \
    echo "brands:" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "  coke:" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "    regex: '\\b(coca[\\s-]?cola|coke)\\b'" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "    weight: 1.0" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "  generic:" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "    regex: '.*'" >> /app/packages/shared/dictionaries/brands.yaml && \
    echo "    weight: 0.1" >> /app/packages/shared/dictionaries/brands.yaml

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]