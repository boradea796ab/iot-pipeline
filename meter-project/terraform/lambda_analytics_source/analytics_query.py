from analytics_backend.common import ValidationError, response
from analytics_backend.lambda_app import lambda_handler as _app_lambda_handler

__all__ = ["lambda_handler", "ValidationError", "response"]


def lambda_handler(event, context):
    return _app_lambda_handler(event, context)
