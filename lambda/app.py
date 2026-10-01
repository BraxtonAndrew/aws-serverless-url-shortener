import json
import os
import boto3
import secrets
import string

table_name = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(table_name)

ALPHABET = string.ascii_letters + string.digits


# Example request
# event = {
#    "routeKey": "POST /links",
#    "body": "{\"url\": \"https://github.com\"}"
#}


def lambda_handler(event, context):
    route = event["routeKey"]

    if route == "POST /links":
        return create_link(event)
    elif route == "GET /{code}":
        return redirect(event)
    else:
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

def create_link(event):
    body = json.loads(event["body"])
    long_url = body["url"]

    short_code = ""
    for _ in range(6):
        short_code += secrets.choice(ALPHABET)

    table.put_item(Item={"short_code": short_code, "long_url": long_url})    

    return {"statusCode": 201, "body": json.dumps({"short_code": short_code})}

def redirect(event):
    return {"statusCode": 200, "body": json.dumps({"message": "redirect works"})}