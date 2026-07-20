"""yxnode (Python) — SPEC-PROOF mirror of the Swift base mesh node.

Purpose (ADR D09): prove the yx node protocol is language-agnostic — a Python
node interoperates with a Swift node byte-for-byte. Production runs the Swift
`yxnode`; this exists to validate the specs.

Same surface as Sources/yxnode/main.swift (ADR D11 + D12):
  Protocol-0 S-expressions exclusively (car-dispatch): (node-hello ...)
  presence, (node-info) receipt, (msg ...) -> spooled verbatim as .sxp.
  (type command)/(type order) is ACTED ON only with a valid Ed25519 (sig)
  from a trusted (key-id) — otherwise REFUSED (signing.md §4).
"""
import argparse, asyncio, os, sys, time, functools
print = functools.partial(print, flush=True)  # daemon logs must stream, not block-buffer
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from yx.YX import YX
from yx.primitives.sexpr import SExpr
from yx.primitives.sexpr_sign import canonical_msg_bytes
from yx.primitives import signer, trusted_signers
from yx_key import resolve_key


def unf_id(dt: datetime | None = None) -> str:
    """Microsecond, sortable id = filename stem = msg-id."""
    dt = dt or datetime.now()
    return f"{dt.strftime('%Y%m%d-%H%M%S')}{dt.microsecond:06d}"


def kv(key: str, val: SExpr) -> SExpr:
    return SExpr.list_([SExpr.sym(key), val])


def write_sxp(spool: str, id: str, raw: str) -> str | None:
    """Spool one received (msg ...) verbatim as ~/ai/mail/YYYY/MM/<id>.sxp.
    Returns the path, or None on failure. (message-format.md §Storage: never UNF/YAML.)"""
    d = os.path.join(spool, datetime.now().strftime("%Y/%m"))
    try:
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, f"{id}.sxp")
        with open(path, "w", encoding="utf-8") as f:
            f.write(raw)
        return path
    except Exception as e:
        print(f"❌ spool write failed: {e}", file=sys.stderr)
        return None


async def main():
    ap = argparse.ArgumentParser(prog="yxnode", description="Python spec-proof mesh node (Protocol-0 s-expr)")
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
    ap.add_argument("--trusted-signers")
    ap.add_argument("--send-test", metavar="TO")
    ap.add_argument("--send-command", metavar="TO")
    ap.add_argument("--send-body")
    ap.add_argument("--sign-as", metavar="AGENT")
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

    # D12: trusted-signers store — loaded once at boot. Missing => nothing trusted.
    trusted_path = os.path.expanduser(a.trusted_signers) if a.trusted_signers \
        else trusted_signers.default_path()
    trusted = trusted_signers.load(trusted_path)

    print(f"🧩 yxnode(py) '{node_id}' agents={agents} port={a.port} mesh={a.mesh} key={key_src}")
    print(f"📬 spool: {spool}")
    print(f"🔏 trusted signers: {len(trusted)} ({trusted_path})")

    yx = YX(port=a.port, key=key)

    # Presence directory: node -> (agents, last_seen)
    presence: dict[str, tuple[list[str], float]] = {}
    started = time.time()

    # node-hello — presence beacon. Updates the directory.
    async def on_hello(expr: SExpr):
        f = expr.field("node")
        frm = (f.string_value if f is not None else None) or "?"
        ag_f = expr.field("agents")
        ag_csv = (ag_f.string_value if ag_f is not None else None) or ""
        ag = ag_csv.split(",") if ag_csv else []
        is_new = frm not in presence
        presence[frm] = (ag, time.time())
        if is_new:
            print(f"🟢 discovered node '{frm}' agents={ag}")

    # node-info — identity query (log receipt; reply needs a sender address).
    async def on_info(expr: SExpr):
        up = int(time.time() - started)
        print(f"📨 node-info received (node={node_id} agents={','.join(agents)} uptime={up}s)")

    # msg — inbound agent message -> spool verbatim as .sxp if addressed locally.
    async def on_msg(expr: SExpr):
        to_f = expr.field("to")
        to = [t.strip() for t in ((to_f.string_value if to_f is not None else None) or "").split(",")]
        local_hit = "@all" in to or any(
            t in agents or t == node_id or t.startswith(f"{node_id}/") for t in to)
        if not local_hit:
            return  # not for us; ignore (filtering, message-format.md)

        # D12 authority: (type command) / (type order) is ACTED ON only with a
        # valid (sig) from a trusted (key-id). Never trust `from` — the
        # signature is the truth. (signing.md §4)
        type_f = expr.field("type")
        msg_type = ""
        if type_f is not None:
            msg_type = type_f.sym_value or type_f.string_value or ""
        if msg_type in ("command", "order"):
            body_f = expr.field("body")
            body = (body_f.string_value if body_f is not None else None) or ""
            key_id_f = expr.field("key-id")
            sig_f = expr.field("sig")
            key_id = key_id_f.string_value if key_id_f is not None else None
            sig = sig_f.string_value if sig_f is not None else None
            pubkey = trusted.get(key_id) if key_id else None  # key-id ∈ trusted-signers
            if (key_id and sig and pubkey
                    and signer.verify(canonical_msg_bytes(expr), sig, pubkey)):
                print(f"✅ EXECUTED command from {key_id}: {body}")
            else:
                print(f"🚫 REFUSED command (untrusted/unsigned): {body}")
            return

        id_f = expr.field("id")
        given_id = (id_f.string_value if id_f is not None else None) or ""
        rid = given_id if given_id else unf_id()
        path = write_sxp(spool, rid, expr.serialize())
        if path:
            print(f"📥 delivered → {path}")

    yx.register_sexp("node-hello", on_hello)
    yx.register_sexp("node-info", on_info)
    yx.register_sexp("msg", on_msg)

    await yx._coordinator.start()   # bind + listen without the run-forever wait
    print(f"✅ yxnode(py) up. peers={peers}")

    def iso_now() -> str:
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Send-test (throwaway loopback proof: one (msg ...) to each peer, then exit)
    if a.send_test:
        body = a.send_body or "loopback test"
        await asyncio.sleep(0.5)   # let peers come up
        msg = SExpr.list_([
            SExpr.sym("msg"),
            kv("v", SExpr.num(1)),
            kv("id", SExpr.string(unf_id())),
            kv("type", SExpr.sym("note")),
            kv("from", SExpr.string(agents[0] if agents else f"{node_id}/claude")),
            kv("to", SExpr.string(a.send_test)),
            kv("created", SExpr.string(iso_now())),
            kv("subject", SExpr.string("send-test")),
            kv("body", SExpr.string(body)),
        ])
        for h, pt in peers:
            await yx.sendSexpr(msg, h, pt)
        print(f"📤 send-test (msg …) → {a.send_test} via {len(peers)} peer(s)")
        await asyncio.sleep(1.0)   # let the send land
        await yx.stop()
        return

    # Send-command (D12: one (msg (type command) ...), signed or unsigned, then exit)
    if a.send_command:
        body = a.send_body or "command"
        sign_as = a.sign_as
        await asyncio.sleep(0.5)   # let peers come up
        children = [
            SExpr.sym("msg"),
            kv("v", SExpr.num(1)),
            kv("id", SExpr.string(unf_id())),
            kv("type", SExpr.sym("command")),
            kv("from", SExpr.string(sign_as or (agents[0] if agents else f"{node_id}/claude"))),
            kv("to", SExpr.string(a.send_command)),
            kv("created", SExpr.string(iso_now())),
            kv("body", SExpr.string(body)),
        ]
        if sign_as:
            # Bind the signer identity via (key-id ...), sign the canonical
            # bytes (which include key-id, exclude sig), then append (sig ...).
            children.append(kv("key-id", SExpr.string(sign_as)))
            canonical = canonical_msg_bytes(SExpr.list_(children))
            sig = signer.sign(canonical, agent_id=sign_as)
            if sig is None:
                print(f"❌ no signing key for '{sign_as}' — run: yx_key.py sign-gen --id {sign_as}",
                      file=sys.stderr)
                await yx.stop()
                sys.exit(1)
            children.append(kv("sig", SExpr.string(sig)))
        msg = SExpr.list_(children)
        for h, pt in peers:
            await yx.sendSexpr(msg, h, pt)
        mode = f"signed as {sign_as}" if sign_as else "UNSIGNED"
        print(f"📤 send-command ({mode}) → {a.send_command} via {len(peers)} peer(s)")
        await asyncio.sleep(1.0)   # let the send land
        await yx.stop()
        return

    # Heartbeat: announce presence to explicit peers + optional broadcast.
    agent_csv = ",".join(agents)

    def hello() -> SExpr:
        return SExpr.list_([
            SExpr.sym("node-hello"),
            kv("node", SExpr.string(node_id)),
            kv("agents", SExpr.string(agent_csv)),
        ])

    async def heartbeat():
        while True:
            for h, pt in peers:
                await yx.sendSexpr(hello(), h, pt)
            if a.broadcast:
                await yx.sendSexpr(hello(), a.broadcast, a.port)
            await asyncio.sleep(a.heartbeat)

    hb = asyncio.create_task(heartbeat())
    try:
        if a.shutdown_after:
            await asyncio.sleep(a.shutdown_after)
            cut = time.time() - a.heartbeat * 3
            online = sorted(n for n, (_, seen) in presence.items() if seen >= cut)
            print(f"🛑 shutdown. online nodes seen: {online}")
        else:
            print("🔄 running (Ctrl+C to stop)")
            await asyncio.Event().wait()
    finally:
        hb.cancel()
        await yx.stop()


if __name__ == "__main__":
    asyncio.run(main())
