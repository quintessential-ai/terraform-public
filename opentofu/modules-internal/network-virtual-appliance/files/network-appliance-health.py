#!/usr/bin/env python3
"""Answers the load balancers' health probes: 200 while this instance takes new flows, 503 once it drains."""

import http.server
import sys
from pathlib import Path

DRAINING_FLAG = Path("/run/network-appliance/draining")


class HealthHandler(http.server.BaseHTTPRequestHandler):
    """Reports whether this instance takes new flows."""

    def do_GET(self) -> None:
        if DRAINING_FLAG.exists():
            self.send_response(503)
        else:
            self.send_response(200)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002 - the base class's signature
        """Silences the probe every few seconds would otherwise log."""


port = int(sys.argv[1])
http.server.ThreadingHTTPServer(("", port), HealthHandler).serve_forever()
