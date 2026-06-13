#!/bin/sh
set -eu

if [ "${1:-start}" != "start" ]; then
  exec "$@"
fi

: "${TEMPEST_DATA_DIR:=/var/lib/tempest}"
export TEMPEST_DATA_DIR

mkdir -p \
  "$TEMPEST_DATA_DIR" \
  "$TEMPEST_DATA_DIR/repos" \
  "$TEMPEST_DATA_DIR/blobs" \
  "$TEMPEST_DATA_DIR/tmp" \
  "$TEMPEST_DATA_DIR/backups"

if [ "${TEMPEST_RELEASE_BOOTSTRAP:-true}" != "false" ]; then
  /app/bin/tempest eval '
    Tempest.Config.load!() |> Tempest.Storage.bootstrap!()

    {:ok, _repo, _apps} =
      Ecto.Migrator.with_repo(Tempest.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true)
      end)
  '
fi

exec /app/bin/tempest start
