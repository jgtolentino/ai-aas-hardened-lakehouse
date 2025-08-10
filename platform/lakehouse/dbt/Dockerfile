FROM python:3.11.8-slim
RUN pip install --no-cache-dir dbt-trino==1.8.5
RUN useradd -m -u 1000 dbtuser
WORKDIR /app
COPY --chown=dbtuser:dbtuser . /app
ENV DBT_PROFILES_DIR=/app/profiles
USER dbtuser
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD python -c "import dbt; print('healthy')" || exit 1
ENTRYPOINT ["dbt"]
CMD ["run","--full-refresh","--profiles-dir","/app/profiles"]
