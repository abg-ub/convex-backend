# Self-hosted Docker environment variables

This describes variables referenced by `[docker-compose.build.yml](./docker-compose.build.yml)` and `[docker-compose.yml](./docker-compose.yml)`. Set them in a `.env` file next to the compose file, or in your shell before `docker compose up`.

**Sources:** backend behavior is implemented in `crates/local_backend`, `crates/common/src/knobs.rs` (tunable limits), `crates/aws_utils`, and `[self-hosted/docker-build/run_backend.sh](../docker-build/run_backend.sh)`. Defaults for limit knobs are compiled into the binary unless you override them here.

**Note:** Any environment variable read via `env_config` in `knobs.rs` can be set on the process, but only the variables listed under `environment:` in compose are *forwarded* into the container automatically. To pass others, extend the compose file.

---

## Compose-only variables (interpolation)

These control published ports and defaults in the YAML; they are not always passed into containers as named env vars.


| Variable          | Used for                                                                                             |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| `PORT`            | Host port mapped to backend API (default `3210`). Drives default `CONVEX_CLOUD_ORIGIN`.              |
| `SITE_PROXY_PORT` | Host port mapped to HTTP actions / site proxy (default `3211`). Drives default `CONVEX_SITE_ORIGIN`. |
| `DASHBOARD_PORT`  | Host port for the dashboard (default `6791`).                                                        |


---

## Backend service

### Instance identity and URLs


| Variable                     | Description                                                                                                                                                                               |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `INSTANCE_NAME`              | Logical name for this deployment (auth / keying). If unset, `[read_credentials.sh](../docker-build/read_credentials.sh)` may persist a default in the data volume (`convex-self-hosted`). |
| `INSTANCE_SECRET`            | Hex secret for signing; must be stable for a given data directory. If unset, a random value is generated and stored under the data volume credentials path.                               |
| `CONVEX_CLOUD_ORIGIN`        | Public URL clients use to reach the Convex API (scheme + host + optional port). Used in callbacks, stored URLs, etc. Default: `http://127.0.0.1:${PORT}`.                                 |
| `CONVEX_SITE_ORIGIN`         | Public URL for HTTP actions (site). Default: `http://127.0.0.1:${SITE_PROXY_PORT}`.                                                                                                       |
| `CONVEX_RELEASE_VERSION_DEV` | Optional runtime version string for metrics / reporting when not baked in at compile time. Empty or `dev` is ignored; see `crates/metrics/src/lib.rs`.                                    |


### Database


| Variable             | Description                                                                                                                                   |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `POSTGRES_URL`       | PostgreSQL connection URL. When set, the backend uses Postgres (see `run_backend.sh`).                                                        |
| `MYSQL_URL`          | MySQL connection URL. When set, the backend uses MySQL.                                                                                       |
| `DATABASE_URL`       | **Deprecated.** Treated like Postgres for backwards compatibility. Prefer `POSTGRES_URL` or `MYSQL_URL`.                                      |
| `DO_NOT_REQUIRE_SSL` | When set (non-empty), allows DB connections without insisting on SSL. Use only in trusted networks; see `crates/local_backend/src/config.rs`. |


If none of the above URLs are set, the container uses SQLite at `/convex/data/db.sqlite3`.

### S3 / object storage (`run_backend.sh`)

If **all** of `AWS_REGION`, `S3_STORAGE_EXPORTS_BUCKET`, `S3_STORAGE_SNAPSHOT_IMPORTS_BUCKET`, `S3_STORAGE_MODULES_BUCKET`, `S3_STORAGE_FILES_BUCKET`, and `S3_STORAGE_SEARCH_BUCKET` are set, the backend uses S3-backed storage. Otherwise it uses local storage under the data volume.


| Variable                             | Description                                                                         |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| `AWS_REGION`                         | AWS region for S3 and credentials.                                                  |
| `AWS_ACCESS_KEY_ID`                  | Access key (optional if using IAM role, instance profile, SSO chain, etc.).         |
| `AWS_SECRET_ACCESS_KEY`              | Secret key.                                                                         |
| `AWS_SESSION_TOKEN`                  | Session token for temporary credentials.                                            |
| `S3_ENDPOINT_URL`                    | Custom S3 API endpoint (required for MinIO, R2, etc.).                              |
| `AWS_S3_FORCE_PATH_STYLE`            | If `true`, use path-style URLs (typical for MinIO).                                 |
| `AWS_S3_DISABLE_SSE`                 | If `true`, do not request S3 server-side encryption.                                |
| `AWS_S3_DISABLE_CHECKSUMS`           | If `true`, disable checksum headers (compatibility with some S3-compatible stores). |
| `S3_STORAGE_EXPORTS_BUCKET`          | Bucket for exports.                                                                 |
| `S3_STORAGE_SNAPSHOT_IMPORTS_BUCKET` | Bucket for snapshot imports.                                                        |
| `S3_STORAGE_MODULES_BUCKET`          | Bucket for deployed modules / code.                                                 |
| `S3_STORAGE_FILES_BUCKET`            | Bucket for user file storage.                                                       |
| `S3_STORAGE_SEARCH_BUCKET`           | Bucket for search-related data.                                                     |


### Privacy, TLS, and telemetry


| Variable                   | Description                                                                                                                                                                               |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DISABLE_BEACON`           | When set to a truthy value, disables the anonymous self-hosted usage beacon. See `[self-hosted/advanced/disabling_logging.md](../advanced/disabling_logging.md)`.                         |
| `REDACT_LOGS_TO_CLIENT`    | When set to a truthy value, redacts log content sent to clients (similar to cloud).                                                                                                       |
| `DISABLE_METRICS_ENDPOINT` | When `true`, disables the Prometheus-style `/metrics` HTTP endpoint. Compose default in this repo is often `true`; the binary default in `knobs.rs` is `false` if the variable is absent. |


### Operations and logging


| Variable                      | Description                                                                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DOCUMENT_RETENTION_DELAY`    | Retention window for document log history, **in seconds**. Smaller values keep less historical data. Default in `knobs.rs` is 14 days; compose may override (e.g. `172800` = 2 days). |
| `HTTP_SERVER_TIMEOUT_SECONDS` | Idle/timeout for HTTP requests handled by the backend (seconds). Default `300`.                                                                                                       |
| `RUST_LOG`                    | Rust `tracing` filter (e.g. `info`, `debug`). Compose default is often `info`.                                                                                                        |
| `RUST_BACKTRACE`              | Set to `1` for backtraces on panics.                                                                                                                                                  |


### Limit and performance knobs (`crates/common/src/knobs.rs`)

Omit these to use compiled-in defaults. Units are as stated.


| Variable                                        | Default (typical)                                                                | Description                                                                                                                   |
| ----------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `ACTIONS_USER_TIMEOUT_SECS`                     | `600`                                                                            | Maximum time user-authored **action** code may run (seconds). Node runs with additional overhead; see comments in `knobs.rs`. |
| `APPLICATION_FUNCTION_RUNNER_SEMAPHORE_TIMEOUT` | `5000`                                                                           | How long a request waits for a free function-execution slot (**milliseconds**).                                               |
| `APPLICATION_MAX_CONCURRENT_QUERIES`            | `16` (`docker-compose.yml`) / `500` (`docker-compose.build.yml` in-repo default) | Concurrent queries per backend.                                                                                               |
| `APPLICATION_MAX_CONCURRENT_MUTATIONS`          | (same pattern)                                                                   | Concurrent mutations.                                                                                                         |
| `APPLICATION_MAX_CONCURRENT_V8_ACTIONS`         | (same)                                                                           | Concurrent V8 actions (includes HTTP actions shape); does **not** cap Node actions.                                           |
| `APPLICATION_MAX_CONCURRENT_NODE_ACTIONS`       | (same)                                                                           | Concurrent Node (runtime) actions.                                                                                            |
| `APPLICATION_MAX_CONCURRENT_UPLOADS`            | `4`                                                                              | Concurrent deploy package uploads during push.                                                                                |
| `DOCUMENT_DELTAS_LIMIT`                         | `128`                                                                            | Max rows read when computing document deltas.                                                                                 |
| `FUNCTION_MAX_ARGS_SIZE`                        | 16 MiB                                                                           | Max serialized function arguments (bytes).                                                                                    |
| `FUNCTION_MAX_RESULT_SIZE`                      | 16 MiB                                                                           | Max serialized function return value (bytes).                                                                                 |
| `HTTP_SERVER_MAX_CONCURRENT_REQUESTS`           | `1024`                                                                           | Max concurrent inbound HTTP requests; also bounds Node action callback concurrency over HTTP.                                 |
| `ISOLATE_MAX_USER_HEAP_SIZE`                    | 64 MiB                                                                           | V8 heap budget for user isolate work (`1 << 26`).                                                                             |
| `ISOLATE_MAX_HEAP_EXTRA_SIZE`                   | 32 MiB                                                                           | Extra heap allowance for shared isolate state (`1 << 25`).                                                                    |
| `MAX_BYTES_WRITTEN_PER_SECOND`                  | 4 MiB                                                                            | Write throughput limit for mutations/imports (bytes per second).                                                              |
| `MAX_REACTOR_CALL_DEPTH`                        | `8`                                                                              | Max nested query/mutation calls in one execution to prevent runaway depth.                                                    |
| `MAX_SYSCALL_BATCH_SIZE`                        | `16`                                                                             | Max parallel DB syscalls batched together; lower values reduce one isolate hogging connections.                               |
| `MAX_TRANSACTION_WINDOW_SECONDS`                | `10`                                                                             | Width of the transactional time window `SnapshotManager` keeps.                                                               |
| `MAX_UDF_EXECUTION`                             | `1000`                                                                           | How many recent UDF execution log entries to retain in memory (not “concurrent UDFs”).                                        |
| `SHARED_UDF_CACHE_MAX_SIZE`                     | 1 GiB                                                                            | Max size of shared UDF bytecode cache in conductor.                                                                           |
| `UDF_CACHE_MAX_SIZE`                            | 100 MiB                                                                          | Max size of the per-process UDF cache.                                                                                        |
| `SNAPSHOT_LIST_LIMIT`                           | `1024`                                                                           | Max rows when serving a snapshot list page.                                                                                   |
| `SNAPSHOT_LIST_TIME_LIMIT_SECONDS`              | `60`                                                                             | Max time spent building one snapshot list page.                                                                               |
| `TRANSACTION_MAX_NUM_USER_WRITES`               | `16000`                                                                          | Max user writes in one transaction. Large DB configs may need matching `MAX_INSERT_SIZE` in drivers.                          |
| `TRANSACTION_MAX_USER_WRITE_SIZE_BYTES`         | 16 MiB                                                                           | Max total user write bytes per transaction.                                                                                   |
| `TRANSACTION_MAX_READ_SIZE_ROWS`                | `32000`                                                                          | Max rows read per transaction.                                                                                                |
| `TRANSACTION_MAX_READ_SIZE_BYTES`               | 16 MiB                                                                           | Max bytes read per transaction.                                                                                               |
| `V8_ACTION_SYSTEM_TIMEOUT_SECONDS`              | `300`                                                                            | System-side timeout for V8 actions (module load, etc.); does not include most syscall time.                                   |


---

## Dashboard service


| Variable                             | Description                                                                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_DEPLOYMENT_URL`         | Browser-facing URL of the Convex backend API (dashboard client). Default matches `CONVEX_CLOUD_ORIGIN` pattern: `http://127.0.0.1:${PORT}`. |
| `NEXT_PUBLIC_LOAD_MONACO_INTERNALLY` | Dashboard build/runtime flag for loading the Monaco editor from the dashboard origin instead of a CDN.                                      |


---

## Further reading

- Build-and-run overview: `[self-hosted/docker-build/README.md](../docker-build/README.md)`
- S3 layout: `[self-hosted/advanced/s3_storage.md](../advanced/s3_storage.md)`
- Postgres/MySQL: `[self-hosted/advanced/postgres_or_mysql.md](../advanced/postgres_or_mysql.md)`
- Knobs catalog (all env-tunable constants): `[crates/common/src/knobs.rs](../../crates/common/src/knobs.rs)`

