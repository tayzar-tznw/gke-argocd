# Placeholder image for an oke worker.
# Loops LPOP'ing from a Redis queue — same pattern KEDA's redis-list scaler watches.
# Real oke worker would be a Rails Sidekiq image.
FROM redis:7-alpine

ARG BUILD_SHA=unknown
ENV BUILD_SHA=${BUILD_SHA}

COPY worker.sh /usr/local/bin/worker.sh
RUN chmod +x /usr/local/bin/worker.sh

USER 999
ENTRYPOINT ["/usr/local/bin/worker.sh"]
