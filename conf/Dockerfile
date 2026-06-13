# syntax=docker/dockerfile:1
# Build from the project root:
#   docker build -f conf/Dockerfile -t tempest:local .

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4
ARG ALPINE_VERSION=3.21.7

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION} AS build

RUN apk add --no-cache build-base git npm python3 sqlite-dev

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod && mix deps.compile

COPY assets ./assets
COPY lib ./lib
COPY priv ./priv

RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache ca-certificates libgcc libstdc++ ncurses-libs openssl sqlite-libs \
  && addgroup -S tempest \
  && adduser -S -G tempest -h /app tempest \
  && mkdir -p /var/lib/tempest \
  && chown -R tempest:tempest /var/lib/tempest

WORKDIR /app
ENV HOME=/app \
    MIX_ENV=prod \
    PHX_SERVER=true \
    PORT=4000 \
    TEMPEST_DATA_DIR=/var/lib/tempest

COPY --from=build --chown=tempest:tempest /app/_build/prod/rel/tempest ./
COPY --chown=tempest:tempest conf/docker-entrypoint.sh /app/bin/docker-entrypoint
RUN chmod +x /app/bin/docker-entrypoint

USER tempest
EXPOSE 4000
ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["start"]
