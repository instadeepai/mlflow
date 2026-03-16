ARG MLFLOW_VERSION=3.10.1

# Stage 1: Build the optimized React UI from source
FROM node:22-alpine AS ui-builder

WORKDIR /app

# Copy JS source and install dependencies
COPY mlflow/server/js/ ./
RUN corepack enable && yarn install --immutable

# Build the production React bundle
ENV DISABLE_ESLINT_PLUGIN=true
ENV NODE_OPTIONS="--max-old-space-size=8192"
RUN yarn build

# Stage 2: Base MLflow image with optimized UI swapped in
FROM ghcr.io/mlflow/mlflow:v${MLFLOW_VERSION}

# Replace the default React UI build with our optimized version
# Optimizations:
#   - Chart card pagination (50 per page) to prevent DOM overload with 3000+ metrics
#   - Auto-collapse metric sections when >100 charts
#   - Line charts by default instead of bar charts for training curves
#   - Auto-upgrade cached BAR chart configs to LINE on load
RUN rm -rf /usr/local/lib/python3.10/site-packages/mlflow/server/js/build
COPY --from=ui-builder /app/build /usr/local/lib/python3.10/site-packages/mlflow/server/js/build

EXPOSE 5000
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
