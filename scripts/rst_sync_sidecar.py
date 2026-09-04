"""Reverse-proxies to a running sphinx-autobuild backend, injecting a small
script that receives cursor-position pushes over SSE and scrolls the page
to follow the edited heading, without ever touching window focus.

Runs inside the same environment as sphinx-autobuild (same `pixi run`/`uv
run` prefix, or the interpreter behind its own shebang), so starlette,
uvicorn and docutils are already present: all three are sphinx-autobuild's
own dependencies.
"""

from __future__ import annotations

import argparse
import asyncio
import http.client
import json
import re
import socket
from urllib.parse import urlsplit

from docutils.nodes import make_id
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import Response, StreamingResponse
from starlette.routing import Route

INJECTED_SCRIPT = b"""
<script>
(function () {
  function apply(data) {
    if (data.page && data.page !== location.pathname.replace(/^\\//, "")) return;
    var el = data.anchor && document.getElementById(data.anchor);
    if (el) {
      var next = data.next_anchor && document.getElementById(data.next_anchor);
      var top = el.getBoundingClientRect().top + window.scrollY;
      if (next && typeof data.frac === "number") {
        var nextTop = next.getBoundingClientRect().top + window.scrollY;
        top += (nextTop - top) * data.frac;
      }
      window.scrollTo({ top: top, behavior: "auto" });
    } else if (typeof data.frac === "number") {
      var doc = document.documentElement;
      var max = doc.scrollHeight - doc.clientHeight;
      window.scrollTo({ top: max * data.frac, behavior: "auto" });
    }
  }
  var es = new EventSource("/__rst_sync/stream");
  es.onmessage = function (ev) { apply(JSON.parse(ev.data)); };
})();
</script>
"""

# A docutils section heading is a text line immediately followed (and
# optionally preceded, for the overline+title+underline form) by a line of
# one repeated "adornment" character, at least as long as the title.
_ADORNMENT = re.compile(r"^([=\-`:'\"~^_*+#<>.])\1{2,}\s*$")


def scan_headings(path: str) -> list[tuple[int, str]]:
    """[(1-based line of the title text, slug), ...] in document order.

    Reads the file off disk rather than the live buffer: sphinx-autobuild
    only rebuilds on save, so disk is the version actually being served,
    and using unsaved edits would drift the mapping until the next save
    anyway.
    """
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []

    headings: list[tuple[int, str]] = []
    seen: dict[str, int] = {}
    for i, raw in enumerate(lines):
        text = raw.strip()
        if not text:
            continue
        underline = lines[i + 1] if i + 1 < len(lines) else ""
        if not (_ADORNMENT.match(underline) and len(underline.strip()) >= len(text)):
            continue
        slug = make_id(text) or "section"
        if slug in seen:
            seen[slug] += 1
            slug = f"{slug}-{seen[slug]}"
        else:
            seen[slug] = 0
        headings.append((i + 1, slug))
    return headings


def locate(headings: list[tuple[int, str]], line: int) -> tuple[str | None, str | None, float]:
    """-> (anchor, next_anchor, frac in [0, 1]) for `line`."""
    if not headings:
        return None, None, 0.0

    prev: tuple[int, str] | None = None
    nxt: tuple[int, str] | None = None
    for ln, slug in headings:
        if ln <= line:
            prev = (ln, slug)
        else:
            nxt = (ln, slug)
            break

    if prev is None:
        first_line, first_slug = headings[0]
        frac = min(1.0, max(0.0, line / max(first_line, 1)))
        return None, first_slug, frac

    if nxt is None:
        return prev[1], None, 0.0

    span = max(nxt[0] - prev[0], 1)
    frac = min(1.0, max(0.0, (line - prev[0]) / span))
    return prev[1], nxt[1], frac


async def proxy(request: Request, backend_host: str, backend_port: int) -> Response:
    def do_fetch():
        conn = http.client.HTTPConnection(backend_host, backend_port, timeout=10)
        headers = {k: v for k, v in request.headers.items() if k.lower() not in ("host", "connection")}
        path = request.url.path
        if request.url.query:
            path += "?" + request.url.query
        conn.request(request.method, path, headers=headers)
        resp = conn.getresponse()
        return resp.status, resp.getheaders(), resp.read()

    status, headers, body = await asyncio.to_thread(do_fetch)
    out_headers = {k: v for k, v in headers if k.lower() not in ("content-length", "connection", "transfer-encoding")}
    content_type = next((v for k, v in headers if k.lower() == "content-type"), "")
    if content_type.startswith("text/html"):
        body += INJECTED_SCRIPT
    out_headers["Content-Length"] = str(len(body))
    return Response(content=body, status_code=status, headers=out_headers, media_type=content_type or None)


subscribers: set[asyncio.Queue] = set()
last_payload: dict | None = None


async def stream(_request: Request):
    queue: asyncio.Queue = asyncio.Queue()
    subscribers.add(queue)
    if last_payload is not None:
        await queue.put(last_payload)

    async def body():
        try:
            while True:
                data = await queue.get()
                yield f"data: {json.dumps(data)}\n\n"
        finally:
            subscribers.discard(queue)

    return StreamingResponse(body(), media_type="text/event-stream")


async def cursor(request: Request):
    global last_payload
    payload_in = await request.json()
    headings = scan_headings(payload_in["file"])
    anchor, next_anchor, frac = locate(headings, int(payload_in["line"]))
    payload = {"page": payload_in.get("page"), "anchor": anchor, "next_anchor": next_anchor, "frac": frac}
    last_payload = payload
    for queue in list(subscribers):
        queue.put_nowait(payload)
    return Response(status_code=204)


def make_app(backend_host: str, backend_port: int) -> Starlette:
    async def catch_all(request: Request) -> Response:
        return await proxy(request, backend_host, backend_port)

    return Starlette(
        routes=[
            Route("/__rst_sync/stream", stream, methods=["GET"]),
            Route("/__rst_sync/cursor", cursor, methods=["POST"]),
            Route("/{path:path}", catch_all, methods=["GET", "HEAD"]),
        ]
    )


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def main() -> None:
    import uvicorn

    parser = argparse.ArgumentParser()
    parser.add_argument("--backend-url", required=True)
    args = parser.parse_args()

    backend = urlsplit(args.backend_url)
    port = find_free_port()
    print(f"Serving on http://127.0.0.1:{port}", flush=True)
    uvicorn.run(make_app(backend.hostname, backend.port), host="127.0.0.1", port=port, log_level="warning")


if __name__ == "__main__":
    main()
