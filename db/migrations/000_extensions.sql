-- MUST run first
\set ON_ERROR_STOP on
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create extension if not exists vector;