# Stage 1: Build Flutter Web Application
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency specifications first for caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy full frontend source code
COPY . .

# Build Flutter Web in release mode with HTML renderer
RUN flutter build web --release

# Stage 2: Serve with Lightweight NGINX Alpine Image
FROM nginx:alpine

# Install curl for docker-compose healthcheck
RUN apk add --no-cache curl

# Copy custom NGINX configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web bundle from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
