"""Generate reckon-gateway's C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: reckon-gateway and every system it talks to
  c4-components.svg  Level 3: what the one release is made of

Every box and every arrow below is taken from the code on this branch: the
supervisor's children, the services registered with grpc-erl, the cowboy routes,
the env vars that pick a mode (RECKON_GATEWAY_STORE_ENABLED,
RECKON_GATEWAY_CLUSTERS_PATH) and the ports the Dockerfile exposes. When the code
changes, change this file and re-run it; a diagram that still names a component
the release lost is drift.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS
custom properties (rsvg-convert renders those black), so the SVGs render the same
on GitHub, in IDE previews and through rsvg-convert. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c4.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # the platform it runs on
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-rel-s {{ font-family: {SANS}; font-size: 10px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel, .t-rel-s { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel, .t-rel-s { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Platform it runs on"),
          ("b-ext", "External system"), ("b-cmp", "Component")]
BOUNDARY = ("bound", "Boundary")


def height_for(desc):
    """The height a box needs: title, kind line, then one line of description."""
    return 74 + 16 * len(desc)


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def box(self, cls, x, y, w, name, kind, desc, person=False, code=False):
        h = height_for(desc)
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)
        return h

    def bound(self, x, y, w, h, label):
        self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
        self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, later=False):
        self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')

    def legend(self, y, boundary=True):
        x = 24
        for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
            self.text("t-leg", x + 30, y + 12, label)
            x += 40 + 6.9 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "reckon-gateway system context", 1000, 800)
    d.box("b-per", 30, 30, 250, "Application developer", "[Person]",
          ["Writes a polyglot client against", "reckon.gateway.v1, from the stubs", "reckon-proto generates"], person=True)
    d.box("b-per", 375, 30, 250, "Operator", "[Person]",
          ["Pulls the image, writes", "clusters.eterm or store.eterm,", "watches the admin UI"], person=True)
    d.box("b-per", 720, 30, 250, "Cluster owner", "[Person]",
          ["Runs the ReckonDB clusters the", "catalogue federates, and supplies", "their Erlang cookies"], person=True)
    d.box("b-ext", 30, 210, 250, "gRPC client", "[External: any language, 50051]",
          ["reckon-go and the generated", "stubs, over HTTP/2 in the clear.",
           "Stream, Subscription, Snapshot,", "Health, Temporal, Schema,",
           "Admin, Stores and DCB services"])
    d.box("b-sys", 375, 210, 250, "reckon-gateway", "[In scope: OTP 28 release 0.30.2, OCI image]",
          ["One release serving the ReckonDB", "API over gRPC and HTTP/JSON at",
           "once. In catalogue mode it holds", "no data: each call is dispatched",
           "to the cluster owning the store"])
    d.box("b-ext", 720, 210, 250, "ReckonDB clusters", "[External: N remote BEAM clusters]",
          ["Each runs reckon_gater and", "reckon_db over Khepri and Ra.",
           "The gateway reaches them over", "Erlang distribution and calls",
           "reckon_gater_api there (EPMD)"])
    d.box("b-ext", 30, 420, 250, "Log handler", "[External: what the operator attaches]",
          ["logger is the default handler.", "Prometheus or OTLP is attached by",
           "the operator; none is bundled"])
    d.box("b-mac", 375, 420, 250, "Embedded ReckonDB", "[Platform: in this VM when embedded]",
          ["In embedded mode", "(STORE_ENABLED=true): Khepri and",
           "Ra on /data, Ra ports 5000-5100,", "peers found by multicast and a",
           "shared cluster secret"])
    d.box("b-ext", 720, 420, 250, "HTTP/JSON client, browser", "[External: port 8080]",
          ["curl, scripts and the admin UI", "at /admin, plus the live event",
           "stream at /v1/admin/events over", "SSE. No authentication"])
    d.edge("M155 157V210"); d.text("t-rel", 163, 188, "writes a client against the proto")
    d.edge("M500 157V210"); d.text("t-rel", 508, 188, "runs, configures, upgrades")
    d.edge("M845 157V210"); d.text("t-rel", 853, 170, "operates the clusters")
    d.edge("M280 285H375"); d.text("t-rel", 327, 268, "gRPC, HTTP/2", anchor="middle"); d.text("t-rel", 327, 305, "port 50051", anchor="middle")
    d.edge("M625 285H720"); d.text("t-rel", 672, 268, "rpc:call", anchor="middle"); d.text("t-rel-s", 672, 305, "reckon_gater_api", anchor="middle")
    d.edge("M625 350H672V490H720"); d.text("t-rel", 664, 420, "HTTP/JSON, SSE", anchor="middle", rotate=90)
    d.edge("M500 370V420"); d.text("t-rel", 508, 400, "boots it in-process")
    d.edge("M420 380V395H155V420"); d.text("t-rel", 163, 412, "telemetry events")
    d.text("t-desc", 30, 596, "The three modes are three env settings, not three programs: catalogue (STORE_ENABLED=false,")
    d.text("t-desc", 30, 612, "CLUSTERS_PATH set), embedded (STORE_ENABLED=true, no clusters path), and hybrid, which runs both.")
    d.text("t-desc", 30, 632, "Nothing here terminates TLS: the gRPC options are empty and the HTTP listener is cowboy_clear, so a")
    d.text("t-desc", 30, 648, "reverse proxy in front of it is the operator's own system, not part of this one.")
    d.legend(760, boundary=False)
    d.write()


def components():
    d = Diagram("c4-components.svg", "reckon-gateway components", 1000, 1200)
    d.bound(16, 40, 968, 948, "reckon_gateway release [Container: OTP 28 relx release 0.30.2, ports 50051 and 8080]")
    d.box("b-cmp", 32, 70, 624, "reckon_gateway_app, reckon_gateway_sup", "[application and top supervisor]",
          ["Attaches the telemetry handlers, starts the gRPC server inline in init/1, then its children:",
           "catalogue, metrics, fleet ingest, HTTP listener and cluster supervisor. The embedded store",
           "starter and the local connector are started only when RECKON_GATEWAY_STORE_ENABLED is true."], code=True)
    d.box("b-cmp", 664, 70, 304, "reckon_gateway_config", "[app env, then OS env, then default]",
          ["Validates clusters.eterm, resolves the", "embedded store spec, and keeps per-peer",
           "cookies out of the catalogue."], code=True)
    d.box("b-sys", 32, 266, 624, "gRPC service layer", "[nine *_service modules, grpc-erl and cowboy HTTP/2, port 50051]",
          ["StreamService, SubscriptionService (server-streaming with acks), SnapshotService,",
           "HealthService, TemporalService, SchemaService, StoresService and DcbService; the AdminService",
           "answers store stats, stream info and event-type summary, scavenge (dry run and matching), the",
           "seven stream-link calls, and a catalogue reload with its status."], code=True)
    d.box("b-cmp", 664, 266, 304, "Generated behaviours and codecs", "[grpc_plugin, reckon-proto v0.8.0]",
          ["reckon_gateway_v_1_*_service_bhvr and", "_client per service, and the protobuf",
           "codecs reckon_*_pb.erl. Generated at", "build time by rebar3 grpc gen, into src/."], code=True)
    d.box("b-cmp", 32, 462, 296, "reckon_gateway_dispatch", "[dispatch]",
          ["Finds the store id in the catalogue,", "picks a member of its cluster and",
           "rpc:call/4s reckon_gater_api there", "with a 5 s timeout. store_unknown and",
           "cluster_unavailable become statuses."], code=True)
    d.box("b-cmp", 348, 462, 296, "reckon_gateway_catalogue", "[gen_server]",
          ["The merged store id to cluster view,", "with cluster info and the announce and",
           "retire events, fanned out to SSE", "subscribers. It never holds a cookie:",
           "the connector keeps that itself."], code=True)
    d.box("b-cmp", 664, 462, 304, "Connectors and federation", "[clusters_sup, cluster_connector]",
          ["One connector per clusters.eterm entry:", "dist connect, per-peer cookie, then",
           "rpc:call of reckon_db_store_registry:", "list_stores/0 each refresh tick.",
           "A reload diffs, adds and removes."], code=True)
    d.box("b-cmp", 32, 658, 296, "reckon_gateway_local_connector", "[gen_server]",
          ["In embedded mode, polls the local", "reckon_db_store_registry and publishes",
           "those stores into the catalogue, so", "dispatch answers on this node."], code=True)
    d.box("b-cmp", 348, 658, 296, "reckon_gateway_store_starter", "[transient worker]",
          ["Builds the store_config from the env", "(pools, timeout, indexes, integrity)",
           "and calls reckon_db_sup:start_store/1,", "then returns ignore."], code=True)
    d.box("b-cmp", 664, 658, 304, "HTTP/JSON, admin UI, SSE", "[cowboy_clear, port 8080]",
          ["reckon_gateway_http_listener mounts the", "routes; _http_streams, _http_dcb,",
           "_http_health and _http_sse answer them", "through the JSON, params and filter",
           "helpers in reckon_gateway_http; the admin", "UI is priv/static/admin."], code=True)
    d.box("b-cmp", 32, 838, 624, "Observability", "[metrics, fleet ingest, telemetry]",
          ["reckon_gateway_metrics keeps ETS counters and one-second ring buckets, and sizes snapshot_json/0 for",
           "/v1/admin/metrics; fleet_ingest polls each store's global_event_count every 5 s for events per second.",
           "reckon_gateway_telemetry is the attach, detach and emit facade."], code=True)
    d.box("b-cmp", 664, 838, 304, "Translation and errors", "[convert, error]",
          ["reckon_gateway_convert maps proto to", "gater types, parses store ids and builds",
           "subscription types; reckon_gateway_error", "wraps a failure as a gRPC status."], code=True)
    d.box("b-ext", 32, 1010, 296, "gRPC and HTTP clients", "[External]",
          ["The generated stubs in any language,", "curl, and the browser at /admin"], None)
    d.box("b-ext", 348, 1010, 296, "ReckonDB clusters", "[External: over Erlang distribution]",
          ["reckon_gater_api, called by dispatch", "with rpc:call/4"], None)
    d.box("b-mac", 664, 1010, 304, "reckon_db, Khepri, Ra", "[Platform: in this VM when embedded]",
          ["The store, its Raft log and /data", "when STORE_ENABLED is true"], None)
    d.edge("M240 192V266"); d.text("t-rel", 248, 236, "starts")
    d.edge("M816 192V266"); d.text("t-rel", 824, 236, "resolves")
    d.edge("M180 388V462"); d.text("t-rel", 188, 436, "looks up")
    d.edge("M498 388V462"); d.text("t-rel", 506, 436, "publishes")
    d.edge("M816 388V462"); d.text("t-rel", 824, 436, "reloads")
    d.edge("M664 527H644"); d.text("t-rel", 654, 500, "announces", anchor="middle")
    d.edge("M180 658V636H498V616"); d.text("t-rel", 340, 630, "publishes", anchor="middle")
    d.edge("M758 658V636H180V616"); d.text("t-rel", 640, 630, "REST and SSE calls", anchor="middle")
    d.edge("M180 1010V988"); d.text("t-rel", 188, 1002, "in on gRPC 50051 and HTTP 8080")
    d.edge("M498 988V1010"); d.text("t-rel", 506, 1002, "rpc:call reckon_gater_api")
    d.edge("M816 988V1010"); d.text("t-rel", 824, 1002, "start_store")
    d.legend(1150)
    d.write()


if __name__ == "__main__":
    for make in (context, components):
        make()
