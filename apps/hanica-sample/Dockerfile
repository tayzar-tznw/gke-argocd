# Placeholder image for the hanica web tier.
# Real hanica is a Rails app with pnpm-built frontend assets — see project.md.
# Replace this Dockerfile with the production build when migrating for real.
FROM nginxinc/nginx-unprivileged:1.27-alpine

ARG BUILD_SHA=unknown
ARG BUILD_TIME=unknown

ENV BUILD_SHA=${BUILD_SHA}
ENV BUILD_TIME=${BUILD_TIME}

COPY --chown=101:101 index.html /usr/share/nginx/html/index.html
RUN sed -i "s|__BUILD_SHA__|${BUILD_SHA}|g; s|__BUILD_TIME__|${BUILD_TIME}|g" \
      /usr/share/nginx/html/index.html

EXPOSE 8080
