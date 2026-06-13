#!/bin/sh
set -eu

if [ "${1:-start}" != "start" ]; then
  exec "$@"
fi

: "${TEMPEST_DATA_DIR:=/var/lib/tempest}"
export TEMPEST_DATA_DIR

run_as_tempest() {
  if [ "$(id -u)" = "0" ]; then
    exec su-exec tempest "$@"
  fi

  exec "$@"
}

eval_as_tempest() {
  if [ "$(id -u)" = "0" ]; then
    su-exec tempest "$@"
  else
    "$@"
  fi
}

mkdir -p \
  "$TEMPEST_DATA_DIR" \
  "$TEMPEST_DATA_DIR/repos" \
  "$TEMPEST_DATA_DIR/blobs" \
  "$TEMPEST_DATA_DIR/tmp" \
  "$TEMPEST_DATA_DIR/backups"

if [ "$(id -u)" = "0" ]; then
  chown -R tempest:tempest "$TEMPEST_DATA_DIR"
fi

if [ "${TEMPEST_RELEASE_BOOTSTRAP:-true}" != "false" ]; then
  eval_as_tempest /app/bin/tempest eval '
    Tempest.Config.load!() |> Tempest.Storage.bootstrap!()

    {:ok, _repo, _apps} =
      Ecto.Migrator.with_repo(Tempest.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true)
      end)
  '
fi

run_as_tempest /app/bin/tempest start
