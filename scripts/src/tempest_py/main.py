"""Tempest account migration CLI."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.parse
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from typing import Any

import httpx

from tempest_py import ar


DEFAULT_DID = "did:plc:oga6ppys7zwxlheuqmcm7dac"
DEFAULT_HANDLE = "tempestpds.bsky.social"
DEFAULT_OLD_PDS = "https://jellybaby.us-east.host.bsky.network"
DEFAULT_TEMPEST = "https://tempest.desertthunder.dev"
DEFAULT_TEMPEST_SERVICE_DID = "did:web:tempest.desertthunder.dev"
CREATE_ACCOUNT_LXM = "com.atproto.server.createAccount"
ARGON_COMMANDS = {"ar", "arg2", "argon"}


class CliError(RuntimeError):
    pass


class Command(StrEnum):
    FULL = "full"
    LOGIN_SOURCE = "login-source"
    SERVICE_AUTH = "service-auth"
    SOURCE_SESSION_STATUS = "source-session-status"
    EXPORT_CAR = "export-car"
    LIST_SOURCE_BLOBS = "list-source-blobs"
    DOWNLOAD_SOURCE_BLOBS = "download-source-blobs"
    CREATE_ACCOUNT = "create-account"
    REFRESH_SESSION = "refresh-session"
    IMPORT_REPO = "import-repo"
    STATUS = "status"
    MISSING_BLOBS = "missing-blobs"
    UPLOAD_MISSING_BLOBS = "upload-missing-blobs"
    PLC_RECOMMENDED = "plc-recommended"
    PLC_REQUEST_TOKEN = "plc-request-token"
    PLC_SIGN = "plc-sign"
    PLC_SUBMIT = "plc-submit"
    ACTIVATE = "activate"


@dataclass(frozen=True)
class Settings:
    artifact_dir: Path
    old_pds: str
    old_login_pds: str
    old_auth_pds: str
    tempest: str
    tempest_service_did: str
    did: str
    handle: str
    email: str | None
    old_password: str | None
    tempest_password: str | None
    old_session_path: Path
    service_auth_path: Path
    car_path: Path
    source_blobs_path: Path
    create_account_path: Path
    import_repo_path: Path
    status_path: Path
    missing_blobs_path: Path
    plc_recommended_path: Path
    plc_token_path: Path
    plc_signed_path: Path
    plc_submit_path: Path
    activate_path: Path


def env(name: str, default: str | None = None) -> str | None:
    value = os.environ.get(name)
    return value if value not in (None, "") else default


def require_env(settings: Settings, name: str, value: str | None) -> str:
    if value:
        return value
    raise CliError(f"{name} is required for this command")


def path_from_env(name: str, default: Path) -> Path:
    value = env(name)
    return Path(value) if value else default


def settings_from_env(args: argparse.Namespace) -> Settings:
    artifact_dir = Path(args.artifact_dir or env("ARTIFACT_DIR", ".sandbox"))

    return Settings(
        artifact_dir=artifact_dir,
        old_pds=env("OLD_PDS", DEFAULT_OLD_PDS).rstrip("/"),
        old_auth_pds=env("OLD_AUTH_PDS", env("OLD_PDS", DEFAULT_OLD_PDS)).rstrip("/"),
        old_login_pds=env("OLD_LOGIN_PDS", env("OLD_AUTH_PDS", env("OLD_PDS", DEFAULT_OLD_PDS))).rstrip("/"),
        tempest=env("TEMPEST", DEFAULT_TEMPEST).rstrip("/"),
        tempest_service_did=env("TEMPEST_SERVICE_DID", DEFAULT_TEMPEST_SERVICE_DID),
        did=env("DID", DEFAULT_DID),
        handle=env("HANDLE", DEFAULT_HANDLE),
        email=env("EMAIL"),
        old_password=env("OLD_PASSWORD"),
        tempest_password=env("TEMPEST_PASSWORD"),
        old_session_path=path_from_env("OLD_SESSION_JSON", artifact_dir / "old_session.json"),
        service_auth_path=path_from_env("SERVICE_AUTH_JSON", artifact_dir / "service_auth_create_account.json"),
        car_path=path_from_env("REPO_CAR", artifact_dir / "tempestpds.repo.car"),
        source_blobs_path=path_from_env("SOURCE_BLOBS_JSON", artifact_dir / "source_blobs.json"),
        create_account_path=path_from_env("TEMPEST_CREATE_ACCOUNT_JSON", artifact_dir / "tempest_create_account.json"),
        import_repo_path=path_from_env("TEMPEST_IMPORT_REPO_JSON", artifact_dir / "tempest_import_repo.json"),
        status_path=path_from_env("TEMPEST_STATUS_JSON", artifact_dir / "tempest_account_status.json"),
        missing_blobs_path=path_from_env("TEMPEST_MISSING_BLOBS_JSON", artifact_dir / "tempest_missing_blobs.json"),
        plc_recommended_path=path_from_env("PLC_RECOMMENDED_JSON", artifact_dir / "plc_recommended.json"),
        plc_token_path=path_from_env("PLC_TOKEN_JSON", artifact_dir / "plc_token.json"),
        plc_signed_path=path_from_env("PLC_SIGNED_OPERATION_JSON", artifact_dir / "plc_signed_operation.json"),
        plc_submit_path=path_from_env("PLC_SUBMIT_JSON", artifact_dir / "plc_submit.json"),
        activate_path=path_from_env("TEMPEST_ACTIVATE_JSON", artifact_dir / "tempest_activate_account.json"),
    )


def log(message: str) -> None:
    print(message, flush=True)


def step(name: str) -> None:
    log(f"\n==> {name}")


def ensure_artifact_dir(settings: Settings) -> None:
    settings.artifact_dir.mkdir(parents=True, exist_ok=True)


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError as exc:
        raise CliError(f"missing artifact: {path}") from exc
    except json.JSONDecodeError as exc:
        raise CliError(f"invalid JSON artifact: {path}") from exc

    if not isinstance(data, dict):
        raise CliError(f"expected JSON object in {path}")
    return data


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")


def write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def safe_summary(data: dict[str, Any]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for key, value in data.items():
        if key.lower() in {"accessjwt", "refreshjwt", "token", "serviceauth", "password"}:
            summary[f"has_{key}"] = isinstance(value, str) and value != ""
        elif isinstance(value, (str, int, bool)) or value is None:
            summary[key] = value
    return summary


def print_json_summary(label: str, data: dict[str, Any]) -> None:
    log(f"{label}: {json.dumps(safe_summary(data), sort_keys=True)}")


def request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    json_body: dict[str, Any] | None = None,
    body: bytes | None = None,
    timeout: int = 30,
) -> tuple[int, dict[str, str], bytes]:
    headers = dict(headers or {})
    payload = body

    if json_body is not None:
        payload = json.dumps(json_body, separators=(",", ":")).encode("utf-8")
        headers.setdefault("Content-Type", "application/json")

    try:
        with httpx.Client(timeout=timeout, follow_redirects=True) as client:
            response = client.request(method, url, headers=headers, content=payload)
    except httpx.HTTPError as exc:
        raise CliError(f"request failed for {url}: {exc}") from exc

    return response.status_code, {key.lower(): value for key, value in response.headers.items()}, response.content


def expect_json(status: int, raw: bytes, url: str) -> dict[str, Any]:
    try:
        data = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise CliError(f"{url} returned HTTP {status} with non-JSON body") from exc

    if not isinstance(data, dict):
        raise CliError(f"{url} returned HTTP {status} with non-object JSON")

    if not 200 <= status <= 299:
        message = data.get("message") or data.get("error") or raw.decode("utf-8", errors="replace")
        raise CliError(f"{url} returned HTTP {status}: {message}")

    return data


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def access_from_session(settings: Settings) -> str:
    if not settings.old_session_path.exists():
        explicit = env("OLD_ACCESS")
        if explicit:
            return explicit
        raise CliError(f"{settings.old_session_path} does not exist; run login-source or set OLD_ACCESS")

    data = read_json(settings.old_session_path)
    session_host = data.get("_tempest_old_login_pds") or data.get("_tempest_old_auth_pds")
    if isinstance(session_host, str) and session_host != settings.old_login_pds:
        raise CliError(
            f"{settings.old_session_path} was created for {session_host}, "
            f"but OLD_LOGIN_PDS is {settings.old_login_pds}; rerun login-source successfully"
        )

    session_identifier = data.get("_tempest_old_identifier")
    current_identifier = env("OLD_IDENTIFIER", settings.handle)
    if isinstance(session_identifier, str) and session_identifier != current_identifier:
        raise CliError(
            f"{settings.old_session_path} was created for identifier {session_identifier}, "
            f"but OLD_IDENTIFIER is {current_identifier}; rerun login-source successfully"
        )

    token = data.get("accessJwt")
    if not isinstance(token, str) or not token:
        raise CliError(f"{settings.old_session_path} does not contain accessJwt")
    return token


def service_auth_token(settings: Settings) -> str:
    explicit = env("SERVICE_AUTH")
    if explicit:
        return explicit

    data = read_json(settings.service_auth_path)
    token = data.get("token")
    if not isinstance(token, str) or not token:
        raise CliError(f"{settings.service_auth_path} does not contain token")
    return token


def tempest_access_token(settings: Settings) -> str:
    if not settings.create_account_path.exists():
        explicit = env("TEMPEST_ACCESS")
        if explicit:
            return explicit
        raise CliError(f"{settings.create_account_path} does not exist; run create-account or set TEMPEST_ACCESS")

    data = read_json(settings.create_account_path)
    token = data.get("accessJwt")
    if not isinstance(token, str) or not token:
        raise CliError(f"{settings.create_account_path} does not contain accessJwt")
    return token


def tempest_refresh_token(settings: Settings) -> str:
    if not settings.create_account_path.exists():
        explicit = env("TEMPEST_REFRESH")
        if explicit:
            return explicit
        raise CliError(f"{settings.create_account_path} does not exist; run create-account or set TEMPEST_REFRESH")

    data = read_json(settings.create_account_path)
    token = data.get("refreshJwt")
    if not isinstance(token, str) or not token:
        raise CliError(f"{settings.create_account_path} does not contain refreshJwt")
    return token


def plc_operation_token(settings: Settings) -> str:
    explicit = env("PLC_TOKEN")
    if explicit:
        return explicit

    data = read_json(settings.plc_token_path)
    token = data.get("token")
    if not isinstance(token, str) or not token:
        raise CliError(f"{settings.plc_token_path} does not contain token; set PLC_TOKEN from the emailed code/token if needed")
    return token


def login_source(settings: Settings) -> None:
    step("source session")
    password = require_env(settings, "OLD_PASSWORD", settings.old_password)
    url = f"{settings.old_login_pds}/xrpc/com.atproto.server.createSession"
    identifier = env("OLD_IDENTIFIER", settings.handle)
    payload = {"identifier": identifier, "password": password}
    auth_factor_token = env("OLD_AUTH_FACTOR_TOKEN")
    if auth_factor_token:
        payload["authFactorToken"] = auth_factor_token
    log(
        "login context: "
        f"old_login_pds={settings.old_login_pds} "
        f"old_auth_pds={settings.old_auth_pds} "
        f"identifier={identifier} "
        f"has_old_password={bool(password)} "
        f"has_old_auth_factor_token={bool(auth_factor_token)}"
    )
    status, _headers, raw = request("POST", url, json_body=payload)
    data = expect_json(status, raw, url)
    data["_tempest_old_login_pds"] = settings.old_login_pds
    data["_tempest_old_auth_pds"] = settings.old_auth_pds
    data["_tempest_old_identifier"] = identifier
    write_json(settings.old_session_path, data)
    print_json_summary("saved source session", data)
    log(f"wrote {settings.old_session_path}")


def get_service_auth(settings: Settings) -> None:
    step("service auth")
    query = urllib.parse.urlencode({"aud": settings.tempest_service_did, "lxm": CREATE_ACCOUNT_LXM})
    url = f"{settings.old_pds}/xrpc/com.atproto.server.getServiceAuth?{query}"
    status, _headers, raw = request("GET", url, headers=bearer(access_from_session(settings)))
    data = expect_json(status, raw, url)
    write_json(settings.service_auth_path, data)
    print_json_summary("saved service auth", data)
    log(f"aud={settings.tempest_service_did} lxm={CREATE_ACCOUNT_LXM}")
    log(f"wrote {settings.service_auth_path}")


def source_session_status(settings: Settings) -> None:
    step("source session status")
    url = f"{settings.old_auth_pds}/xrpc/com.atproto.server.getSession"
    status, _headers, raw = request("GET", url, headers=bearer(access_from_session(settings)))
    data = expect_json(status, raw, url)
    print_json_summary("source session is accepted", data)


def export_car(settings: Settings) -> None:
    step("export repo CAR")
    query = urllib.parse.urlencode({"did": settings.did})
    url = f"{settings.old_pds}/xrpc/com.atproto.sync.getRepo?{query}"
    status, headers, raw = request("GET", url, timeout=60)
    if not 200 <= status <= 299:
        data = expect_json(status, raw, url)
        raise CliError(str(data))
    write_bytes(settings.car_path, raw)
    log(f"content-type={headers.get('content-type', '<unknown>')} bytes={len(raw)}")
    log(f"wrote {settings.car_path}")


def list_source_blobs(settings: Settings) -> None:
    step("source blob inventory")
    query = urllib.parse.urlencode({"did": settings.did})
    url = f"{settings.old_pds}/xrpc/com.atproto.sync.listBlobs?{query}"
    status, _headers, raw = request("GET", url)
    data = expect_json(status, raw, url)
    write_json(settings.source_blobs_path, data)
    cids = data.get("cids") if isinstance(data.get("cids"), list) else []
    log(f"blob_count={len(cids)}")
    log(f"wrote {settings.source_blobs_path}")


def blob_path(settings: Settings, cid: str) -> Path:
    return settings.artifact_dir / f"tempestpds.blob.{cid}"


def download_source_blobs(settings: Settings) -> None:
    step("download source blobs")
    data = read_json(settings.source_blobs_path)
    cids = data.get("cids")
    if not isinstance(cids, list):
        raise CliError(f"{settings.source_blobs_path} does not contain cids")

    if not cids:
        log("no source blobs to download")
        return

    for cid in cids:
        if not isinstance(cid, str) or not cid:
            raise CliError(f"invalid blob CID in {settings.source_blobs_path}")
        query = urllib.parse.urlencode({"did": settings.did, "cid": cid})
        url = f"{settings.old_pds}/xrpc/com.atproto.sync.getBlob?{query}"
        status, headers, raw = request("GET", url, timeout=60)
        if not 200 <= status <= 299:
            expect_json(status, raw, url)
        path = blob_path(settings, cid)
        write_bytes(path, raw)
        log(f"downloaded cid={cid} content-type={headers.get('content-type', '<unknown>')} bytes={len(raw)} path={path}")


def create_account(settings: Settings) -> None:
    step("create inactive Tempest account")
    email = require_env(settings, "EMAIL", settings.email)
    password = require_env(settings, "TEMPEST_PASSWORD", settings.tempest_password)
    payload = {
        "did": settings.did,
        "handle": settings.handle,
        "email": email,
        "password": password,
        "serviceAuth": service_auth_token(settings),
    }
    url = f"{settings.tempest}/xrpc/com.atproto.server.createAccount"
    status, _headers, raw = request("POST", url, json_body=payload)
    data = expect_json(status, raw, url)
    write_json(settings.create_account_path, data)
    print_json_summary("saved Tempest account", data)
    log(f"wrote {settings.create_account_path}")


def refresh_tempest_session(settings: Settings) -> None:
    step("refresh Tempest session")
    url = f"{settings.tempest}/xrpc/com.atproto.server.refreshSession"
    status, _headers, raw = request("POST", url, headers=bearer(tempest_refresh_token(settings)))
    data = expect_json(status, raw, url)
    write_json(settings.create_account_path, data)
    print_json_summary("saved refreshed Tempest account", data)
    log(f"wrote {settings.create_account_path}")


def import_repo(settings: Settings) -> None:
    step("import repo CAR into Tempest")
    if not settings.car_path.exists():
        raise CliError(f"missing CAR: {settings.car_path}")
    url = f"{settings.tempest}/xrpc/com.atproto.repo.importRepo"
    status, _headers, raw = request(
        "POST",
        url,
        headers={**bearer(tempest_access_token(settings)), "Content-Type": "application/vnd.ipld.car"},
        body=settings.car_path.read_bytes(),
        timeout=120,
    )
    data = expect_json(status, raw, url)
    write_json(settings.import_repo_path, data)
    print_json_summary("saved import result", data)
    log(f"wrote {settings.import_repo_path}")


def check_status(settings: Settings) -> None:
    step("Tempest account status")
    url = f"{settings.tempest}/xrpc/com.atproto.server.checkAccountStatus"
    status, _headers, raw = request("GET", url, headers=bearer(tempest_access_token(settings)))
    data = expect_json(status, raw, url)
    write_json(settings.status_path, data)
    print_json_summary("saved account status", data)
    log(f"wrote {settings.status_path}")


def list_missing_blobs(settings: Settings) -> None:
    step("Tempest missing blobs")
    url = f"{settings.tempest}/xrpc/com.atproto.repo.listMissingBlobs"
    status, _headers, raw = request("GET", url, headers=bearer(tempest_access_token(settings)))
    data = expect_json(status, raw, url)
    write_json(settings.missing_blobs_path, data)
    blobs = data.get("blobs") if isinstance(data.get("blobs"), list) else []
    log(f"missing_blob_count={len(blobs)}")
    log(f"wrote {settings.missing_blobs_path}")


def upload_missing_blobs(settings: Settings) -> None:
    step("upload missing blobs to Tempest")
    data = read_json(settings.missing_blobs_path)
    blobs = data.get("blobs")
    if not isinstance(blobs, list):
        raise CliError(f"{settings.missing_blobs_path} does not contain blobs")
    if not blobs:
        log("no missing blobs to upload")
        return

    for blob in blobs:
        cid = blob.get("cid") if isinstance(blob, dict) else None
        if not isinstance(cid, str) or not cid:
            raise CliError(f"invalid missing blob entry in {settings.missing_blobs_path}")

        path = blob_path(settings, cid)
        if not path.exists():
            raise CliError(f"missing downloaded blob file: {path}")

        mime_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        if path.name.endswith(f".{cid}"):
            mime_type = "application/octet-stream"
        if cid == "bafkreifodmypic3zbjtevk7rbftxvjxgpgegt5njaxn57lamxracv2a3he":
            mime_type = "image/png"

        url = f"{settings.tempest}/xrpc/com.atproto.repo.uploadBlob"
        status, _headers, raw = request(
            "POST",
            url,
            headers={**bearer(tempest_access_token(settings)), "Content-Type": mime_type},
            body=path.read_bytes(),
            timeout=60,
        )
        result = expect_json(status, raw, url)
        print_json_summary(f"uploaded cid={cid}", result)


def plc_recommended(settings: Settings) -> None:
    step("recommended PLC credentials from Tempest")
    url = f"{settings.tempest}/xrpc/com.atproto.identity.getRecommendedDidCredentials"
    status, _headers, raw = request("GET", url, headers=bearer(tempest_access_token(settings)))
    data = expect_json(status, raw, url)
    write_json(settings.plc_recommended_path, data)
    print_json_summary("saved recommended PLC credentials", data)
    log(f"wrote {settings.plc_recommended_path}")


def plc_request_token(settings: Settings) -> None:
    step("request PLC operation token from old PDS")
    url = f"{settings.old_auth_pds}/xrpc/com.atproto.identity.requestPlcOperationSignature"
    status, _headers, raw = request("POST", url, headers=bearer(access_from_session(settings)))

    first_error: dict[str, Any] = {}
    if not 200 <= status <= 299:
        try:
            decoded = json.loads(raw.decode("utf-8"))
            first_error = decoded if isinstance(decoded, dict) else {}
        except json.JSONDecodeError:
            first_error = {}

    first_message = first_error.get("message")
    first_error_name = first_error.get("error")

    if status == 400 and settings.old_password and first_message == "password is required":
        status, _headers, raw = request(
            "POST",
            url,
            headers=bearer(access_from_session(settings)),
            json_body={"password": settings.old_password},
        )

    if not 200 <= status <= 299:
        try:
            decoded = json.loads(raw.decode("utf-8"))
            data = decoded if isinstance(decoded, dict) else {}
        except json.JSONDecodeError:
            data = first_error

        message = data.get("message") or first_message
        error_name = data.get("error") or first_error_name
        if message == "Bad token scope":
            raise CliError(
                "source PDS rejected the fresh session for PLC operation signatures: "
                f"{error_name or 'InvalidRequest'}: {message}. "
                "The source session itself is valid, but this old-PDS endpoint is refusing its scope."
            )

    if 200 <= status <= 299 and raw.strip() == b"":
        data = {"requested": True, "delivery": "email"}
    else:
        data = expect_json(status, raw, url)

    write_json(settings.plc_token_path, data)
    print_json_summary("saved PLC operation token response", data)
    log(f"wrote {settings.plc_token_path}")
    if "token" not in data:
        log("Check the source account email for the PLC token/code, then export it as PLC_TOKEN before plc-sign.")


def plc_sign(settings: Settings) -> None:
    step("sign PLC operation on old PDS")
    recommended = read_json(settings.plc_recommended_path)
    payload = {
        key: recommended[key]
        for key in ("rotationKeys", "alsoKnownAs", "verificationMethods", "services")
        if key in recommended
    }
    payload["token"] = plc_operation_token(settings)

    url = f"{settings.old_auth_pds}/xrpc/com.atproto.identity.signPlcOperation"
    status, _headers, raw = request("POST", url, headers=bearer(access_from_session(settings)), json_body=payload)
    data = expect_json(status, raw, url)
    write_json(settings.plc_signed_path, data)
    operation = data.get("operation") if isinstance(data.get("operation"), dict) else {}
    service = operation.get("services", {}).get("atproto_pds", {}) if isinstance(operation.get("services"), dict) else {}
    log(f"signed operation service_endpoint={service.get('endpoint', '<unknown>')}")
    log(f"wrote {settings.plc_signed_path}")


def plc_submit(settings: Settings) -> None:
    step("submit PLC operation through Tempest")
    data = read_json(settings.plc_signed_path)
    operation = data.get("operation")
    if not isinstance(operation, dict):
        raise CliError(f"{settings.plc_signed_path} does not contain operation")

    url = f"{settings.tempest}/xrpc/com.atproto.identity.submitPlcOperation"
    status, _headers, raw = request("POST", url, headers=bearer(tempest_access_token(settings)), json_body={"operation": operation})
    result = expect_json(status, raw, url)
    write_json(settings.plc_submit_path, result)
    print_json_summary("saved PLC submit result", result)
    log(f"wrote {settings.plc_submit_path}")


def activate_account(settings: Settings) -> None:
    step("activate Tempest account")
    url = f"{settings.tempest}/xrpc/com.atproto.server.activateAccount"
    status, _headers, raw = request("POST", url, headers=bearer(tempest_access_token(settings)), json_body={})
    data = expect_json(status, raw, url)
    write_json(settings.activate_path, data)
    print_json_summary("saved activation result", data)
    log(f"wrote {settings.activate_path}")


def full(settings: Settings) -> None:
    started = time.monotonic()
    log("Tempest migration CLI")
    log(f"old_pds={settings.old_pds}")
    log(f"old_login_pds={settings.old_login_pds}")
    log(f"old_auth_pds={settings.old_auth_pds}")
    log(f"tempest={settings.tempest}")
    log(f"tempest_service_did={settings.tempest_service_did}")
    log(f"did={settings.did}")
    log(f"handle={settings.handle}")
    ensure_artifact_dir(settings)
    login_source(settings)
    get_service_auth(settings)
    export_car(settings)
    list_source_blobs(settings)
    download_source_blobs(settings)
    create_account(settings)
    import_repo(settings)
    check_status(settings)
    list_missing_blobs(settings)
    log(f"\ncomplete in {time.monotonic() - started:.1f}s")
    log("Do not activate until the DID document #atproto_pds serviceEndpoint points at Tempest.")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="tempest",
        description="Run Tempest account migration steps from environment variables.",
        epilog="Admin token helper aliases: tempest ar, tempest arg2, tempest argon.",
    )
    p.add_argument(
        "command",
        nargs="?",
        choices=[command.value for command in Command],
        default=Command.FULL.value,
        help="Command to run. Defaults to full.",
    )
    p.add_argument(
        "--artifact-dir",
        default=None,
        help="Directory for JSON/CAR/blob artifacts. Defaults to ARTIFACT_DIR or .sandbox.",
    )
    return p


def run_command(command: Command, settings: Settings) -> None:
    match command:
        case Command.FULL:
            full(settings)
        case Command.LOGIN_SOURCE:
            login_source(settings)
        case Command.SERVICE_AUTH:
            get_service_auth(settings)
        case Command.SOURCE_SESSION_STATUS:
            source_session_status(settings)
        case Command.EXPORT_CAR:
            export_car(settings)
        case Command.LIST_SOURCE_BLOBS:
            list_source_blobs(settings)
        case Command.DOWNLOAD_SOURCE_BLOBS:
            download_source_blobs(settings)
        case Command.CREATE_ACCOUNT:
            create_account(settings)
        case Command.REFRESH_SESSION:
            refresh_tempest_session(settings)
        case Command.IMPORT_REPO:
            import_repo(settings)
        case Command.STATUS:
            check_status(settings)
        case Command.MISSING_BLOBS:
            list_missing_blobs(settings)
        case Command.UPLOAD_MISSING_BLOBS:
            upload_missing_blobs(settings)
        case Command.PLC_RECOMMENDED:
            plc_recommended(settings)
        case Command.PLC_REQUEST_TOKEN:
            plc_request_token(settings)
        case Command.PLC_SIGN:
            plc_sign(settings)
        case Command.PLC_SUBMIT:
            plc_submit(settings)
        case Command.ACTIVATE:
            activate_account(settings)


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)

    if argv and argv[0] in ARGON_COMMANDS:
        return ar.main(argv[1:])

    args = parser().parse_args(argv)

    settings = settings_from_env(args)
    command = Command(args.command)

    try:
        ensure_artifact_dir(settings)
        run_command(command, settings)
    except CliError as exc:
        log(f"\nERROR: {exc}")
        return 1
    except KeyboardInterrupt:
        log("\ninterrupted")
        return 130

    return 0


if __name__ == "__main__":
    sys.exit(main())
