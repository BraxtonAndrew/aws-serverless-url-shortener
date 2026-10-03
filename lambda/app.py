import json
import os
import boto3
import secrets
import string
import base64

table_name = os.environ["TABLE_NAME"]
table = boto3.resource("dynamodb").Table(table_name)

ALPHABET = string.ascii_letters + string.digits


# Example request to create the new url
# event = {
#    "routeKey": "POST /links",
#    "body": "{\"url\": \"https://github.com\"}"
#}

# Example request to visit the new url
#event = {
#    "routeKey": "GET /{code}",
#    "pathParameters": {"code": "SVAWpT"},
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
    try:
        raw_body = event["body"]
        if event.get("isBase64Encoded"):
            raw_body = base64.b64decode(raw_body).decode("utf-8")

        body = json.loads(raw_body)
        long_url = body["url"]
    except (ValueError, KeyError):
        return {"statusCode": 400, "body": json.dumps({"message": "Invalid request body"})}

    short_code = ""
    for _ in range(6):
        short_code += secrets.choice(ALPHABET)

    table.put_item(Item={"short_code": short_code, "long_url": long_url})    

    return {"statusCode": 201, "body": json.dumps({"short_code": short_code})}

def redirect(event):
    short_code = event["pathParameters"]["code"]

    response = table.get_item(Key={"short_code": short_code})

    item = response.get("Item")
    if item is None:
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

    return {"statusCode": 301, "headers": {"Location": item["long_url"]}}