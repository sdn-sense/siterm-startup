#!/usr/bin/env python3
# pylint: disable=W1203
"""VPP Prometheus Exporter with Caching and IPv6 Support"""
import os
import subprocess
import threading
import time
import random
import signal
import socket
import gzip
import logging
from io import BytesIO
from http.server import BaseHTTPRequestHandler, HTTPServer

import requests

LOGGER = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')

class HTTPServerV6(HTTPServer):
    """HTTP server supporting IPv6."""
    address_family = socket.AF_INET6

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------
CACHE_REFRESH_SECONDS = int(os.environ.get("VPPMON_CACHE_REFRESH_SECONDS", "30"))
EXPORTER_START_TIMEOUT = int(os.environ.get("VPPMON_EXPORTER_START_TIMEOUT", "30"))
EXPORTER_SCRAPE_TIMEOUT = int(os.environ.get("VPPMON_EXPORTER_SCRAPE_TIMEOUT", "30"))
EXPORTER_KILL_TIMEOUT = int(os.environ.get("VPPMON_EXPORTER_KILL_TIMEOUT", "30"))
BIND_ADDRESS = os.environ.get("VPPMON_BIND_ADDRESS", "::")
BIND_PORT = int(os.environ.get("VPPMON_BIND_PORT", "1234"))
RANDOM_PORT_FROM = int(os.environ.get("VPPMON_RANDOM_PORT_FROM", "30000"))
RANDOM_PORT_TO = int(os.environ.get("VPPMON_RANDOM_PORT_TO", "40000"))
LOG_LEVEL = os.environ.get("VPPMON_LOG_LEVEL", "INFO").upper()

LOGGER.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))
LOGGER.info("Logger initialized with level %s", LOG_LEVEL)

PROXY_BIND = (BIND_ADDRESS, BIND_PORT)

EXPORTER_CMD_BASE = ["vpp_prometheus_export", "port", None, "v2", "^/sys/heartbeat",
                     "^/sys/last_stats_clear", "^/sys/boottime", "^/sys/vector_rate",
                     "^/sys/vector_rate_per_worker", "^/sys/loops_per_worker",
                     "^/sys/num_worker_threads", "^/sys/last_update", "^/sys/input_rate",
                     "^/mem/", "^/nodes/", "^/interfaces/", "^/buffer-pools/", "^/err/"]

cache = ""
cache_ts = 0.0
cache_ok = 0

lock = threading.Lock()
stop_event = threading.Event()


def random_port():
    """Generate a random port within the specified range."""
    return random.randint(RANDOM_PORT_FROM, RANDOM_PORT_TO)

def wait_for_port(port, timeout):
    """Wait for a TCP port to become available on localhost."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection(("::1", port), timeout=0.2):
                return True
        except OSError:
            time.sleep(0.1)
    return False

def collection_loop():
    """Background collection loop."""
    global cache, cache_ts, cache_ok

    while not stop_event.is_set():
        port = random_port()
        url = f"http://[::1]:{port}/metrics"

        cmd = EXPORTER_CMD_BASE.copy()
        cmd[2] = str(port)

        proc = None

        try:
            LOGGER.info(f"[collector] starting exporter on port {port}")

            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            if not wait_for_port(port, EXPORTER_START_TIMEOUT):
                raise RuntimeError("exporter did not start listening")

            r = requests.get(url, timeout=EXPORTER_SCRAPE_TIMEOUT)
            r.raise_for_status()

            with lock:
                cache = r.text
                cache_ts = time.time()
                cache_ok = 1

            LOGGER.info(f"[collector] scrape successful ({len(cache)} bytes)")

        except Exception as e:
            with lock:
                cache_ok = 0
            LOGGER.warning(f"[collector] collection failed: {e}")

        finally:
            if proc:
                proc.terminate()
                try:
                    proc.wait(timeout=EXPORTER_KILL_TIMEOUT)
                except subprocess.TimeoutExpired:
                    proc.kill()

        stop_event.wait(CACHE_REFRESH_SECONDS)

class MetricsHandler(BaseHTTPRequestHandler):
    """ HTTP handler for serving cached metrics. """

    def do_GET(self):
        """ Handle GET requests. """
        LOGGER.info(f"[http] received request for {self.path} from {self.client_address}")
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return

        with lock:
            body = cache
            ts = cache_ts
            ok = cache_ok

        if not body:
            body = "# vpp_exporter_up 0\n"

        body += (
            f"\n# HELP vpp_exporter_cache_age_seconds Cache age\n"
            f"# TYPE vpp_exporter_cache_age_seconds gauge\n"
            f"vpp_exporter_cache_age_seconds {time.time() - ts if ts else 0}\n"
            f"# HELP vpp_exporter_last_run_success Last run success\n"
            f"# TYPE vpp_exporter_last_run_success gauge\n"
            f"vpp_exporter_last_run_success {ok}\n"
        )

        raw = body.encode("utf-8")

        accept_encoding = self.headers.get("Accept-Encoding", "")

        if "gzip" in accept_encoding.lower():
            buf = BytesIO()
            with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
                gz.write(raw)
            data = buf.getvalue()

            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)


def shutdown(server):
    """ Shutdown the server and stop the collection loop. """
    stop_event.set()
    server.shutdown()


def main():
    """ Main function to start the server and collection loop. """
    collector = threading.Thread(target=collection_loop, daemon=True)
    collector.start()

    server = HTTPServerV6(PROXY_BIND, MetricsHandler)

    signal.signal(signal.SIGINT, lambda s, f: shutdown(server))
    signal.signal(signal.SIGTERM, lambda s, f: shutdown(server))

    print(f"Serving cached metrics on http://[{PROXY_BIND[0]}]:{PROXY_BIND[1]}/metrics")

    server.serve_forever()

if __name__ == "__main__":
    LOGGER.info("Starting VPP Prometheus Exporter with Caching and IPv6 Support")
    main()
