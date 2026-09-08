#!/usr/bin/env python3
"""Small SmartCast contract appliance for hardware-free stress testing.

The server intentionally uses HTTP so it can run with only Python's standard
library. The iOS app uses HTTPS for real televisions. `--self-test` validates
pairing, authentication, command shape, text batching, and error responses.
"""

from __future__ import annotations

import argparse
import json
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


AUTH_TOKEN = "TEST-AUTH-TOKEN"
PAIRING_TOKEN = 246810


def response(result="SUCCESS", detail="Success", **extra):
    return {"STATUS": {"RESULT": result, "DETAIL": detail}, **extra}


class SmartCastHandler(BaseHTTPRequestHandler):
    command_log = []

    def log_message(self, *_):
        return

    def body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if not length:
            return {}
        return json.loads(self.rfile.read(length))

    def send_json(self, status, payload):
        encoded = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def authorized(self):
        if self.headers.get("AUTH") == AUTH_TOKEN:
            return True
        self.send_json(200, response("REQUIRES_PAIRING", "Pair this TV first"))
        return False

    def do_GET(self):
        if self.path == "/state/device/power_mode" and self.authorized():
            self.send_json(200, response(ITEMS=[{"CNAME": "power_mode", "VALUE": 1}]))
            return
        self.send_json(404, response("URI_NOT_FOUND", "Unknown endpoint"))

    def do_PUT(self):
        try:
            payload = self.body()
        except (ValueError, json.JSONDecodeError):
            self.send_json(200, response("INVALID_PARAMETER", "Invalid JSON"))
            return

        if self.path == "/pairing/start":
            if not payload.get("DEVICE_ID") or not payload.get("DEVICE_NAME"):
                self.send_json(200, response("INVALID_PARAMETER", "Missing device identity"))
                return
            self.send_json(200, response(ITEM={"PAIRING_REQ_TOKEN": PAIRING_TOKEN, "CHALLENGE_TYPE": 1}))
            return

        if self.path == "/pairing/pair":
            valid = (
                payload.get("PAIRING_REQ_TOKEN") == PAIRING_TOKEN
                and payload.get("CHALLENGE_TYPE") == 1
                and payload.get("RESPONSE_VALUE") == "1234"
            )
            if valid:
                self.send_json(200, response(ITEM={"AUTH_TOKEN": AUTH_TOKEN}))
            else:
                self.send_json(200, response("PAIRING_DENIED", "Incorrect PIN"))
            return

        if self.path == "/key_command/":
            if not self.authorized():
                return
            keys = payload.get("KEYLIST")
            if not isinstance(keys, list) or not keys:
                self.send_json(200, response("INVALID_PARAMETER", "KEYLIST is required"))
                return
            for key in keys:
                if not all(field in key for field in ("CODESET", "CODE", "ACTION")):
                    self.send_json(200, response("INVALID_PARAMETER", "Malformed key"))
                    return
                if key["ACTION"] not in ("KEYPRESS", "KEYDOWN", "KEYUP"):
                    self.send_json(200, response("INVALID_PARAMETER", "Unknown action"))
                    return
            self.command_log.extend(keys)
            self.send_json(200, response())
            return

        self.send_json(404, response("URI_NOT_FOUND", "Unknown endpoint"))


def call(base, method, path, payload=None, token=None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(base + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("AUTH", token)
    try:
        with urllib.request.urlopen(request, timeout=2) as result:
            return json.loads(result.read())
    except urllib.error.HTTPError as error:
        return json.loads(error.read())


def self_test():
    SmartCastHandler.command_log = []
    server = ThreadingHTTPServer(("127.0.0.1", 0), SmartCastHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}"

    try:
        missing_identity = call(base, "PUT", "/pairing/start", {"DEVICE_NAME": "TV Remote"})
        assert missing_identity["STATUS"]["RESULT"] == "INVALID_PARAMETER"

        start = call(base, "PUT", "/pairing/start", {"DEVICE_ID": "test", "DEVICE_NAME": "TV Remote"})
        assert start["ITEM"]["PAIRING_REQ_TOKEN"] == PAIRING_TOKEN

        denied = call(base, "PUT", "/pairing/pair", {
            "DEVICE_ID": "test", "CHALLENGE_TYPE": 1,
            "RESPONSE_VALUE": "9999", "PAIRING_REQ_TOKEN": PAIRING_TOKEN,
        })
        assert denied["STATUS"]["RESULT"] == "PAIRING_DENIED"

        paired = call(base, "PUT", "/pairing/pair", {
            "DEVICE_ID": "test", "CHALLENGE_TYPE": 1,
            "RESPONSE_VALUE": "1234", "PAIRING_REQ_TOKEN": PAIRING_TOKEN,
        })
        assert paired["ITEM"]["AUTH_TOKEN"] == AUTH_TOKEN

        unauthenticated = call(base, "GET", "/state/device/power_mode")
        assert unauthenticated["STATUS"]["RESULT"] == "REQUIRES_PAIRING"

        power = call(base, "GET", "/state/device/power_mode", token=AUTH_TOKEN)
        assert power["ITEMS"][0]["VALUE"] == 1

        missing_keys = call(base, "PUT", "/key_command/", {}, AUTH_TOKEN)
        assert missing_keys["STATUS"]["RESULT"] == "INVALID_PARAMETER"

        invalid_action = call(base, "PUT", "/key_command/", {
            "KEYLIST": [{"CODESET": 3, "CODE": 8, "ACTION": "INVALID"}],
        }, AUTH_TOKEN)
        assert invalid_action["STATUS"]["RESULT"] == "INVALID_PARAMETER"

        commands = [
            {"CODESET": 3, "CODE": 8, "ACTION": "KEYPRESS"},
            {"CODESET": 3, "CODE": 2, "ACTION": "KEYPRESS"},
            *({"CODESET": 0, "CODE": ord(char), "ACTION": "KEYPRESS"} for char in "Hello 123"),
        ]
        accepted = call(base, "PUT", "/key_command/", {"KEYLIST": commands}, AUTH_TOKEN)
        assert accepted["STATUS"]["RESULT"] == "SUCCESS"
        assert SmartCastHandler.command_log[-1]["CODE"] == ord("3")

        for _ in range(250):
            rapid = call(base, "PUT", "/key_command/", {
                "KEYLIST": [{"CODESET": 5, "CODE": 1, "ACTION": "KEYPRESS"}],
            }, AUTH_TOKEN)
            assert rapid["STATUS"]["RESULT"] == "SUCCESS"
        assert len(SmartCastHandler.command_log) == len(commands) + 250

        unknown = call(base, "GET", "/not-a-real-endpoint", token=AUTH_TOKEN)
        assert unknown["STATUS"]["RESULT"] == "URI_NOT_FOUND"
        print("PASS: 11 SmartCast contract scenarios, including 250 rapid commands")
    finally:
        server.shutdown()
        server.server_close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--port", type=int, default=7346)
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    server = ThreadingHTTPServer(("127.0.0.1", args.port), SmartCastHandler)
    print(f"Mock SmartCast HTTP appliance listening on http://127.0.0.1:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
