import json
import os
import boto3

table_name = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(table_name)


def lambda_handler(event, context):
    route = event["routeKey"]

    if route == "POST /links":
        return create_link(event)
    elif route == "GET /{code}":
        return redirect(event)
    else:
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

def create_link(event):
    return {"statusCode": 200, "body": json.dumps({"message": "create_link works"})}

def redirect(event):
    return {"statusCode": 200, "body": json.dumps({"message": "redirect works"})}