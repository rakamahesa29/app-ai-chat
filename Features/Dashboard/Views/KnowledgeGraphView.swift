import SwiftUI
#if os(macOS)
import WebKit
#else
import WebKit
#endif

// MARK: - Knowledge Graph View (vis.js via WebKit — identical to web dashboard)
struct KnowledgeGraphView: View {
    @State private var stats: GraphStatsData? = nil
    @State private var rooms: [GraphRoomData] = []
    @State private var selectedRoomID: Int? = nil
    @State private var isLoading = false
    @State private var errorText: String? = nil

    var body: some View {
        HermesCard(padding: HermesSpacing.xl) {
            VStack(alignment: .leading, spacing: HermesSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                        Text("Knowledge Graph").font(.hermes.h3).foregroundColor(.hermes.text)
                        Text("Visualize conversation context relationships.").font(.hermes.caption).foregroundColor(.hermes.muted)
                    }
                    Spacer()
                    if isLoading { ProgressView().scaleEffect(0.7) }
                }
                if let err = errorText {
                    HStack(spacing: HermesSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hermes.warning)
                        Text(err).font(.hermes.caption).foregroundColor(.hermes.warning)
                    }.padding(HermesSpacing.md).background(Color.hermes.warning.opacity(0.1)).cornerRadius(HermesRadius.md)
                }

                // Stats
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: HermesSpacing.md) {
                    MiniStatCard(title: "Total Nodes", value: "\(stats?.totalNodes ?? 0)", icon: "circle.dotted", color: .indigo)
                    MiniStatCard(title: "Total Edges", value: "\(stats?.totalEdges ?? 0)", icon: "arrow.triangle.branch", color: .purple)
                    MiniStatCard(title: "Tokens Saved", value: fmt(stats?.totalTokensSaved), icon: "bolt.fill", color: .green)
                    MiniStatCard(title: "Avg Degree", value: stats?.avgDegree.map{String(format:"%.1f",$0)} ?? "--", icon: "network", color: .hermes.accent)
                    MiniStatCard(title: "Rooms", value: "\(stats?.roomsWithGraphs ?? 0)", icon: "square.stack.3d.up", color: .orange)
                    MiniStatCard(title: "Indexed", value: stats?.indexProgress.map{"\(Int($0))%"} ?? "--", icon: "chart.bar.fill", color: .blue)
                }

                // vis.js graph (identical to web dashboard)
                if let token = APIConfig.token {
                    WebKitGraphView(apiToken: token, apiBase: APIConfig.baseURL)
                        .frame(height: 420)
                        .background(Color.hermes.bg)
                        .cornerRadius(HermesRadius.md)
                        .overlay(RoundedRectangle(cornerRadius: HermesRadius.md).strokeBorder(Color.hermes.border, lineWidth: 1))
                }

                // Legend
                legendView
            }
        }
        .task { await load() }
    }

    private var legendView: some View {
        HStack(spacing: 0) {
            Text("Nodes:").font(.hermes.badge).foregroundColor(.hermes.muted)
            legendDot("#6366f1", "Topic"); legendDot("#22c55e", "Concept")
            legendDot("#f59e0b", "Person"); legendDot("#ef4444", "Action")
            legendDot("#8b5cf6", "Entity")
            Text("|").foregroundColor(.hermes.border).padding(.horizontal, 6).font(.hermes.badge)
            Text("Edges:").font(.hermes.badge).foregroundColor(.hermes.muted)
            Text("— Extracted").font(.hermes.badge).foregroundColor(.hermes.muted).padding(.leading, 4)
            Text("- - Inferred").font(.hermes.badge).foregroundColor(.hermes.muted).padding(.leading, 4)
            Spacer()
        }
    }

    private func legendDot(_ hex: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: hex)).frame(width: 8, height: 8)
            Text(label).font(.hermes.badge).foregroundColor(.hermes.muted)
        }.padding(.leading, 6)
    }

    private func fmt(_ v: Int?) -> String { guard let v else {return "--"}; return v>=1000 ? "\(v/1000)K":"\(v)" }

    private func load() async {
        isLoading=true; errorText=nil
        do {
            async let s=APIClient.shared.fetchGraphStats()
            async let r=APIClient.shared.fetchGraphRooms()
            stats=try await s; rooms=try await r
        } catch { errorText=error.localizedDescription }
        isLoading=false
    }
}

// MARK: - WebKit Graph View (vis.js — identical to web dashboard)
struct WebKitGraphView: View {
    let apiToken: String; let apiBase: String
    var body: some View {
        _WebKitGraph(apiToken: apiToken, apiBase: apiBase)
    }
}

#if os(macOS)
struct _WebKitGraph: NSViewRepresentable {
    let apiToken: String; let apiBase: String
    func makeCoordinator() -> Coordinator { Coordinator.shared }
    func makeNSView(context: Context) -> WKWebView { makeView() }
    func updateNSView(_ v: WKWebView, context: Context) {}
}
#else
struct _WebKitGraph: UIViewRepresentable {
    let apiToken: String; let apiBase: String
    func makeCoordinator() -> Coordinator { Coordinator.shared }
    func makeUIView(context: Context) -> WKWebView { makeView() }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
#endif

extension _WebKitGraph {
    func makeView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let v = WKWebView(frame: .zero, configuration: config)
        v.setValue(false, forKey: "drawsBackground")
        v.loadHTMLString(graphHTML(), baseURL: nil)
        return v
    }

    func graphHTML() -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
        <style>*{margin:0;padding:0}body{background:transparent;overflow:hidden}#graph{width:100%;height:100vh}
        select{position:absolute;top:8px;right:10px;z-index:10;background:#fff;border:1px solid #e5e7eb;border-radius:6px;padding:4px 8px;font:11px -apple-system,sans-serif;color:#374151;max-width:180px}
        @media(prefers-color-scheme:dark){select{background:#1c1c1e;border-color:#38383a;color:#e5e7eb}}
        </style></head><body>
        <select id="roomFilter" onchange="loadGraph()"><option value="">All Rooms</option></select>
        <div id="graph"></div>
        <script src="https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js"></script>
        <script>
        const TOKEN='\(apiToken)', BASE='\(apiBase)';
        let network=null;
        async function init(){
            try{
                const r=await fetch(BASE+'/dashboard/graph-rooms',{headers:{Accept:'application/json',Authorization:'Bearer '+TOKEN}});
                const rooms=await r.json();
                const sel=document.getElementById('roomFilter');
                (rooms.data||rooms).forEach(room=>{
                    const o=document.createElement('option');o.value=room.id;
                    o.text=room.title+' ('+(room.node_count||0)+')';sel.appendChild(o);
                });
                await loadGraph();
            }catch(e){console.error(e)}
        }
        async function loadGraph(){
            const sel=document.getElementById('roomFilter');
            const rid=sel.value;
            let url=BASE+'/dashboard/graph-data?limit=100';
            if(rid)url+='&room_id='+rid;
            try{
                const r=await fetch(url,{headers:{Accept:'application/json',Authorization:'Bearer '+TOKEN}});
                const d=await r.json();
                const data=d.data||d;
                if(!data.nodes||data.nodes.length===0){
                    document.getElementById('graph').innerHTML='';
                    return;
                }
                render(data);
            }catch(e){console.error(e)}
        }
        function render(data){
            const nodes=new vis.DataSet(data.nodes.map(n=>({
                id:n.id,label:n.label,value:n.value||1,group:n.group||'entity',
                title:n.title||'',color:{background:n.color||'#888',border:n.color||'#888',
                highlight:{background:n.color||'#888',border:'#fff'},
                hover:{background:n.color||'#888',border:'#fff'}},
                borderWidth:2,shape:'dot',
                scaling:{min:8,max:30,label:{enabled:true,min:10,max:16}},
                font:{color:window.matchMedia('(prefers-color-scheme:dark)').matches?'#e5e7eb':'#374151',size:12,face:'-apple-system,sans-serif',strokeWidth:4,strokeColor:window.matchMedia('(prefers-color-scheme:dark)').matches?'#141414':'#fff',vadjust:20},
                chosen:{node:function(v){v.shadowSize=0}}
            })));
            const edges=new vis.DataSet(data.edges.map(e=>({
                from:e.from,to:e.to,
                color:{color:e.dashes?'#a1a1aa':'#9ca3af',highlight:'#6366f1',hover:'#818cf8'},
                width:e.dashes?1.5:2,dashes:e.dashes?[6,4]:false,smooth:{enabled:true,type:'curvedCW',roundness:0.15},
                arrows:{to:{enabled:true,scaleFactor:0.5,type:'arrow'}}
            })));
            const options={
                physics:{enabled:true,barnesHut:{gravitationalConstant:-3000,centralGravity:0.2,springLength:160,springConstant:0.02,damping:0.15,avoidOverlap:0.4},stabilization:{enabled:true,iterations:100},minVelocity:0.75},
                interaction:{hover:true,tooltipDelay:100,zoomView:true,dragView:true,navigationButtons:false}
            };
            if(network){network.destroy()}
            network=new vis.Network(document.getElementById('graph'),{nodes,edges},options);
        }
        init();
        </script></body></html>
        """
    }
}

// MARK: - Coordinator (shared)
class Coordinator: NSObject, WKNavigationDelegate {
    static let shared = Coordinator()
    func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - Color Helper
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var n: UInt64 = 0; Scanner(string: s).scanHexInt64(&n)
        self.init(red: Double((n>>16)&0xFF)/255, green: Double((n>>8)&0xFF)/255, blue: Double(n&0xFF)/255)
    }
}
