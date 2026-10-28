FROM node:22-bookworm AS web-build

ARG FLUTTER_VERSION=3.47.1
ARG FLUTTER_COMMIT=6655482ec06e547f90abf8ae7590466f4415978d
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=/opt/flutter/bin:$PATH
ENV CI=true
ENV PUB_ENVIRONMENT=ci

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git curl unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_ROOT" \
    && test "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" = "$FLUTTER_COMMIT" \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /workspace
COPY . .
RUN flutter pub get \
    && flutter build web --release \
       --dart-define=PESO_NSRP_WORKSPACE_URL=/nsrp/ \
       --dart-define=PESO_API_BASE_URL=http://127.0.0.1:3000 \
    && npm ci --prefix react_workspace \
    && npm run build --prefix react_workspace -- --base=/nsrp/ \
    && mkdir -p build/web/nsrp \
    && cp -R react_workspace/dist/. build/web/nsrp/ \
    && test -s build/web/index.html \
    && test -s build/web/nsrp/index.html

FROM nginx:1.31-alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-build /workspace/build/web /usr/share/nginx/html
EXPOSE 8080