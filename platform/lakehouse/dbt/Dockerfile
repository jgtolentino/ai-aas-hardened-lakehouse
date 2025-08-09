FROM python:3.11-slim
RUN pip install --no-cache-dir dbt-trino==1.8.5
WORKDIR /app
COPY . /app
ENV DBT_PROFILES_DIR=/app/profiles
ENTRYPOINT ["dbt"]
CMD ["run","--full-refresh","--profiles-dir","/app/profiles"]
