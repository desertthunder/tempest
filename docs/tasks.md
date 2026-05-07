# Tempest PDS Task Index

Milestone task files live in `docs/tasks/`.

## Milestones

1. [00 Foundation](tasks/00-foundation.md)
2. [01 XRPC Shell](tasks/01-xrpc-shell.md)
3. [02 Accounts and Sessions](tasks/02-accounts-sessions.md)
4. [03 Identity and Handles](tasks/03-identity-handles.md)
5. [04 Repository Core](tasks/04-repo-core.md)
6. [05 Record APIs](tasks/05-record-apis.md)
7. [06 CAR and Sync Reads](tasks/06-car-sync-reads.md)
8. [07 Firehose](tasks/07-firehose.md)
9. [08 Blobs](tasks/08-blobs.md)
10. [09 Admin and Deployment](tasks/09-admin-deployment.md)
11. [10 Compatibility Hardening](tasks/10-compatibility-hardening.md)

## Done Rule

A milestone is done only when:

- all listed tasks are complete;
- the milestone HTTP verification passes against a running server;
- integration tests cover the main path and one failure path;
- `mix precommit` passes.
