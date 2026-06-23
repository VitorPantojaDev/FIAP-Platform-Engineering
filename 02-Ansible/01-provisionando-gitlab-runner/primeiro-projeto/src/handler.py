"""API de status da frota da Vortex Mobility.

Uma unica Lambda atras de um API Gateway HTTP, persistindo em DynamoDB:
  GET  /scooters          -> lista os status registrados
  GET  /scooters/{id}     -> status de uma scooter
  PUT  /scooters/{id}     -> registra/atualiza o status (body JSON: {"status": "..."})

O nome da tabela vem da variavel de ambiente TABLE_NAME (injetada pelo Terraform).
"""
import json
import os

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
_dynamodb = boto3.resource("dynamodb")
_table = _dynamodb.Table(TABLE_NAME)

# Status aceitos para uma scooter. Validamos no PUT para nao gravar lixo.
VALID_STATUS = {"available", "in_use", "maintenance", "charging"}


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path_params = event.get("pathParameters") or {}
    scooter_id = path_params.get("id")

    if method == "GET" and scooter_id:
        return _get_one(scooter_id)
    if method == "GET":
        return _list_all()
    if method == "PUT" and scooter_id:
        return _put_one(scooter_id, event.get("body"))

    return _response(405, {"error": "metodo nao suportado", "method": method})


def _list_all():
    items = _table.scan().get("Items", [])
    return _response(200, {"count": len(items), "scooters": items})


def _get_one(scooter_id):
    item = _table.get_item(Key={"scooter_id": scooter_id}).get("Item")
    if not item:
        return _response(404, {"error": "scooter nao encontrada", "scooter_id": scooter_id})
    return _response(200, item)


def _put_one(scooter_id, raw_body):
    try:
        payload = json.loads(raw_body) if raw_body else {}
    except json.JSONDecodeError:
        return _response(400, {"error": "body nao e um JSON valido"})

    status = payload.get("status")
    if status not in VALID_STATUS:
        return _response(
            400,
            {"error": "status invalido", "aceitos": sorted(VALID_STATUS)},
        )

    item = {"scooter_id": scooter_id, "status": status}
    _table.put_item(Item=item)
    return _response(200, {"updated": item})
