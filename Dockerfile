ARG MLFLOW_VERSION=3.10.1

# Stage 1: Build the optimized React UI from source
FROM node:22-alpine AS ui-builder

WORKDIR /app

# Copy yarn configuration first (required for Yarn 4 Berry).
# The repo .dockerignore excludes dotfiles (`.*`), so we use a
# Dockerfile.dockerignore that does NOT exclude .yarnrc.yml.
COPY mlflow/server/js/.yarnrc.yml ./
COPY mlflow/server/js/yarn/ ./yarn/
COPY mlflow/server/js/package.json mlflow/server/js/yarn.lock ./

# Enable corepack so it picks up the Yarn 4 binary from yarnPath
RUN corepack enable && yarn install --immutable

# Copy the rest of the JS source and build
COPY mlflow/server/js/ ./
ENV DISABLE_ESLINT_PLUGIN=true
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN yarn build

# Stage 2: Base MLflow image with optimized UI swapped in
FROM ghcr.io/mlflow/mlflow:v${MLFLOW_VERSION}

# Install PostgreSQL driver
RUN pip install --no-cache-dir psycopg2-binary

# Find the mlflow JS build path dynamically (avoids hardcoding Python version)
RUN MLFLOW_DIR=$(python -c "import mlflow, os; print(os.path.join(os.path.dirname(mlflow.__file__), 'server', 'js', 'build'))") && \
    rm -rf "$MLFLOW_DIR" && \
    mkdir -p "$(dirname "$MLFLOW_DIR")" && \
    echo "$MLFLOW_DIR" > /tmp/mlflow_js_build_path

COPY --from=ui-builder /app/build /tmp/mlflow_ui_build

RUN MLFLOW_DIR=$(cat /tmp/mlflow_js_build_path) && \
    mv /tmp/mlflow_ui_build "$MLFLOW_DIR" && \
    rm /tmp/mlflow_js_build_path

EXPOSE 5000
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
