#!/usr/bin/env python3
"""Minimal webhook to trigger an OctoDNS reconcile (POST /sync)."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import os

HOST = os.environ.get("GITOPS_WEBHOOK_HOST", "0.0.0.0")
PORT = int(os.environ.get("GITOPS_WEBHOOK_PORT", "8088"))
SYNC_FLAG = os.environ.get("GITOPS_SYNC_FLAG", "/tmp/octodns-sync-requested")
TOKEN = os.environ.get("GITOPS_WEBHOOK_TOKEN", "")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[gitops-webhook] {self.address_string()} - {fmt % args}")

    def _auth_ok(self) -> bool:
        if not TOKEN:
            return True
        auth = self.headers.get("Authorization", "")
        return auth in (f"Bearer {TOKEN}", f"token {TOKEN}")

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        if self.path == "/ready":
            last = "/tmp/gitops-last-success"
            if os.path.isfile(last):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(open(last).read().encode())
            else:
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b"not yet reconciled")
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        if self.path != "/sync":
            self.send_response(404)
            self.end_headers()
            return
        if not self._auth_ok():
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"unauthorized")
            return
        open(SYNC_FLAG, "w").close()
        self.send_response(202)
        self.end_headers()
        self.wfile.write(b"sync queued")


if __name__ == "__main__":
    print(f"[gitops-webhook] listening on {HOST}:{PORT}")
    HTTPServer((HOST, PORT), Handler).serve_forever()
