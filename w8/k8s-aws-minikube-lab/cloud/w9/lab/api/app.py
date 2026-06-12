import os
import random
from flask import Flask, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
PrometheusMetrics(app)

ERROR_RATE = float(os.getenv("ERROR_RATE", "0"))
VERSION = os.getenv("VERSION", "v2-crud")

items = [
    {"id": 1, "title": "Learn GitOps", "done": True},
    {"id": 2, "title": "Deploy backend on AWS", "done": False},
]


@app.get("/")
def index():
    if random.random() < ERROR_RATE:
        return jsonify(error="injected error", version=VERSION), 500

    return jsonify(ok=True, version=VERSION), 200


@app.get("/info")
def info():
    return jsonify(
        service="backend-api",
        owner="Nguyen Van Tuan Anh",
        lab="W9 Frontend Backend CRUD Demo on AWS",
        status="running",
        version=VERSION,
        storage="in-memory",
    ), 200


@app.get("/items")
def get_items():
    return jsonify(items), 200


@app.post("/items")
def create_item():
    data = request.get_json(silent=True) or {}

    title = data.get("title", "").strip()
    if not title:
        return jsonify(error="title is required"), 400

    new_id = max([item["id"] for item in items], default=0) + 1
    item = {
        "id": new_id,
        "title": title,
        "done": False,
    }

    items.append(item)
    return jsonify(item), 201


@app.put("/items/<int:item_id>")
def update_item(item_id):
    data = request.get_json(silent=True) or {}

    for item in items:
        if item["id"] == item_id:
            if "title" in data:
                item["title"] = str(data["title"]).strip()

            if "done" in data:
                item["done"] = bool(data["done"])

            return jsonify(item), 200

    return jsonify(error="item not found"), 404


@app.delete("/items/<int:item_id>")
def delete_item(item_id):
    for item in items:
        if item["id"] == item_id:
            items.remove(item)
            return jsonify(message="item deleted", id=item_id), 200

    return jsonify(error="item not found"), 404


@app.get("/healthz")
def healthz():
    return "ok", 200
