"""yxnode (Python) — SPEC-PROOF mirror of the Swift base mesh node.

Purpose (ADR D09): prove the yx node protocol is language-agnostic — a Python
node interoperates with a Swift node (presence + msg.deliver + UNF) byte-for-byte.
Production runs the Swift `yxnode`; this exists to validate the specs.

Same surface as Sources/yxnode/main.swift:
  node.hello (heartbeat presence) · node.info (RPC) · msg.deliver -> UNF file.
"""
import argparse, asyncio, os, sys, math, time, functools
print = functools.partial(print, flush=True)  # daemon logs must stream, not block-buffer
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from yx.YX import YX
from yx.rpc.dispatcher import RPCRequest
from yx_key import resolve_key


def unf_id(dt: datetime | None = None) -> str:
    dt = dt or datetime.now()
    return f"{dt.strftime('%Y%m%d-%H%M%S')}{dt.microsecond:06d}"


def write_unf(spool: str, *, id: str, frm: str, to: list[str], typ: str,
              subject: str, refs: list[str], body: str) -> str | None:
    now = datetime.now()
    d = os.path.join(spool, now.strftime("%Y/%m"))
    theme = typ.split(".")[0] if typ else typ
    to_list = ", ".join(f'"{t}"' for t in to)
    ref_list = ", ".join(f'"{r}"' for r in refs if r)
    created = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
    doc = (f"---\nid: \"{id}\"\ntype: message\nstatus: unread\nsource: yxbus\n"
           f"from: \"{frm}\"\nto: [{to_list}]\nsubject: \"{subject}\"\n"
           f"themes: [{theme}]\nrefs: [{ref_list}]\ncreated: \"{created}\"\n---\n{body}")
    try:
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, f"{id}.md")
        with open(path, "w") as f:
            f.write(doc)
        return path
    except Exception as e:
        print(f"❌ spool write failed: {e}", file=sys.stderr)
        return None


async def main():
    ap = argparse.ArgumentParser(prog="yxnode", description="Python spec-proof mesh node")
    ap.add_argument("--node", default=os.uname().nodename.split(".")[0])
    ap.add_argument("--port", type=int, default=9720)
    ap.add_argument("--peers", default="")
    ap.add_argument("--mesh", default="agents")
    ap.add_argument("--key")
    ap.add_argument("--agents")
    ap.add_argument("--heartbeat", type=float, default=5.0)
    ap.add_argument("--spool", default=os.path.expanduser("~/ai/mail"))
    ap.add_argument("--broadcast")
    ap.add_argument("--shutdown-after", type=float)
    a = ap.parse_args()

    node_id = a.node
    agents = (a.agents or f"{node_id}/claude").split(",")
    spool = os.path.expanduser(a.spool)
    peers = []
    for p in filter(None, a.peers.split(",")):
        h, _, pt = p.partition(":")
        if pt:
            peers.append((h, int(pt)))

    key, key_src = resolve_key(a.key, a.mesh)
    print(f"🧩 yxnode(py) '{node_id}' agents={agents} port={a.port} mesh={a.mesh} key={key_src}")
    print(f"📬 spool: {spool}")

    yx = YX(port=a.port, key=key)
    seen: set[str] = set()
    started = time.time()

    async def on_hello(req: RPCRequest):
        frm = str(req.params.get("node", "?"))
        ag = str(req.params.get("agents", "")).split(",") if req.params.get("agents") else []
        if frm and frm != node_id and frm not in seen:
            seen.add(frm)
            print(f"🟢 discovered node '{frm}' agents={ag}")

    async def on_info(req: RPCRequest):
        # best-effort reply; the proof cares about presence + delivery
        print(f"📨 node.info asked ({req.id})")

    async def on_deliver(req: RPCRequest):
        to = str(req.params.get("to", "")).split(",")
        local = "@all" in to or any(
            t in agents or t == node_id or t.startswith(f"{node_id}/") for t in to)
        if not local:
            return
        gid = str(req.params.get("id") or "")
        rid = gid if gid else unf_id()
        path = write_unf(spool, id=rid, frm=str(req.params.get("from", "?")), to=to,
                         typ=str(req.params.get("type", "note")),
                         subject=str(req.params.get("subject", "")),
                         refs=str(req.params.get("refs", "")).split(","),
                         body=str(req.params.get("body", "")))
        if path:
            print(f"📥 delivered → {path}")

    yx.register_rpc("node.hello", on_hello)
    yx.register_rpc("node.info", on_info)
    yx.register_rpc("msg.deliver", on_deliver)

    await yx._coordinator.start()   # bind + listen without the run-forever wait
    print(f"✅ yxnode(py) up. peers={peers}")

    async def heartbeat():
        while True:
            msg = {"method": "node.hello",
                   "params": {"node": node_id, "agents": ",".join(agents)}}
            for h, pt in peers:
                await yx.sendText(msg, h, pt)
            if a.broadcast:
                await yx.sendText(msg, a.broadcast, a.port)
            await asyncio.sleep(a.heartbeat)

    hb = asyncio.create_task(heartbeat())
    try:
        if a.shutdown_after:
            await asyncio.sleep(a.shutdown_after)
            print(f"🛑 shutdown. online nodes seen: {sorted(seen)}")
        else:
            print("🔄 running (Ctrl+C to stop)")
            await asyncio.Event().wait()
    finally:
        hb.cancel()
        await yx.stop()


if __name__ == "__main__":
    asyncio.run(main())
