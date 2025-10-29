import os, hmac, hashlib, base64, logging

import boto3
from botocore.exceptions import ClientError

ssm = boto3.client("ssm")
_SECRET_CACHE: dict[str, str] = {}
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    headers = event.get("headers") or {}
    token = headers.get("x-signature")
    device_id = headers.get("x-device-id")
    timestamp = headers.get("x-timestamp")

    logger.info(
        "Authorizer invoked for device_id=%s signature_present=%s timestamp=%s",
        device_id,
        bool(token),
        timestamp,
    )

    if not token or not device_id or not timestamp:
        return _deny("Missing signature, device ID, or timestamp")

    try:
        secret = _get_device_secret(device_id)
    except KeyError:
        logger.warning("Denying request: unknown device_id=%s", device_id)
        return _deny("Unknown device")
    except ClientError:
        logger.exception("Denying request: SSM get_parameter failed for device_id=%s", device_id)
        return _deny("Secret lookup failed")

    canonical = f"{device_id}:{timestamp}"
    calc_sig = base64.b64encode(
        hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).digest()
    ).decode()

    if not hmac.compare_digest(calc_sig, token):
        logger.warning("Denying request: signature mismatch for device_id=%s", device_id)
        return _deny("Invalid signature")

    logger.info("Allowing request for device_id=%s", device_id)
    return _allow(device_id)

def _allow(device_id):
    return {
        "principalId": device_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": "Allow", "Resource": "*"}
            ],
        },
    }

def _deny(reason):
    return {
        "principalId": "unknown",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": "Deny", "Resource": "*"}
            ],
        },
        "context": {"error": reason},
    }


def _get_device_secret(device_id: str) -> str:
    if device_id in _SECRET_CACHE:
        return _SECRET_CACHE[device_id]

    param_name = os.environ.get(f"DEVICE_{device_id}_PARAM")
    if not param_name:
        prefix = os.environ.get("DEVICE_SECRET_PARAMETER_PREFIX", "")
        prefix = prefix.rstrip("/")
        if prefix:
            param_name = f"{prefix}/{device_id}"

    if not param_name:
        raise KeyError(f"No parameter mapping for {device_id}")

    response = ssm.get_parameter(Name=param_name, WithDecryption=True)
    secret = response["Parameter"]["Value"]
    _SECRET_CACHE[device_id] = secret
    return secret
