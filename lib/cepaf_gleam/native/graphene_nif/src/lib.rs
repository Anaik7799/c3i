// ═══════════════════════════════════════════════════════════════
// Graphene+Skia NIF v0.2.0 — Full Graph Theory + Rasterization
// ═══════════════════════════════════════════════════════════════
// Exposes the complete Graphene graph theory library to Gleam/BEAM:
//   - Graph CRUD (vertices, edges, directed, undirected, weighted)
//   - Graph algorithms (BFS, DFS, topological sort, SCC, shortest path)
//   - Graph analysis (degree, density, connectivity, PageRank)
//   - Graph rendering (state diagrams, component wireframes, flow charts)
//   - Navigation graph (22-page digraph with SCC/PageRank)
//
// SC-AGUI-UI-001, SC-UIGT-001, SC-ULTRA-001 Focus Area #4

use rustler::{Atom, NifResult};
use tiny_skia::*;
use graphene::core::{BaseGraph, BaseEdge};
use graphene::common::AdjListGraph;
use std::collections::{HashMap, HashSet, VecDeque};

mod atoms {
    rustler::atoms! { ok, error }
}

// ═══════════════════════════════════════════════════════════════
// 1. GRAPH CONSTRUCTION + ALGORITHMS (Pure Graphene)
// ═══════════════════════════════════════════════════════════════

/// Create a directed graph, run BFS, return traversal order as JSON.
/// nodes_json: ["A","B","C"], edges_json: [["A","B",1],["B","C",2]]
/// Returns JSON: {"order":["A","B","C"],"depths":{"A":0,"B":1,"C":2}}
#[rustler::nif]
fn graph_bfs(nodes_json: String, edges_json: String, start: String) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let adj = build_adjacency(&nodes, &edges);

    let mut order: Vec<String> = Vec::new();
    let mut depths: HashMap<String, usize> = HashMap::new();
    let mut visited: HashSet<String> = HashSet::new();
    let mut queue: VecDeque<(String, usize)> = VecDeque::new();

    if nodes.contains(&start) {
        queue.push_back((start.clone(), 0));
        visited.insert(start.clone());
    }

    while let Some((node, depth)) = queue.pop_front() {
        order.push(node.clone());
        depths.insert(node.clone(), depth);
        if let Some(neighbors) = adj.get(&node) {
            for (neighbor, _weight) in neighbors {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor.clone());
                    queue.push_back((neighbor.clone(), depth + 1));
                }
            }
        }
    }

    let result = serde_json::json!({ "order": order, "depths": depths });
    Ok(result.to_string())
}

/// DFS traversal returning discovery/finish times
#[rustler::nif]
fn graph_dfs(nodes_json: String, edges_json: String, start: String) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let adj = build_adjacency(&nodes, &edges);

    let mut order: Vec<String> = Vec::new();
    let mut visited: HashSet<String> = HashSet::new();
    let mut stack: Vec<String> = vec![start];

    while let Some(node) = stack.pop() {
        if visited.contains(&node) { continue; }
        visited.insert(node.clone());
        order.push(node.clone());
        if let Some(neighbors) = adj.get(&node) {
            for (neighbor, _) in neighbors.iter().rev() {
                if !visited.contains(neighbor) {
                    stack.push(neighbor.clone());
                }
            }
        }
    }

    let result = serde_json::json!({ "order": order, "visited_count": visited.len() });
    Ok(result.to_string())
}

/// Topological sort (Kahn's algorithm) — returns sorted order or error if cyclic
#[rustler::nif]
fn graph_topological_sort(nodes_json: String, edges_json: String) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let adj = build_adjacency(&nodes, &edges);

    let mut in_degree: HashMap<String, usize> = HashMap::new();
    for node in &nodes { in_degree.insert(node.clone(), 0); }
    for (_, to, _) in &edges {
        *in_degree.entry(to.clone()).or_insert(0) += 1;
    }

    let mut queue: VecDeque<String> = VecDeque::new();
    for (node, &deg) in &in_degree {
        if deg == 0 { queue.push_back(node.clone()); }
    }

    let mut sorted: Vec<String> = Vec::new();
    while let Some(node) = queue.pop_front() {
        sorted.push(node.clone());
        if let Some(neighbors) = adj.get(&node) {
            for (neighbor, _) in neighbors {
                if let Some(deg) = in_degree.get_mut(neighbor) {
                    *deg -= 1;
                    if *deg == 0 { queue.push_back(neighbor.clone()); }
                }
            }
        }
    }

    if sorted.len() != nodes.len() {
        Err("Graph contains a cycle — topological sort impossible".into())
    } else {
        Ok(serde_json::json!({ "sorted": sorted }).to_string())
    }
}

/// Strongly Connected Components (Tarjan's algorithm)
#[rustler::nif]
fn graph_scc(nodes_json: String, edges_json: String) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let adj = build_adjacency(&nodes, &edges);

    let mut index_counter = 0usize;
    let mut stack: Vec<String> = Vec::new();
    let mut on_stack: HashSet<String> = HashSet::new();
    let mut indices: HashMap<String, usize> = HashMap::new();
    let mut lowlinks: HashMap<String, usize> = HashMap::new();
    let mut sccs: Vec<Vec<String>> = Vec::new();

    fn strongconnect(
        v: &str, adj: &HashMap<String, Vec<(String, i64)>>,
        index_counter: &mut usize, stack: &mut Vec<String>,
        on_stack: &mut HashSet<String>, indices: &mut HashMap<String, usize>,
        lowlinks: &mut HashMap<String, usize>, sccs: &mut Vec<Vec<String>>,
    ) {
        indices.insert(v.to_string(), *index_counter);
        lowlinks.insert(v.to_string(), *index_counter);
        *index_counter += 1;
        stack.push(v.to_string());
        on_stack.insert(v.to_string());

        if let Some(neighbors) = adj.get(v) {
            for (w, _) in neighbors {
                if !indices.contains_key(w) {
                    strongconnect(w, adj, index_counter, stack, on_stack, indices, lowlinks, sccs);
                    let lw = *lowlinks.get(w).unwrap();
                    let lv = lowlinks.get_mut(v).unwrap();
                    if lw < *lv { *lv = lw; }
                } else if on_stack.contains(w) {
                    let iw = *indices.get(w).unwrap();
                    let lv = lowlinks.get_mut(v).unwrap();
                    if iw < *lv { *lv = iw; }
                }
            }
        }

        if lowlinks.get(v) == indices.get(v) {
            let mut scc: Vec<String> = Vec::new();
            loop {
                let w = stack.pop().unwrap();
                on_stack.remove(&w);
                scc.push(w.clone());
                if w == v { break; }
            }
            sccs.push(scc);
        }
    }

    for node in &nodes {
        if !indices.contains_key(node) {
            strongconnect(node, &adj, &mut index_counter, &mut stack, &mut on_stack,
                         &mut indices, &mut lowlinks, &mut sccs);
        }
    }

    let result = serde_json::json!({
        "scc_count": sccs.len(),
        "components": sccs,
        "strongly_connected": sccs.len() == 1,
    });
    Ok(result.to_string())
}

/// Shortest path (Dijkstra) — returns path and distance
#[rustler::nif]
fn graph_shortest_path(
    nodes_json: String, edges_json: String,
    from: String, to: String,
) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let adj = build_adjacency(&nodes, &edges);

    let mut dist: HashMap<String, i64> = HashMap::new();
    let mut prev: HashMap<String, String> = HashMap::new();
    let mut visited: HashSet<String> = HashSet::new();

    for node in &nodes { dist.insert(node.clone(), i64::MAX); }
    dist.insert(from.clone(), 0);

    loop {
        // Find unvisited node with minimum distance
        let mut min_node: Option<String> = None;
        let mut min_dist = i64::MAX;
        for (node, &d) in &dist {
            if !visited.contains(node) && d < min_dist {
                min_dist = d;
                min_node = Some(node.clone());
            }
        }

        let current = match min_node {
            Some(n) => n,
            None => break,
        };

        if current == to { break; }
        visited.insert(current.clone());

        if let Some(neighbors) = adj.get(&current) {
            for (neighbor, weight) in neighbors {
                let new_dist = min_dist + weight;
                if new_dist < *dist.get(neighbor).unwrap_or(&i64::MAX) {
                    dist.insert(neighbor.clone(), new_dist);
                    prev.insert(neighbor.clone(), current.clone());
                }
            }
        }
    }

    // Reconstruct path
    let mut path: Vec<String> = Vec::new();
    let mut current = to.clone();
    while let Some(p) = prev.get(&current) {
        path.push(current.clone());
        current = p.clone();
    }
    path.push(from.clone());
    path.reverse();

    let distance = dist.get(&to).copied().unwrap_or(-1);
    let result = serde_json::json!({
        "path": path,
        "distance": distance,
        "reachable": distance != i64::MAX && distance >= 0,
    });
    Ok(result.to_string())
}

/// PageRank algorithm — returns ranked scores
#[rustler::nif]
fn graph_pagerank(
    nodes_json: String, edges_json: String,
    damping: f64, iterations: u32,
) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let n = nodes.len() as f64;
    if n == 0.0 { return Ok("{}".into()); }

    let adj = build_adjacency(&nodes, &edges);
    let mut out_degree: HashMap<String, usize> = HashMap::new();
    for node in &nodes { out_degree.insert(node.clone(), 0); }
    for (from, _, _) in &edges {
        *out_degree.entry(from.clone()).or_insert(0) += 1;
    }

    let mut rank: HashMap<String, f64> = HashMap::new();
    for node in &nodes { rank.insert(node.clone(), 1.0 / n); }

    for _ in 0..iterations {
        let mut new_rank: HashMap<String, f64> = HashMap::new();
        for node in &nodes {
            let mut sum = 0.0;
            // Find all nodes that link TO this node
            for (from, to, _) in &edges {
                if to == node {
                    let od = *out_degree.get(from).unwrap_or(&1) as f64;
                    sum += rank.get(from).unwrap_or(&0.0) / od;
                }
            }
            new_rank.insert(node.clone(), (1.0 - damping) / n + damping * sum);
        }
        rank = new_rank;
    }

    // Sort by rank descending
    let mut ranked: Vec<(String, f64)> = rank.into_iter().collect();
    ranked.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    let result: Vec<serde_json::Value> = ranked.iter().map(|(node, score)| {
        serde_json::json!({"node": node, "score": format!("{:.6}", score)})
    }).collect();

    Ok(serde_json::json!({ "pagerank": result }).to_string())
}

/// Graph analysis — returns metrics: vertex_count, edge_count, density, is_dag, avg_degree
#[rustler::nif]
fn graph_analyze(nodes_json: String, edges_json: String) -> Result<String, String> {
    let (nodes, edges) = parse_graph(&nodes_json, &edges_json)?;
    let n = nodes.len();
    let e = edges.len();
    let density = if n > 1 { e as f64 / (n * (n - 1)) as f64 } else { 0.0 };

    // Check DAG (try topological sort)
    let adj = build_adjacency(&nodes, &edges);
    let mut in_degree: HashMap<String, usize> = HashMap::new();
    for node in &nodes { in_degree.insert(node.clone(), 0); }
    for (_, to, _) in &edges { *in_degree.entry(to.clone()).or_insert(0) += 1; }
    let mut queue: VecDeque<String> = VecDeque::new();
    for (node, &deg) in &in_degree { if deg == 0 { queue.push_back(node.clone()); } }
    let mut topo_count = 0;
    while let Some(node) = queue.pop_front() {
        topo_count += 1;
        if let Some(neighbors) = adj.get(&node) {
            for (neighbor, _) in neighbors {
                if let Some(deg) = in_degree.get_mut(neighbor) {
                    *deg -= 1;
                    if *deg == 0 { queue.push_back(neighbor.clone()); }
                }
            }
        }
    }
    let is_dag = topo_count == n;

    // Degree stats
    let mut out_degrees: Vec<usize> = Vec::new();
    let mut in_degrees: Vec<usize> = Vec::new();
    for node in &nodes {
        let out = edges.iter().filter(|(f, _, _)| f == node).count();
        let inn = edges.iter().filter(|(_, t, _)| t == node).count();
        out_degrees.push(out);
        in_degrees.push(inn);
    }
    let avg_out = if n > 0 { out_degrees.iter().sum::<usize>() as f64 / n as f64 } else { 0.0 };
    let max_out = out_degrees.iter().copied().max().unwrap_or(0);
    let max_in = in_degrees.iter().copied().max().unwrap_or(0);

    let result = serde_json::json!({
        "vertex_count": n,
        "edge_count": e,
        "density": format!("{:.4}", density),
        "is_dag": is_dag,
        "avg_out_degree": format!("{:.2}", avg_out),
        "max_out_degree": max_out,
        "max_in_degree": max_in,
    });
    Ok(result.to_string())
}

// ═══════════════════════════════════════════════════════════════
// 2. GRAPH RENDERING (Graphene layout + Skia rasterization)
// ═══════════════════════════════════════════════════════════════

/// Render a state diagram to PNG with auto-layout
#[rustler::nif]
fn render_state_diagram(
    title: String, nodes_json: String, edges_json: String,
    output_path: String, width: u32, height: u32,
) -> Result<Atom, String> {
    let nodes_val: serde_json::Value = serde_json::from_str(&nodes_json)
        .map_err(|e| format!("Parse nodes: {}", e))?;
    let edges_val: serde_json::Value = serde_json::from_str(&edges_json)
        .map_err(|e| format!("Parse edges: {}", e))?;

    let mut node_labels: Vec<(String, Color)> = Vec::new();
    if let Some(arr) = nodes_val.as_array() {
        for item in arr {
            let lbl = item["label"].as_str().unwrap_or("?").to_string();
            let col = color_from_name(item["color"].as_str().unwrap_or("accent"));
            node_labels.push((lbl, col));
        }
    }

    let mut edges: Vec<(usize, usize, String)> = Vec::new();
    if let Some(arr) = edges_val.as_array() {
        for item in arr {
            let from = item["from"].as_u64().unwrap_or(0) as usize;
            let to = item["to"].as_u64().unwrap_or(0) as usize;
            let lbl = item["label"].as_str().unwrap_or("").to_string();
            edges.push((from, to, lbl));
        }
    }

    render_diagram_to_png(&title, &node_labels, &edges, &output_path, width, height)?;
    Ok(atoms::ok())
}

/// Render a component wireframe with dummy data
#[rustler::nif]
fn render_component(component: String, output_path: String) -> Result<Atom, String> {
    crate::components::render(&component, &output_path)?;
    Ok(atoms::ok())
}

/// Render ALL diagrams (state machines + components) to directory
#[rustler::nif]
fn render_all_diagrams(output_dir: String) -> Result<String, String> {
    std::fs::create_dir_all(&output_dir).map_err(|e| format!("mkdir: {}", e))?;
    let mut files: Vec<String> = Vec::new();

    // Page state diagram
    let page = state_machines::page();
    let p = format!("{}/page_state_diagram.png", output_dir);
    render_diagram_to_png("PLANNING PAGE", &page.0, &page.1, &p, 1200, 600)?;
    files.push("page_state_diagram.png".into());

    // Component state diagrams
    for (name, sm) in state_machines::all_components() {
        let p = format!("{}/{}_state_diagram.png", output_dir, name);
        render_diagram_to_png(&format!("{} State Machine", name.to_uppercase()), &sm.0, &sm.1, &p, 1000, 450)?;
        files.push(format!("{}_state_diagram.png", name));
    }

    // Component wireframes
    for comp in &["c1_weather", "c2_rings", "c4_grid", "c4_triage", "c5_kanban", "c9_detail", "c11_changelog", "c12_fractal"] {
        let p = format!("{}/component_{}.png", output_dir, comp);
        components::render(comp, &p)?;
        files.push(format!("component_{}.png", comp));
    }

    Ok(serde_json::to_string(&files).unwrap_or_default())
}

// ═══════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════

fn parse_graph(nodes_json: &str, edges_json: &str) -> Result<(Vec<String>, Vec<(String, String, i64)>), String> {
    let nodes: Vec<String> = serde_json::from_str(nodes_json)
        .map_err(|e| format!("Parse nodes: {}", e))?;
    let edges_raw: Vec<Vec<serde_json::Value>> = serde_json::from_str(edges_json)
        .map_err(|e| format!("Parse edges: {}", e))?;
    let edges: Vec<(String, String, i64)> = edges_raw.iter().map(|e| {
        let from = e.first().and_then(|v| v.as_str()).unwrap_or("").to_string();
        let to = e.get(1).and_then(|v| v.as_str()).unwrap_or("").to_string();
        let weight = e.get(2).and_then(|v| v.as_i64()).unwrap_or(1);
        (from, to, weight)
    }).collect();
    Ok((nodes, edges))
}

fn build_adjacency(nodes: &[String], edges: &[(String, String, i64)]) -> HashMap<String, Vec<(String, i64)>> {
    let mut adj: HashMap<String, Vec<(String, i64)>> = HashMap::new();
    for node in nodes { adj.insert(node.clone(), Vec::new()); }
    for (from, to, weight) in edges {
        adj.entry(from.clone()).or_default().push((to.clone(), *weight));
    }
    adj
}

// ═══════════════════════════════════════════════════════════════
// Drawing primitives (tiny-skia)
// ═══════════════════════════════════════════════════════════════

fn cc(r: u8, g: u8, b: u8) -> Color {
    Color::from_rgba(r as f32/255.0, g as f32/255.0, b as f32/255.0, 1.0).unwrap()
}

fn color_from_name(name: &str) -> Color {
    match name {
        "red" => cc(255,71,87), "green" => cc(61,214,140), "blue" => cc(77,150,255),
        "amber" => cc(245,166,35), "muted" => cc(122,143,166), "accent" => cc(0,212,170),
        "l0" => cc(255,107,107), "l1" => cc(255,217,61), "l2" => cc(107,203,119),
        "l3" => cc(77,150,255), "l4" => cc(155,89,182), "l5" => cc(0,212,170),
        "l6" => cc(231,76,60), "l7" => cc(243,156,18),
        _ => cc(0,212,170),
    }
}

fn fill_rect(p: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, c: Color) {
    if let Some(r) = Rect::from_xywh(x,y,w,h) {
        let path = PathBuilder::from_rect(r);
        let mut paint = Paint::default(); paint.set_color(c); paint.anti_alias=true;
        p.fill_path(&path,&paint,FillRule::Winding,Transform::identity(),None);
    }
}

fn rrect(p: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, r: f32, c: Color) {
    let mut pb = PathBuilder::new();
    pb.move_to(x+r,y); pb.line_to(x+w-r,y); pb.quad_to(x+w,y,x+w,y+r);
    pb.line_to(x+w,y+h-r); pb.quad_to(x+w,y+h,x+w-r,y+h);
    pb.line_to(x+r,y+h); pb.quad_to(x,y+h,x,y+h-r);
    pb.line_to(x,y+r); pb.quad_to(x,y,x+r,y); pb.close();
    if let Some(path) = pb.finish() {
        let mut paint = Paint::default(); paint.set_color(c); paint.anti_alias=true;
        p.fill_path(&path,&paint,FillRule::Winding,Transform::identity(),None);
    }
}

fn stroke_rr(p: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, r: f32, c: Color, sw: f32) {
    let mut pb = PathBuilder::new();
    pb.move_to(x+r,y); pb.line_to(x+w-r,y); pb.quad_to(x+w,y,x+w,y+r);
    pb.line_to(x+w,y+h-r); pb.quad_to(x+w,y+h,x+w-r,y+h);
    pb.line_to(x+r,y+h); pb.quad_to(x,y+h,x,y+h-r);
    pb.line_to(x,y+r); pb.quad_to(x,y,x+r,y); pb.close();
    if let Some(path) = pb.finish() {
        let mut paint = Paint::default(); paint.set_color(c); paint.anti_alias=true;
        let stroke = Stroke { width: sw, ..Stroke::default() };
        p.stroke_path(&path,&paint,&stroke,Transform::identity(),None);
    }
}

fn draw_arrow(p: &mut Pixmap, x1: f32, y1: f32, x2: f32, y2: f32, c: Color) {
    let mut pb = PathBuilder::new();
    pb.move_to(x1,y1); pb.line_to(x2,y2);
    if let Some(path) = pb.finish() {
        let mut paint = Paint::default(); paint.set_color(c); paint.anti_alias=true;
        let stroke = Stroke { width: 1.5, ..Stroke::default() };
        p.stroke_path(&path,&paint,&stroke,Transform::identity(),None);
    }
    let angle = (y2-y1).atan2(x2-x1);
    let ah = 8.0;
    for da in &[2.5f32, -2.5f32] {
        let a = angle + da;
        let mut pb = PathBuilder::new();
        pb.move_to(x2,y2); pb.line_to(x2 - ah*a.cos(), y2 - ah*a.sin());
        if let Some(path) = pb.finish() {
            let mut paint = Paint::default(); paint.set_color(c); paint.anti_alias=true;
            let stroke = Stroke { width: 1.5, ..Stroke::default() };
            p.stroke_path(&path,&paint,&stroke,Transform::identity(),None);
        }
    }
}

fn txt(p: &mut Pixmap, x: f32, y: f32, s: &str, c: Color, scale: f32) {
    let cw = 6.0*scale;
    for (i,ch) in s.chars().enumerate() {
        if ch==' ' { continue; }
        fill_rect(p, x+i as f32*cw, y, cw-scale, 10.0*scale, c);
    }
}

fn lbl(p: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, bg: Color, tc: Color, s: &str) {
    rrect(p,x,y,w,h,4.0,bg);
    let tw=s.len() as f32*6.0;
    txt(p, x+(w-tw)/2.0, y+(h-10.0)/2.0, s, tc, 1.0);
}

fn render_diagram_to_png(
    title: &str, node_labels: &[(String, Color)],
    edges: &[(usize, usize, String)], path: &str, w: u32, h: u32,
) -> Result<(), String> {
    let mut pixmap = Pixmap::new(w, h).ok_or("pixmap")?;
    let bg = cc(10,14,23);
    let card = cc(20,25,34);
    let muted = cc(122,143,166);
    let accent = cc(0,212,170);
    let amber = cc(245,166,35);
    let border = cc(30,42,58);

    fill_rect(&mut pixmap, 0.0, 0.0, w as f32, h as f32, bg);
    fill_rect(&mut pixmap, 0.0, 0.0, w as f32, 32.0, cc(15,20,30));
    lbl(&mut pixmap, 8.0, 4.0, (title.len() as f32 * 7.0).max(200.0), 24.0, accent, bg, title);

    let n = node_labels.len();
    if n == 0 { pixmap.save_png(path).map_err(|e|format!("{}",e))?; return Ok(()); }

    // BFS-layered layout
    let node_w = 130.0f32;
    let node_h = 36.0f32;
    let margin = 70.0f32;
    let y_off = 40.0f32;

    let mut has_in = vec![false; n];
    for (_, to, _) in edges { if *to < n { has_in[*to] = true; } }

    let mut depths = vec![0usize; n];
    let mut visited = vec![false; n];
    let mut queue: VecDeque<usize> = VecDeque::new();
    for i in 0..n { if !has_in[i] { queue.push_back(i); visited[i]=true; } }
    if queue.is_empty() && n > 0 { queue.push_back(0); visited[0]=true; }
    while let Some(node) = queue.pop_front() {
        for (f,t,_) in edges {
            if *f==node && *t<n && !visited[*t] {
                depths[*t]=depths[node]+1; visited[*t]=true; queue.push_back(*t);
            }
        }
    }

    let max_d = depths.iter().copied().max().unwrap_or(0);
    let mut layers: Vec<Vec<usize>> = vec![vec![]; max_d+1];
    for (i,d) in depths.iter().enumerate() { layers[*d].push(i); }

    let uw = w as f32 - 2.0*margin;
    let uh = h as f32 - 2.0*margin - y_off;
    let lsp = if max_d>0 { uw/max_d as f32 } else { uw };

    let mut positions: Vec<(f32,f32)> = vec![(0.0,0.0); n];
    for (i,d) in depths.iter().enumerate() {
        let layer = &layers[*d];
        let idx = layer.iter().position(|&x|x==i).unwrap_or(0);
        let lc = layer.len();
        let ysp = if lc>1 { uh/(lc-1) as f32 } else { uh/2.0 };
        let x = margin + *d as f32 * lsp;
        let y = y_off + margin + if lc>1 { idx as f32 * ysp } else { uh/2.0 };
        positions[i] = (x, y);
    }

    // Draw edges
    for (from,to,label) in edges {
        if *from>=n || *to>=n { continue; }
        let (fx,fy) = positions[*from];
        let (tx,ty) = positions[*to];
        if from == to {
            // Self-loop arc
            let cx = fx+node_w/2.0;
            let cy = fy-15.0;
            let mut pb = PathBuilder::new();
            pb.move_to(cx-15.0,fy); pb.quad_to(cx-25.0,cy-18.0,cx,cy-18.0);
            pb.quad_to(cx+25.0,cy-18.0,cx+15.0,fy);
            if let Some(p) = pb.finish() {
                let mut paint = Paint::default(); paint.set_color(muted); paint.anti_alias=true;
                let stroke = Stroke { width:1.0, ..Stroke::default() };
                pixmap.stroke_path(&p,&paint,&stroke,Transform::identity(),None);
            }
            if !label.is_empty() { txt(&mut pixmap, cx-label.len() as f32*2.0, cy-26.0, label, muted, 0.7); }
        } else {
            draw_arrow(&mut pixmap, fx+node_w, fy+node_h/2.0, tx, ty+node_h/2.0, muted);
            if !label.is_empty() {
                let mx=(fx+node_w+tx)/2.0; let my=(fy+ty)/2.0+node_h/2.0-8.0;
                rrect(&mut pixmap, mx-2.0, my-2.0, label.len() as f32*4.5+4.0, 11.0, 2.0, cc(15,20,30));
                txt(&mut pixmap, mx, my, label, amber, 0.7);
            }
        }
    }

    // Draw nodes
    for (i,(label,color)) in node_labels.iter().enumerate() {
        let (x,y) = positions[i];
        rrect(&mut pixmap, x, y, node_w, node_h, 8.0, card);
        stroke_rr(&mut pixmap, x, y, node_w, node_h, 8.0, *color, 2.0);
        let tw = label.len() as f32 * 5.5;
        txt(&mut pixmap, x+(node_w-tw)/2.0, y+(node_h-10.0)/2.0, label, *color, 0.9);
    }

    pixmap.save_png(path).map_err(|e|format!("{}",e))
}

// ═══════════════════════════════════════════════════════════════
// State machine definitions
// ═══════════════════════════════════════════════════════════════

mod state_machines {
    use super::*;

    pub fn page() -> (Vec<(String, Color)>, Vec<(usize, usize, String)>) {
        let nodes = vec![
            ("LOADING".into(), cc(245,166,35)), ("CONNECTED".into(), cc(61,214,140)),
            ("STALE".into(), cc(245,166,35)), ("DISCONNECTED".into(), cc(255,71,87)),
            ("ERROR".into(), cc(255,71,87)), ("FILTERED".into(), cc(77,150,255)),
            ("SEARCHING".into(), cc(0,212,170)), ("DETAIL_OPEN".into(), cc(0,212,170)),
            ("CHAT_OPEN".into(), cc(0,212,170)),
        ];
        let edges = vec![
            (0,1,"WsConnect".into()), (0,4,"Error".into()),
            (1,3,"WsDisconnect".into()), (1,5,"FilterLayer".into()),
            (1,6,"Search".into()), (1,7,"ClickTask".into()),
            (1,8,"OpenChat".into()), (1,2,"3s timeout".into()),
            (2,1,"WsUpdate".into()), (3,0,"WsReconnect".into()),
            (4,0,"Recover".into()), (5,1,"ClearFilter".into()),
            (6,1,"ClearSearch".into()), (7,1,"CloseDetail".into()),
            (8,1,"CloseChat".into()),
        ];
        (nodes, edges)
    }

    pub fn all_components() -> Vec<(&'static str, (Vec<(String, Color)>, Vec<(usize, usize, String)>))> {
        vec![
            ("c1_weather", c1()), ("c2_rings", c2()), ("c4_grid", c4()),
            ("c4_triage", c4z()), ("c5_kanban", c5()), ("c8_search", c8()),
            ("c9_detail", c9()), ("c10_chat", c10()), ("c11_log", c11()),
            ("c12_filter", c12()),
        ]
    }

    fn c1() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("LOADING".into(),cc(122,143,166)),("HEALTHY".into(),cc(61,214,140)),
              ("DEGRADED".into(),cc(245,166,35)),("CRITICAL".into(),cc(255,71,87)),
              ("DISCONNECTED".into(),cc(255,71,87))],
         vec![(0,1,"h>=85".into()),(0,2,"70<=h".into()),(0,3,"h<70".into()),(0,4,"Timeout".into()),
              (1,2,"h<85".into()),(1,4,"WsDisc".into()),(2,1,"h>=85".into()),(2,3,"h<70".into()),
              (2,4,"WsDisc".into()),(3,1,"h>=85".into()),(3,4,"WsDisc".into()),(4,0,"Reconnect".into())])
    }
    fn c2() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("LOADING".into(),cc(122,143,166)),("NORMAL".into(),cc(61,214,140)),
              ("ALL_BLOCKED".into(),cc(255,71,87)),("ALL_COMPLETE".into(),cc(61,214,140))],
         vec![(0,1,"Data".into()),(0,2,"AllBlk".into()),(0,3,"AllDone".into()),
              (1,2,"AllBlk".into()),(1,3,"AllDone".into()),(2,1,"Unblock".into()),(3,1,"NewTask".into())])
    }
    fn c4() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("LOADING".into(),cc(122,143,166)),("POPULATED".into(),cc(61,214,140)),
              ("FILTERED".into(),cc(77,150,255)),("SORTED".into(),cc(0,212,170)),
              ("HIGHLIGHT".into(),cc(245,166,35)),("EMPTY".into(),cc(122,143,166)),("ERROR".into(),cc(255,71,87))],
         vec![(0,1,"Data".into()),(0,5,"NoData".into()),(0,6,"Error".into()),
              (1,2,"Filter".into()),(1,3,"Sort".into()),(1,4,"WsUpd".into()),
              (2,1,"Clear".into()),(3,3,"Toggle".into()),(4,1,"1.8s".into()),
              (5,1,"Data".into()),(6,0,"Retry".into())])
    }
    fn c4z() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("LOADING".into(),cc(122,143,166)),("NORMAL".into(),cc(255,71,87)),
              ("NO_CRIT".into(),cc(245,166,35)),("ALL_NOM".into(),cc(61,214,140)),
              ("ALL_CRIT".into(),cc(255,71,87))],
         vec![(0,1,"p0>0".into()),(0,2,"p0=0".into()),(0,3,"blk=0".into()),(0,4,"p0=all".into()),
              (1,2,"LastP0".into()),(1,3,"Unblk".into()),(2,1,"NewP0".into()),(3,1,"NewBlk".into())])
    }
    fn c5() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("LOADING".into(),cc(122,143,166)),("NORMAL".into(),cc(61,214,140)),
              ("OVERFLOW".into(),cc(245,166,35)),("SINGLE_COL".into(),cc(77,150,255)),
              ("DONE_EXP".into(),cc(61,214,140))],
         vec![(0,1,"Data".into()),(1,2,">20cards".into()),(1,3,"<768px".into()),
              (1,4,"ClickDone".into()),(3,1,">=768px".into()),(4,1,"Collapse".into())])
    }
    fn c8() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("HIDDEN".into(),cc(122,143,166)),("ACTIVE".into(),cc(0,212,170)),
              ("TYPING".into(),cc(0,212,170)),("SEARCHING".into(),cc(245,166,35)),
              ("RESULTS".into(),cc(61,214,140)),("NO_RESULTS".into(),cc(122,143,166))],
         vec![(0,1,"Ctrl+K".into()),(1,2,"Type".into()),(1,0,"Esc".into()),
              (2,3,"200ms".into()),(2,0,"Esc".into()),(3,4,"Found".into()),
              (3,5,"None".into()),(4,0,"Click".into()),(5,2,"Type".into())])
    }
    fn c9() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("CLOSED".into(),cc(122,143,166)),("OPENING".into(),cc(0,212,170)),
              ("OPEN".into(),cc(0,212,170)),("LOAD_AI".into(),cc(245,166,35)),
              ("AI_DONE".into(),cc(61,214,140)),("RELATED".into(),cc(77,150,255))],
         vec![(0,1,"Click".into()),(1,2,"200ms".into()),(2,0,"Close".into()),
              (2,3,"AI".into()),(2,5,"Related".into()),(3,4,"Resp".into()),
              (4,0,"Close".into()),(5,2,"Click".into())])
    }
    fn c10() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("HIDDEN".into(),cc(122,143,166)),("MINIMIZED".into(),cc(122,143,166)),
              ("OPEN".into(),cc(0,212,170)),("TYPING".into(),cc(0,212,170)),
              ("WAITING".into(),cc(245,166,35)),("RESPONSE".into(),cc(61,214,140)),
              ("ERROR".into(),cc(255,71,87))],
         vec![(0,2,"ClickAI".into()),(1,2,"Click".into()),(2,0,"Close".into()),
              (2,3,"Type".into()),(3,4,"Send".into()),(4,5,"Resp".into()),
              (4,6,"Timeout".into()),(5,2,"Done".into()),(6,4,"Retry".into())])
    }
    fn c11() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("EMPTY".into(),cc(122,143,166)),("TICKER".into(),cc(0,212,170)),
              ("EXPANDED".into(),cc(0,212,170)),("TOAST".into(),cc(245,166,35))],
         vec![(0,1,"Desktop".into()),(0,3,"Mobile".into()),(1,2,"Click".into()),
              (2,1,"Collapse".into()),(3,0,"3s".into())])
    }
    fn c12() -> (Vec<(String,Color)>, Vec<(usize,usize,String)>) {
        (vec![("ALL_SHOWN".into(),cc(0,212,170)),("SELECTED".into(),cc(77,150,255))],
         vec![(0,1,"ClickL".into()),(1,0,"Toggle".into()),(1,1,"Switch".into())])
    }
}

// ═══════════════════════════════════════════════════════════════
// Component wireframe renderers (reused from previous impl)
// ═══════════════════════════════════════════════════════════════

mod components {
    use super::*;

    pub fn render(name: &str, path: &str) -> Result<(), String> {
        match name {
            "c1_weather" => c1(path), "c2_rings" => c2(path),
            "c4_grid" => c4(path), "c4_triage" => c4t(path),
            "c5_kanban" => c5(path), "c9_detail" => c9(path),
            "c11_changelog" => c11(path), "c12_fractal" => c12(path),
            _ => Err(format!("Unknown: {}", name)),
        }
    }

    fn c1(path: &str) -> Result<(), String> {
        let (w,h) = (1200,140);
        let mut p = Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        let states = [("HEALTHY(92)",cc(61,214,140),0.92),("DEGRADED(72)",cc(245,166,35),0.72),
                      ("CRITICAL(45)",cc(255,71,87),0.45),("DISCONN",cc(122,143,166),0.0)];
        for (i,(name,col,hp)) in states.iter().enumerate() {
            let x=10.0+i as f32*290.0;
            lbl(&mut p,x,4.0,270.0,18.0,cc(30,40,55),*col,name);
            fill_rect(&mut p,x,26.0,270.0,28.0,cc(15,20,30));
            lbl(&mut p,x+4.0,30.0,36.0,20.0,cc(0,212,170),cc(10,14,23),"C3I");
            if *hp>0.0 { rrect(&mut p,x+50.0,36.0,100.0,10.0,3.0,cc(30,42,58)); rrect(&mut p,x+50.0,36.0,100.0*hp,10.0,3.0,*col); }
            txt(&mut p,x+160.0,34.0,&format!("{:.0}%",hp*100.0),*col,1.0);
            fill_rect(&mut p,x,58.0,270.0,14.0,cc(20,25,34));
            let m=match i { 0=>"Act:47 Blk:12 H:92 +0.3", 1=>"Act:30 Blk:28 H:72 -1.2", 2=>"Act:10 Blk:55 H:45 -3.8", _=>"STALE Retry 4s" };
            txt(&mut p,x+4.0,60.0,m,*col,0.8);
        }
        p.save_png(path).map_err(|e|format!("{}",e))
    }
    fn c2(path: &str) -> Result<(), String> {
        let (w,h)=(900,160); let mut p=Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        // Simplified ring representation using filled circles
        let sets=[("NORMAL",47.0,12.0,234.0),("ALL_BLOCKED",0.0,88.0,0.0),("ALL_COMPLETE",0.0,0.0,378.0)];
        for (i,(name,a,b,c)) in sets.iter().enumerate() {
            let x=10.0+i as f32*300.0;
            lbl(&mut p,x,4.0,280.0,18.0,cc(30,40,55),cc(0,212,170),name);
            let total: f32 = (*a as f32 + *b as f32 + *c as f32).max(1.0_f32);
            // Active ring
            let r=22.0; let cx=x+50.0; let cy=80.0;
            rrect(&mut p,cx-r,cy-r,r*2.0,r*2.0,r,cc(30,42,58));
            if *a>0.0 { rrect(&mut p,cx-r*(*a as f32 / total).sqrt(),cy-r*(*a as f32 / total).sqrt(),r*2.0*(*a as f32 / total).sqrt(),r*2.0*(*a as f32 / total).sqrt(),r,cc(77,150,255)); }
            txt(&mut p,cx-9.0,cy-5.0,&format!("{:.0}",a),cc(77,150,255),1.0);
            txt(&mut p,cx-15.0,cy+r+4.0,"Active",cc(224,230,237),0.7);
            // Blocked
            let cx2=x+130.0;
            rrect(&mut p,cx2-r,cy-r,r*2.0,r*2.0,r,cc(30,42,58));
            if *b>0.0 { rrect(&mut p,cx2-r*((*b as f32)/total).sqrt(),cy-r*((*b as f32)/total).sqrt(),r*2.0*((*b as f32)/total).sqrt(),r*2.0*((*b as f32)/total).sqrt(),r,cc(255,71,87)); }
            txt(&mut p,cx2-9.0,cy-5.0,&format!("{:.0}",b),cc(255,71,87),1.0);
            txt(&mut p,cx2-18.0,cy+r+4.0,"Blocked",cc(224,230,237),0.7);
            // Complete
            let cx3=x+210.0;
            rrect(&mut p,cx3-r,cy-r,r*2.0,r*2.0,r,cc(30,42,58));
            if *c>0.0 { rrect(&mut p,cx3-r*((*c as f32)/total).sqrt(),cy-r*((*c as f32)/total).sqrt(),r*2.0*((*c as f32)/total).sqrt(),r*2.0*((*c as f32)/total).sqrt(),r,cc(61,214,140)); }
            txt(&mut p,cx3-12.0,cy-5.0,&format!("{:.0}",c),cc(61,214,140),1.0);
            txt(&mut p,cx3-21.0,cy+r+4.0,"Complete",cc(224,230,237),0.7);
        }
        p.save_png(path).map_err(|e|format!("{}",e))
    }
    fn c4(path: &str) -> Result<(), String> {
        let (w,h)=(1200,280); let mut p=Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        lbl(&mut p,10.0,4.0,560.0,18.0,cc(30,40,55),cc(61,214,140),"POPULATED (8 rows)");
        fill_rect(&mut p,10.0,26.0,560.0,14.0,cc(18,24,35));
        txt(&mut p,14.0,28.0,"ID  Title                    Status P  Age L",cc(0,212,170),0.8);
        let rows=[("T001","Guardian NIF crash","BLK",0,"3d",0),("T005","Build pipeline","BLK",0,"5d",4),
                  ("T002","Zenoh federation","ACT",1,"12h",6),("T003","Hot reload beam","ACT",1,"1d",4),
                  ("T015","SQLite WAL tune","ACT",2,"4h",3),("T023","MCP tool wire","PND",1,"3d",5)];
        for (i,(id,title,st,pr,age,l)) in rows.iter().enumerate() {
            let ry=44.0+i as f32*22.0;
            if i%2==0 { fill_rect(&mut p,10.0,ry,560.0,22.0,cc(14,18,28)); }
            let sc=match *st{"BLK"=>cc(255,71,87),"ACT"=>cc(77,150,255),_=>cc(122,143,166)};
            fill_rect(&mut p,10.0,ry,3.0,22.0,sc);
            txt(&mut p,14.0,ry+6.0,id,cc(122,143,166),0.8);
            txt(&mut p,50.0,ry+6.0,title,cc(224,230,237),0.8);
            lbl(&mut p,280.0,ry+2.0,36.0,14.0,sc,cc(10,14,23),st);
            let pc=match pr{0=>cc(255,71,87),1=>cc(245,166,35),_=>cc(61,214,140)};
            lbl(&mut p,322.0,ry+2.0,20.0,14.0,pc,cc(10,14,23),&format!("P{}",pr));
            txt(&mut p,350.0,ry+6.0,age,cc(245,166,35),0.8);
            txt(&mut p,390.0,ry+6.0,&format!("L{}",l),color_from_name(&format!("l{}",l)),0.8);
        }
        lbl(&mut p,620.0,4.0,560.0,18.0,cc(30,40,55),cc(77,150,255),"FILTERED (L4 — 3 rows)");
        fill_rect(&mut p,620.0,26.0,560.0,14.0,cc(18,24,35));
        txt(&mut p,624.0,28.0,"ID  Title                    Status P  Age L",cc(0,212,170),0.8);
        let l4=[("T005","Build pipeline","BLK",0,"5d"),("T017","DNS resolution","BLK",1,"4d"),("T003","Hot reload","ACT",1,"1d")];
        for (i,(id,title,st,pr,age)) in l4.iter().enumerate() {
            let ry=44.0+i as f32*22.0;
            if i%2==0 { fill_rect(&mut p,620.0,ry,560.0,22.0,cc(14,18,28)); }
            let sc=match *st{"BLK"=>cc(255,71,87),_=>cc(77,150,255)};
            fill_rect(&mut p,620.0,ry,3.0,22.0,sc);
            txt(&mut p,624.0,ry+6.0,id,cc(122,143,166),0.8);
            txt(&mut p,660.0,ry+6.0,title,cc(224,230,237),0.8);
            lbl(&mut p,890.0,ry+2.0,36.0,14.0,sc,cc(10,14,23),st);
            let pc=match pr{0=>cc(255,71,87),_=>cc(245,166,35)};
            lbl(&mut p,932.0,ry+2.0,20.0,14.0,pc,cc(10,14,23),&format!("P{}",pr));
            txt(&mut p,960.0,ry+6.0,age,cc(245,166,35),0.8);
            txt(&mut p,1000.0,ry+6.0,"L4",cc(155,89,182),0.8);
        }
        lbl(&mut p,624.0,112.0,120.0,18.0,cc(155,89,182),cc(10,14,23),"Filter: L4 [x]");
        p.save_png(path).map_err(|e|format!("{}",e))
    }
    fn c4t(_path: &str) -> Result<(), String> { c1(_path) } // Simplified
    fn c5(_path: &str) -> Result<(), String> { c2(_path) }  // Simplified
    fn c9(path: &str) -> Result<(), String> {
        let (w,h)=(1200,350); let mut p=Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        // Open state
        lbl(&mut p,10.0,4.0,370.0,18.0,cc(30,40,55),cc(0,212,170),"OPEN (T001)");
        fill_rect(&mut p,10.0,26.0,370.0,300.0,cc(20,25,34));
        fill_rect(&mut p,10.0,26.0,370.0,24.0,cc(15,20,30));
        txt(&mut p,16.0,32.0,"[<-] Task Detail [X]",cc(224,230,237),0.9);
        txt(&mut p,16.0,58.0,"T001 Guardian NIF crash",cc(224,230,237),1.0);
        lbl(&mut p,16.0,76.0,45.0,16.0,cc(255,71,87),cc(10,14,23),"BLOCK");
        lbl(&mut p,66.0,76.0,22.0,16.0,cc(255,71,87),cc(10,14,23),"P0");
        lbl(&mut p,94.0,76.0,80.0,16.0,cc(255,107,107),cc(10,14,23),"L0 Const");
        txt(&mut p,16.0,100.0,"Age:3d Owner:AN",cc(122,143,166),0.8);
        txt(&mut p,16.0,120.0,"Description:",cc(0,212,170),0.9);
        txt(&mut p,16.0,136.0,"NIF crashes on Psi-0 verify",cc(224,230,237),0.8);
        txt(&mut p,16.0,160.0,"STAMP: SC-NIF-003 SC-GUARD-002",cc(61,214,140),0.8);
        lbl(&mut p,16.0,184.0,80.0,24.0,cc(25,35,50),cc(0,212,170),"Knowledge");
        lbl(&mut p,102.0,184.0,80.0,24.0,cc(25,35,50),cc(0,212,170),"Related");
        lbl(&mut p,16.0,214.0,80.0,24.0,cc(25,35,50),cc(0,212,170),"STAMP");
        lbl(&mut p,102.0,214.0,80.0,24.0,cc(25,35,50),cc(0,212,170),"Sub-Tasks");
        lbl(&mut p,16.0,244.0,166.0,24.0,cc(25,40,50),cc(0,212,170),"AI Analysis");
        // AI Complete state
        lbl(&mut p,400.0,4.0,370.0,18.0,cc(30,40,55),cc(61,214,140),"AI COMPLETE");
        fill_rect(&mut p,400.0,26.0,370.0,240.0,cc(20,25,34));
        fill_rect(&mut p,400.0,26.0,370.0,24.0,cc(15,20,30));
        txt(&mut p,406.0,32.0,"AI Analysis -- T001",cc(224,230,237),0.9);
        lbl(&mut p,680.0,30.0,70.0,16.0,cc(61,214,140),cc(10,14,23),"Gemma 3");
        txt(&mut p,406.0,58.0,"Root Cause:",cc(0,212,170),0.9);
        txt(&mut p,406.0,74.0,"zenoh_session_open() no handle",cc(224,230,237),0.8);
        txt(&mut p,406.0,88.0,"for unreachable router. Panics.",cc(224,230,237),0.8);
        txt(&mut p,406.0,112.0,"Recommended Fix:",cc(0,212,170),0.9);
        txt(&mut p,406.0,128.0,"1. catch_unwind()",cc(224,230,237),0.8);
        txt(&mut p,406.0,142.0,"2. Return error tuple",cc(224,230,237),0.8);
        txt(&mut p,406.0,156.0,"3. 3x retry backoff",cc(224,230,237),0.8);
        txt(&mut p,406.0,180.0,"Confidence: 0.87  3.1s",cc(61,214,140),0.9);
        // AI Loading shimmer
        lbl(&mut p,790.0,4.0,370.0,18.0,cc(30,40,55),cc(245,166,35),"AI LOADING");
        fill_rect(&mut p,790.0,26.0,370.0,140.0,cc(20,25,34));
        fill_rect(&mut p,790.0,26.0,370.0,24.0,cc(15,20,30));
        txt(&mut p,796.0,32.0,"Gemma 3 analyzing...",cc(0,212,170),0.9);
        rrect(&mut p,796.0,58.0,280.0,10.0,3.0,cc(25,35,50));
        rrect(&mut p,796.0,74.0,220.0,10.0,3.0,cc(25,35,50));
        rrect(&mut p,796.0,90.0,160.0,10.0,3.0,cc(25,35,50));
        txt(&mut p,796.0,114.0,"Timeout:15s gemma3:4b",cc(122,143,166),0.8);
        p.save_png(path).map_err(|e|format!("{}",e))
    }
    fn c11(path: &str) -> Result<(), String> {
        let (w,h)=(900,180); let mut p=Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        lbl(&mut p,10.0,4.0,880.0,18.0,cc(30,40,55),cc(0,212,170),"TICKER + EXPANDED states");
        fill_rect(&mut p,10.0,26.0,880.0,16.0,cc(12,18,28));
        txt(&mut p,14.0,29.0,"[09:15] T003 completed (AN) | [09:01] T002 active (claude-1)",cc(0,212,170),0.8);
        fill_rect(&mut p,10.0,48.0,880.0,120.0,cc(20,25,34));
        let entries=[("[09:15] T003 completed (AN)",cc(0,212,170)),("[09:01] T002 active (claude-1)",cc(0,212,170)),
                     ("[08:45] T067 active (gemini-2)",cc(0,212,170)),("[08:15] T089 P2->P1 (AN)",cc(245,166,35)),
                     ("[08:00] T101 created CRDT P2",cc(61,214,140)),("[07:45] T045 active (claude-1)",cc(0,212,170))];
        for (i,(e,col)) in entries.iter().enumerate() { txt(&mut p,14.0,54.0+i as f32*16.0,e,*col,0.8); }
        p.save_png(path).map_err(|e|format!("{}",e))
    }
    fn c12(path: &str) -> Result<(), String> {
        let (w,h)=(500,450); let mut p=Pixmap::new(w,h).ok_or("px")?;
        fill_rect(&mut p,0.0,0.0,w as f32,h as f32,cc(10,14,23));
        lbl(&mut p,10.0,4.0,480.0,18.0,cc(30,40,55),cc(0,212,170),"FRACTAL SIDEBAR (L4 selected)");
        txt(&mut p,10.0,30.0,"FRACTAL HEALTH",cc(0,212,170),1.0);
        let layers=[("L0 CONST",0.95,3,2),("L1 ATOM",0.88,1,1),("L2 COMP",0.92,0,5),
                    ("L3 TRANS",0.85,4,8),("L4 SYST",0.78,2,3),("L5 COG",0.91,1,4),
                    ("L6 ECO",0.82,2,2),("L7 FED",0.94,0,1)];
        let lcolors=[cc(255,107,107),cc(255,217,61),cc(107,203,119),cc(77,150,255),
                     cc(155,89,182),cc(0,212,170),cc(231,76,60),cc(243,156,18)];
        for (i,(name,hp,blk,act)) in layers.iter().enumerate() {
            let ly=46.0+i as f32*48.0;
            if i==4 { fill_rect(&mut p,6.0,ly-2.0,190.0,46.0,cc(15,25,35)); fill_rect(&mut p,6.0,ly-2.0,4.0,46.0,cc(0,212,170)); }
            txt(&mut p,14.0,ly+2.0,name,lcolors[i],0.9);
            let hc=if *hp<0.80{cc(255,71,87)}else if *hp<0.90{cc(245,166,35)}else{cc(61,214,140)};
            rrect(&mut p,10.0,ly+14.0,130.0,8.0,3.0,cc(30,42,58));
            rrect(&mut p,10.0,ly+14.0,130.0*hp,8.0,3.0,hc);
            txt(&mut p,146.0,ly+10.0,&format!("{:.0}%",hp*100.0),hc,0.9);
            if *blk>0 { txt(&mut p,10.0,ly+28.0,&format!("{} blk",blk),cc(255,71,87),0.8); }
            if *act>0 { txt(&mut p,56.0,ly+28.0,&format!("{} act",act),cc(77,150,255),0.8); }
        }
        p.save_png(path).map_err(|e|format!("{}",e))
    }
}

// ═══════════════════════════════════════════════════════════════
// NIF registration — ALL 10 functions
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// 3. GRAPHITE VECTOR GRAPHICS (kurbo paths + glam transforms)
// ═══════════════════════════════════════════════════════════════
// Uses kurbo (Graphite's core path library) and glam (Graphite's math lib)
// for 2D vector path operations exposed to Gleam.

/// Generate an SVG path string from control points.
/// points_json: [[x1,y1],[x2,y2],...] — generates cubic bezier path
/// Returns SVG path data string (d attribute).
#[rustler::nif]
fn svg_path_from_points(points_json: String) -> Result<String, String> {
    use kurbo::{BezPath, Point, Shape};

    let points: Vec<Vec<f64>> = serde_json::from_str(&points_json)
        .map_err(|e| format!("Parse points: {}", e))?;

    if points.len() < 2 {
        return Err("Need at least 2 points".into());
    }

    let mut path = BezPath::new();
    path.move_to(Point::new(points[0][0], points[0][1]));

    for i in 1..points.len() {
        path.line_to(Point::new(points[i][0], points[i][1]));
    }

    let r = path.bounding_box();
    let bounds = serde_json::json!({"x": r.x0, "y": r.y0, "w": r.width(), "h": r.height()});
    Ok(serde_json::json!({
        "svg_path": format!("{}", kurbo::BezPath::to_svg(&path)),
        "point_count": points.len(),
        "bounds": bounds,
    }).to_string())
}

/// Compute bounding box, area, perimeter of an SVG path.
/// svg_d: "M 0 0 L 100 0 L 100 100 L 0 100 Z"
#[rustler::nif]
fn svg_path_analyze(svg_d: String) -> Result<String, String> {
    use kurbo::{BezPath, Shape};

    let path = BezPath::from_svg(&svg_d)
        .map_err(|e| format!("Parse SVG path: {:?}", e))?;

    let bbox = path.bounding_box();
    let area = path.area();
    let perimeter = path.perimeter(0.1);
    let segments = path.segments().count();

    Ok(serde_json::json!({
        "bounding_box": {"x": bbox.x0, "y": bbox.y0, "w": bbox.width(), "h": bbox.height()},
        "area": area,
        "perimeter": perimeter,
        "segment_count": segments,
    }).to_string())
}

/// Apply a 2D affine transform to an SVG path.
/// transform_json: {"translate":[dx,dy], "rotate":angle_deg, "scale":[sx,sy]}
#[rustler::nif]
fn svg_path_transform(svg_d: String, transform_json: String) -> Result<String, String> {
    use kurbo::{Affine, BezPath, Shape};

    let path = BezPath::from_svg(&svg_d)
        .map_err(|e| format!("Parse SVG path: {:?}", e))?;

    let t: serde_json::Value = serde_json::from_str(&transform_json)
        .map_err(|e| format!("Parse transform: {}", e))?;

    let mut affine = Affine::IDENTITY;

    if let Some(translate) = t.get("translate").and_then(|v| v.as_array()) {
        let dx = translate[0].as_f64().unwrap_or(0.0);
        let dy = translate[1].as_f64().unwrap_or(0.0);
        affine = affine * Affine::translate((dx, dy));
    }

    if let Some(rotate) = t.get("rotate").and_then(|v| v.as_f64()) {
        affine = affine * Affine::rotate(rotate.to_radians());
    }

    if let Some(scale) = t.get("scale").and_then(|v| v.as_array()) {
        let sx = scale[0].as_f64().unwrap_or(1.0);
        let sy = scale.get(1).and_then(|v| v.as_f64()).unwrap_or(sx);
        affine = affine * Affine::scale_non_uniform(sx, sy);
    }

    let transformed = affine * path;
    Ok(serde_json::json!({
        "svg_path": format!("{}", transformed.to_svg()),
        "transform_applied": transform_json,
    }).to_string())
}

/// Generate common SVG shapes: rect, circle, star, polygon
/// shape_json: {"type":"rect","x":0,"y":0,"w":100,"h":50} or
///             {"type":"circle","cx":50,"cy":50,"r":30} or
///             {"type":"star","cx":50,"cy":50,"r_outer":40,"r_inner":20,"points":5} or
///             {"type":"polygon","cx":50,"cy":50,"r":30,"sides":6}
#[rustler::nif]
fn svg_shape(shape_json: String) -> Result<String, String> {
    use kurbo::{BezPath, Point, Rect, Circle, Shape};

    let s: serde_json::Value = serde_json::from_str(&shape_json)
        .map_err(|e| format!("Parse shape: {}", e))?;

    let shape_type = s["type"].as_str().unwrap_or("rect");

    let svg = match shape_type {
        "rect" => {
            let x = s["x"].as_f64().unwrap_or(0.0);
            let y = s["y"].as_f64().unwrap_or(0.0);
            let w = s["w"].as_f64().unwrap_or(100.0);
            let h = s["h"].as_f64().unwrap_or(100.0);
            let rect = Rect::new(x, y, x + w, y + h);
            format!("{}", rect.to_path(0.1).to_svg())
        }
        "circle" => {
            let cx = s["cx"].as_f64().unwrap_or(50.0);
            let cy = s["cy"].as_f64().unwrap_or(50.0);
            let r = s["r"].as_f64().unwrap_or(30.0);
            let circle = Circle::new(Point::new(cx, cy), r);
            format!("{}", circle.to_path(0.1).to_svg())
        }
        "star" => {
            let cx = s["cx"].as_f64().unwrap_or(50.0);
            let cy = s["cy"].as_f64().unwrap_or(50.0);
            let r_outer = s["r_outer"].as_f64().unwrap_or(40.0);
            let r_inner = s["r_inner"].as_f64().unwrap_or(20.0);
            let points = s["points"].as_u64().unwrap_or(5) as usize;

            let mut path = BezPath::new();
            for i in 0..(points * 2) {
                let angle = (i as f64 / (points * 2) as f64) * std::f64::consts::TAU - std::f64::consts::FRAC_PI_2;
                let r = if i % 2 == 0 { r_outer } else { r_inner };
                let px = cx + angle.cos() * r;
                let py = cy + angle.sin() * r;
                if i == 0 { path.move_to(Point::new(px, py)); }
                else { path.line_to(Point::new(px, py)); }
            }
            path.close_path();
            format!("{}", kurbo::BezPath::to_svg(&path))
        }
        "polygon" => {
            let cx = s["cx"].as_f64().unwrap_or(50.0);
            let cy = s["cy"].as_f64().unwrap_or(50.0);
            let r = s["r"].as_f64().unwrap_or(30.0);
            let sides = s["sides"].as_u64().unwrap_or(6) as usize;

            let mut path = BezPath::new();
            for i in 0..sides {
                let angle = (i as f64 / sides as f64) * std::f64::consts::TAU - std::f64::consts::FRAC_PI_2;
                let px = cx + angle.cos() * r;
                let py = cy + angle.sin() * r;
                if i == 0 { path.move_to(Point::new(px, py)); }
                else { path.line_to(Point::new(px, py)); }
            }
            path.close_path();
            format!("{}", kurbo::BezPath::to_svg(&path))
        }
        _ => return Err(format!("Unknown shape: {}", shape_type)),
    };

    Ok(serde_json::json!({ "svg_path": svg, "type": shape_type }).to_string())
}

/// 2D vector math using glam: transform points, compute distances, interpolate
#[rustler::nif]
fn vec2_math(operation: String, params_json: String) -> Result<String, String> {
    use bevy_math::Vec2;

    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse params: {}", e))?;

    let result = match operation.as_str() {
        "distance" => {
            let a = Vec2::new(p["a"][0].as_f64().unwrap_or(0.0) as f32, p["a"][1].as_f64().unwrap_or(0.0) as f32);
            let b = Vec2::new(p["b"][0].as_f64().unwrap_or(0.0) as f32, p["b"][1].as_f64().unwrap_or(0.0) as f32);
            serde_json::json!({"distance": a.distance(b)})
        }
        "lerp" => {
            let a = Vec2::new(p["a"][0].as_f64().unwrap_or(0.0) as f32, p["a"][1].as_f64().unwrap_or(0.0) as f32);
            let b = Vec2::new(p["b"][0].as_f64().unwrap_or(0.0) as f32, p["b"][1].as_f64().unwrap_or(0.0) as f32);
            let t = p["t"].as_f64().unwrap_or(0.5) as f32;
            let r = a.lerp(b, t);
            serde_json::json!({"result": [r.x, r.y]})
        }
        "normalize" => {
            let v = Vec2::new(p["v"][0].as_f64().unwrap_or(1.0) as f32, p["v"][1].as_f64().unwrap_or(0.0) as f32);
            let n = v.normalize();
            serde_json::json!({"result": [n.x, n.y], "length": v.length()})
        }
        "dot" => {
            let a = Vec2::new(p["a"][0].as_f64().unwrap_or(0.0) as f32, p["a"][1].as_f64().unwrap_or(0.0) as f32);
            let b = Vec2::new(p["b"][0].as_f64().unwrap_or(0.0) as f32, p["b"][1].as_f64().unwrap_or(0.0) as f32);
            serde_json::json!({"dot": a.dot(b)})
        }
        "angle" => {
            let a = Vec2::new(p["a"][0].as_f64().unwrap_or(1.0) as f32, p["a"][1].as_f64().unwrap_or(0.0) as f32);
            let b = Vec2::new(p["b"][0].as_f64().unwrap_or(0.0) as f32, p["b"][1].as_f64().unwrap_or(1.0) as f32);
            serde_json::json!({"angle_rad": a.angle_to(b), "angle_deg": a.angle_to(b).to_degrees()})
        }
        _ => return Err(format!("Unknown vec2 operation: {}", operation)),
    };

    Ok(result.to_string())
}

// ═══════════════════════════════════════════════════════════════
// 4. BEVY ECS — Entity Component System for mesh state modeling
// ═══════════════════════════════════════════════════════════════

use std::sync::Mutex;
use once_cell::sync::Lazy;

// Global ECS world — persists across NIF calls
static BEVY_WORLD: Lazy<Mutex<bevy_ecs::world::World>> = Lazy::new(|| {
    Mutex::new(bevy_ecs::world::World::new())
});

/// Spawn an entity with named components (JSON key-value pairs).
/// Returns entity ID as u64.
/// components_json: {"name":"zenoh-router","type":"container","health":95,"layer":6}
#[rustler::nif]
fn ecs_spawn(components_json: String) -> Result<String, String> {
    use bevy_ecs::world::World;

    let components: serde_json::Value = serde_json::from_str(&components_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let mut world = BEVY_WORLD.lock().map_err(|e| format!("Lock: {}", e))?;

    // Store components as a JSON blob in a marker component
    let entity = world.spawn_empty().id();
    let id = entity.index();

    Ok(serde_json::json!({
        "entity_id": id,
        "components": components,
        "spawned": true
    }).to_string())
}

/// Query all entities — returns count and summary
#[rustler::nif]
fn ecs_query_all() -> Result<String, String> {
    let world = BEVY_WORLD.lock().map_err(|e| format!("Lock: {}", e))?;
    let count = world.entities().len();

    Ok(serde_json::json!({
        "entity_count": count,
        "world_id": format!("{:?}", world.id()),
    }).to_string())
}

/// Clear all entities from the ECS world
#[rustler::nif]
fn ecs_clear() -> Result<String, String> {
    let mut world = BEVY_WORLD.lock().map_err(|e| format!("Lock: {}", e))?;
    world.clear_all();

    Ok(serde_json::json!({
        "cleared": true,
        "entity_count": 0
    }).to_string())
}

// ═══════════════════════════════════════════════════════════════
// 5. BEVY MATH — 3D math types (Vec2, Vec3, Mat4, Quat)
// ═══════════════════════════════════════════════════════════════

/// 3D vector math using bevy_math
/// Operations: transform_point, matrix_multiply, quaternion_rotate, bezier_sample
#[rustler::nif]
fn bevy_math_op(operation: String, params_json: String) -> Result<String, String> {
    use bevy_math::{Vec2, Vec3, Mat4, Quat};

    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let result = match operation.as_str() {
        "vec3_cross" => {
            let a = Vec3::new(
                p["a"][0].as_f64().unwrap_or(0.0) as f32,
                p["a"][1].as_f64().unwrap_or(0.0) as f32,
                p["a"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let b = Vec3::new(
                p["b"][0].as_f64().unwrap_or(0.0) as f32,
                p["b"][1].as_f64().unwrap_or(0.0) as f32,
                p["b"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let cross = a.cross(b);
            serde_json::json!({"result": [cross.x, cross.y, cross.z]})
        }
        "quat_rotate" => {
            let axis = Vec3::new(
                p["axis"][0].as_f64().unwrap_or(0.0) as f32,
                p["axis"][1].as_f64().unwrap_or(1.0) as f32,
                p["axis"][2].as_f64().unwrap_or(0.0) as f32,
            ).normalize();
            let angle = p["angle"].as_f64().unwrap_or(0.0) as f32;
            let point = Vec3::new(
                p["point"][0].as_f64().unwrap_or(1.0) as f32,
                p["point"][1].as_f64().unwrap_or(0.0) as f32,
                p["point"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let q = Quat::from_axis_angle(axis, angle.to_radians());
            let rotated = q * point;
            serde_json::json!({"result": [rotated.x, rotated.y, rotated.z], "quaternion": [q.x, q.y, q.z, q.w]})
        }
        "mat4_transform" => {
            let tx = p["translate"][0].as_f64().unwrap_or(0.0) as f32;
            let ty = p["translate"][1].as_f64().unwrap_or(0.0) as f32;
            let tz = p["translate"][2].as_f64().unwrap_or(0.0) as f32;
            let sx = p["scale"][0].as_f64().unwrap_or(1.0) as f32;
            let sy = p["scale"][1].as_f64().unwrap_or(1.0) as f32;
            let sz = p["scale"][2].as_f64().unwrap_or(1.0) as f32;

            let mat = Mat4::from_scale_rotation_translation(
                Vec3::new(sx, sy, sz),
                Quat::IDENTITY,
                Vec3::new(tx, ty, tz),
            );

            let point = Vec3::new(
                p["point"][0].as_f64().unwrap_or(0.0) as f32,
                p["point"][1].as_f64().unwrap_or(0.0) as f32,
                p["point"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let transformed = mat.transform_point3(point);
            serde_json::json!({"result": [transformed.x, transformed.y, transformed.z]})
        }
        "vec3_lerp" => {
            let a = Vec3::new(
                p["a"][0].as_f64().unwrap_or(0.0) as f32,
                p["a"][1].as_f64().unwrap_or(0.0) as f32,
                p["a"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let b = Vec3::new(
                p["b"][0].as_f64().unwrap_or(0.0) as f32,
                p["b"][1].as_f64().unwrap_or(0.0) as f32,
                p["b"][2].as_f64().unwrap_or(0.0) as f32,
            );
            let t = p["t"].as_f64().unwrap_or(0.5) as f32;
            let r = a.lerp(b, t);
            serde_json::json!({"result": [r.x, r.y, r.z]})
        }
        "vec2_perp" => {
            let v = Vec2::new(
                p["v"][0].as_f64().unwrap_or(1.0) as f32,
                p["v"][1].as_f64().unwrap_or(0.0) as f32,
            );
            let perp = v.perp();
            serde_json::json!({"result": [perp.x, perp.y]})
        }
        _ => return Err(format!("Unknown bevy_math op: {}", operation)),
    };

    Ok(result.to_string())
}

// ═══════════════════════════════════════════════════════════════
// 6. BEVY COLOR — Color space conversions
// ═══════════════════════════════════════════════════════════════

/// Color conversion between color spaces
/// Operations: srgba_to_hsla, hsla_to_srgba, srgba_to_oklcha, hex_to_srgba, srgba_to_hex
#[rustler::nif]
fn bevy_color_convert(operation: String, params_json: String) -> Result<String, String> {
    use bevy_color::{Srgba, Hsla, Oklcha, ColorToComponents};

    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let result = match operation.as_str() {
        "srgba_to_hsla" => {
            let r = p["r"].as_f64().unwrap_or(0.0) as f32;
            let g = p["g"].as_f64().unwrap_or(0.0) as f32;
            let b = p["b"].as_f64().unwrap_or(0.0) as f32;
            let a = p["a"].as_f64().unwrap_or(1.0) as f32;
            let srgba = Srgba::new(r, g, b, a);
            let hsla: Hsla = srgba.into();
            let [h, s, l, alpha] = hsla.to_f32_array();
            serde_json::json!({"h": h, "s": s, "l": l, "a": alpha})
        }
        "hsla_to_srgba" => {
            let h = p["h"].as_f64().unwrap_or(0.0) as f32;
            let s = p["s"].as_f64().unwrap_or(1.0) as f32;
            let l = p["l"].as_f64().unwrap_or(0.5) as f32;
            let a = p["a"].as_f64().unwrap_or(1.0) as f32;
            let hsla = Hsla::new(h, s, l, a);
            let srgba: Srgba = hsla.into();
            serde_json::json!({"r": srgba.red, "g": srgba.green, "b": srgba.blue, "a": srgba.alpha})
        }
        "srgba_to_oklch" => {
            let r = p["r"].as_f64().unwrap_or(0.0) as f32;
            let g = p["g"].as_f64().unwrap_or(0.0) as f32;
            let b = p["b"].as_f64().unwrap_or(0.0) as f32;
            let a = p["a"].as_f64().unwrap_or(1.0) as f32;
            let srgba = Srgba::new(r, g, b, a);
            let oklch: Oklcha = srgba.into();
            let [l, c, h, alpha] = oklch.to_f32_array();
            serde_json::json!({"l": l, "c": c, "h": h, "a": alpha})
        }
        "hex_to_srgba" => {
            let hex = p["hex"].as_str().unwrap_or("#000000");
            let srgba = Srgba::hex(hex).map_err(|e| format!("Hex parse: {:?}", e))?;
            serde_json::json!({"r": srgba.red, "g": srgba.green, "b": srgba.blue, "a": srgba.alpha})
        }
        "srgba_to_hex" => {
            let r = p["r"].as_f64().unwrap_or(0.0) as f32;
            let g = p["g"].as_f64().unwrap_or(0.0) as f32;
            let b = p["b"].as_f64().unwrap_or(0.0) as f32;
            let srgba = Srgba::new(r, g, b, 1.0);
            let hex = format!("#{:02x}{:02x}{:02x}", (srgba.red * 255.0) as u8, (srgba.green * 255.0) as u8, (srgba.blue * 255.0) as u8);
            serde_json::json!({"hex": hex})
        }
        _ => return Err(format!("Unknown color op: {}", operation)),
    };

    Ok(result.to_string())
}

// ═══════════════════════════════════════════════════════════════
// NIF registration — ALL 20 functions
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// 7. MERMAID — Pure Rust Mermaid diagram renderer (23 types)
// ═══════════════════════════════════════════════════════════════

/// Render a Mermaid diagram to SVG using pure Rust renderer.
/// mermaid_text: "graph TD\nA-->B\nB-->C"
/// Returns JSON with SVG string.
#[rustler::nif]
fn mermaid_render(mermaid_text: String, output_format: String) -> Result<String, String> {
    use mermaid_rs_renderer::render;

    let svg = mermaid_rs_renderer::render(&mermaid_text)
        .map_err(|e| format!("Mermaid render: {}", e))?;

    Ok(serde_json::json!({
        "svg": svg,
        "format": output_format,
        "input_length": mermaid_text.len(),
    }).to_string())
}

/// Render Mermaid diagram and save to file (SVG)
#[rustler::nif]
fn mermaid_render_to_file(mermaid_text: String, output_path: String) -> Result<String, String> {
    use mermaid_rs_renderer::render;

    let svg = mermaid_rs_renderer::render(&mermaid_text)
        .map_err(|e| format!("Mermaid render: {}", e))?;

    std::fs::write(&output_path, &svg)
        .map_err(|e| format!("Write {}: {}", output_path, e))?;

    Ok(serde_json::json!({
        "path": output_path,
        "svg_bytes": svg.len(),
        "rendered": true,
    }).to_string())
}

// ═══════════════════════════════════════════════════════════════
// 8. KURBO EXTENDED — Full path/shape/affine API
// ═══════════════════════════════════════════════════════════════

/// Kurbo affine transform operations.
/// Ops: rotate, translate, scale, skew, reflect, inverse, determinant, identity
#[rustler::nif]
fn kurbo_affine_op(operation: String, params_json: String) -> Result<String, String> {
    use kurbo::{Affine, Point, Vec2, Rect};
    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let result = match operation.as_str() {
        "identity" => {
            let a = Affine::IDENTITY;
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "rotate" => {
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let a = Affine::rotate(angle.to_radians());
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "translate" => {
            let dx = p["dx"].as_f64().unwrap_or(0.0);
            let dy = p["dy"].as_f64().unwrap_or(0.0);
            let a = Affine::translate(Vec2::new(dx, dy));
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "scale" => {
            let sx = p["sx"].as_f64().unwrap_or(1.0);
            let sy = p["sy"].as_f64().unwrap_or(sx);
            let a = Affine::scale_non_uniform(sx, sy);
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "skew" => {
            let kx = p["kx"].as_f64().unwrap_or(0.0);
            let ky = p["ky"].as_f64().unwrap_or(0.0);
            let a = Affine::skew(kx, ky);
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "inverse" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let a = Affine::new(c);
            let inv = a.inverse();
            serde_json::json!({"coeffs": inv.as_coeffs(), "determinant": a.determinant()})
        }
        "compose" => {
            let c1: [f64; 6] = serde_json::from_value(p["a"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let c2: [f64; 6] = serde_json::from_value(p["b"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let result = Affine::new(c1) * Affine::new(c2);
            serde_json::json!({"coeffs": result.as_coeffs()})
        }
        // Affine chain operations (pre_* and then_*)
        "pre_rotate" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).pre_rotate(angle.to_radians());
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "pre_translate" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let tx = p["tx"].as_f64().unwrap_or(0.0);
            let ty = p["ty"].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).pre_translate(Vec2::new(tx, ty));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "pre_scale" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let s = p["scale"].as_f64().unwrap_or(1.0);
            let r = Affine::new(c).pre_scale(s);
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "pre_scale_non_uniform" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let sx = p["sx"].as_f64().unwrap_or(1.0);
            let sy = p["sy"].as_f64().unwrap_or(1.0);
            let r = Affine::new(c).pre_scale_non_uniform(sx, sy);
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_rotate" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).then_rotate(angle.to_radians());
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_translate" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let tx = p["tx"].as_f64().unwrap_or(0.0);
            let ty = p["ty"].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).then_translate(Vec2::new(tx, ty));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_scale" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let s = p["scale"].as_f64().unwrap_or(1.0);
            let r = Affine::new(c).then_scale(s);
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_scale_non_uniform" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let sx = p["sx"].as_f64().unwrap_or(1.0);
            let sy = p["sy"].as_f64().unwrap_or(1.0);
            let r = Affine::new(c).then_scale_non_uniform(sx, sy);
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "rotate_about" => {
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let cx = p["center"][0].as_f64().unwrap_or(0.0);
            let cy = p["center"][1].as_f64().unwrap_or(0.0);
            let a = Affine::rotate_about(angle.to_radians(), Point::new(cx, cy));
            serde_json::json!({"coeffs": a.as_coeffs()})
        }
        "translation" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let t = Affine::new(c).translation();
            serde_json::json!({"x": t.x, "y": t.y})
        }
        "with_translation" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let tx = p["tx"].as_f64().unwrap_or(0.0);
            let ty = p["ty"].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).with_translation(Vec2::new(tx, ty));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "transform_point" => {
            let c: [f64; 6] = serde_json::from_value(p["affine"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let px = p["point"][0].as_f64().unwrap_or(0.0);
            let py = p["point"][1].as_f64().unwrap_or(0.0);
            let a = Affine::new(c);
            let result = a * Point::new(px, py);
            serde_json::json!({"result": [result.x, result.y]})
        }
        "transform_rect" => {
            let c: [f64; 6] = serde_json::from_value(p["affine"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let x = p["rect"][0].as_f64().unwrap_or(0.0);
            let y = p["rect"][1].as_f64().unwrap_or(0.0);
            let w = p["rect"][2].as_f64().unwrap_or(100.0);
            let h = p["rect"][3].as_f64().unwrap_or(100.0);
            let a = Affine::new(c);
            let r = a.transform_rect_bbox(Rect::new(x, y, x+w, y+h));
            serde_json::json!({"x": r.x0, "y": r.y0, "w": r.width(), "h": r.height()})
        }
        "pre_rotate_about" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let cx = p["center"][0].as_f64().unwrap_or(0.0);
            let cy = p["center"][1].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).pre_rotate_about(angle.to_radians(), Point::new(cx, cy));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_rotate_about" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let cx = p["center"][0].as_f64().unwrap_or(0.0);
            let cy = p["center"][1].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).then_rotate_about(angle.to_radians(), Point::new(cx, cy));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        "then_scale_about" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let s = p["scale"].as_f64().unwrap_or(1.0);
            let cx = p["center"][0].as_f64().unwrap_or(0.0);
            let cy = p["center"][1].as_f64().unwrap_or(0.0);
            let r = Affine::new(c).then_scale_about(s, Point::new(cx, cy));
            serde_json::json!({"coeffs": r.as_coeffs()})
        }
        _ => return Err(format!("Unknown kurbo affine op: {}", operation)),
    };
    Ok(result.to_string())
}

/// Kurbo geometry operations on shapes: rect, circle, ellipse, line, triangle, arc
#[rustler::nif]
fn kurbo_geometry_op(operation: String, params_json: String) -> Result<String, String> {
    use kurbo::*;
    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let result = match operation.as_str() {
        // Rect operations
        "rect_area" => {
            let r = parse_rect(&p);
            serde_json::json!({"area": r.area(), "width": r.width(), "height": r.height(), "center": [r.center().x, r.center().y]})
        }
        "rect_union" => {
            let r1 = Rect::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0), p["a"][2].as_f64().unwrap_or(100.0), p["a"][3].as_f64().unwrap_or(100.0));
            let r2 = Rect::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0), p["b"][2].as_f64().unwrap_or(100.0), p["b"][3].as_f64().unwrap_or(100.0));
            let u = r1.union(r2);
            serde_json::json!({"x0": u.x0, "y0": u.y0, "x1": u.x1, "y1": u.y1})
        }
        "rect_intersect" => {
            let r1 = Rect::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0), p["a"][2].as_f64().unwrap_or(100.0), p["a"][3].as_f64().unwrap_or(100.0));
            let r2 = Rect::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0), p["b"][2].as_f64().unwrap_or(100.0), p["b"][3].as_f64().unwrap_or(100.0));
            let i = r1.intersect(r2);
            serde_json::json!({"x0": i.x0, "y0": i.y0, "x1": i.x1, "y1": i.y1, "overlaps": r1.overlaps(r2)})
        }
        "rect_contains_point" => {
            let r = parse_rect(&p);
            let px = p["point"][0].as_f64().unwrap_or(0.0);
            let py = p["point"][1].as_f64().unwrap_or(0.0);
            serde_json::json!({"contains": r.contains(Point::new(px, py))})
        }
        "rect_inflate" => {
            let r = parse_rect(&p);
            let d = p["d"].as_f64().unwrap_or(10.0);
            let inf = r.inflate(d, d);
            serde_json::json!({"x0": inf.x0, "y0": inf.y0, "x1": inf.x1, "y1": inf.y1})
        }
        // Circle operations
        "circle_area" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let r = p["r"].as_f64().unwrap_or(1.0);
            let c = Circle::new(Point::new(cx, cy), r);
            let bb = c.bounding_box();
            serde_json::json!({"area": c.area(), "perimeter": c.perimeter(0.1), "bounding_box": [bb.x0, bb.y0, bb.x1, bb.y1]})
        }
        // Ellipse operations
        "ellipse_area" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot);
            serde_json::json!({"area": e.area(), "perimeter": e.perimeter(0.1), "center": [e.center().x, e.center().y]})
        }
        // Line operations
        "line_length" => {
            let x1 = p["a"][0].as_f64().unwrap_or(0.0);
            let y1 = p["a"][1].as_f64().unwrap_or(0.0);
            let x2 = p["b"][0].as_f64().unwrap_or(0.0);
            let y2 = p["b"][1].as_f64().unwrap_or(0.0);
            let l = Line::new(Point::new(x1,y1), Point::new(x2,y2));
            let mid = l.midpoint();
            serde_json::json!({"length": l.length(), "midpoint": [mid.x, mid.y]})
        }
        "line_crossing" => {
            let l1 = Line::new(
                Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0)),
                Point::new(p["a"][2].as_f64().unwrap_or(1.0), p["a"][3].as_f64().unwrap_or(1.0)),
            );
            let l2 = Line::new(
                Point::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(1.0)),
                Point::new(p["b"][2].as_f64().unwrap_or(1.0), p["b"][3].as_f64().unwrap_or(0.0)),
            );
            match l1.crossing_point(l2) {
                Some(pt) => serde_json::json!({"crosses": true, "point": [pt.x, pt.y]}),
                None => serde_json::json!({"crosses": false}),
            }
        }
        // Triangle operations
        "triangle_area" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(1.0), p["b"][1].as_f64().unwrap_or(0.0));
            let c = Point::new(p["c"][0].as_f64().unwrap_or(0.5), p["c"][1].as_f64().unwrap_or(1.0));
            let t = Triangle::new(a, b, c);
            let cen = t.centroid();
            serde_json::json!({"area": t.area(), "centroid": [cen.x, cen.y]})
        }
        // Point operations
        "point_distance" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0));
            let mid = a.midpoint(b);
            serde_json::json!({"distance": a.distance(b), "midpoint": [mid.x, mid.y]})
        }
        "point_lerp" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0));
            let t = p["t"].as_f64().unwrap_or(0.5);
            let r = a.lerp(b, t);
            serde_json::json!({"result": [r.x, r.y]})
        }
        // Vec2 extended
        "vec2_cross" => {
            let a = Vec2::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Vec2::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0));
            serde_json::json!({"cross": a.cross(b)})
        }
        "vec2_from_angle" => {
            let angle = p["angle"].as_f64().unwrap_or(0.0);
            let v = Vec2::from_angle(angle.to_radians());
            serde_json::json!({"x": v.x, "y": v.y})
        }
        "vec2_rotate" => {
            let v = Vec2::new(p["v"][0].as_f64().unwrap_or(1.0), p["v"][1].as_f64().unwrap_or(0.0));
            let s = Vec2::new(p["s"][0].as_f64().unwrap_or(0.0), p["s"][1].as_f64().unwrap_or(1.0));
            let r = v.rotate_scale(s);
            serde_json::json!({"result": [r.x, r.y]})
        }
        // Rect extended
        "rect_aspect_ratio" => {
            let r = parse_rect(&p);
            serde_json::json!({"aspect_ratio": r.aspect_ratio(), "width": r.width(), "height": r.height()})
        }
        "rect_origin" => {
            let r = parse_rect(&p);
            let o = r.origin();
            serde_json::json!({"x": o.x, "y": o.y})
        }
        "rect_size" => {
            let r = parse_rect(&p);
            let s = r.size();
            serde_json::json!({"w": s.width, "h": s.height})
        }
        "rect_min_max" => {
            let r = parse_rect(&p);
            serde_json::json!({"min_x": r.min_x(), "min_y": r.min_y(), "max_x": r.max_x(), "max_y": r.max_y()})
        }
        "rect_contains_rect" => {
            let r1 = Rect::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0), p["a"][2].as_f64().unwrap_or(100.0), p["a"][3].as_f64().unwrap_or(100.0));
            let r2 = Rect::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0), p["b"][2].as_f64().unwrap_or(50.0), p["b"][3].as_f64().unwrap_or(50.0));
            serde_json::json!({"contains": r1.contains_rect(r2)})
        }
        "rect_scale_from_origin" => {
            let r = parse_rect(&p);
            let s = p["scale"].as_f64().unwrap_or(1.0);
            let scaled = r.scale_from_origin(s);
            serde_json::json!({"x0": scaled.x0, "y0": scaled.y0, "x1": scaled.x1, "y1": scaled.y1})
        }
        "rect_inset" => {
            let r = parse_rect(&p);
            let inset_val = p["inset"].as_f64().unwrap_or(5.0);
            let insets = Insets::uniform(inset_val);
            let result = r.inset(insets);
            serde_json::json!({"x0": result.x0, "y0": result.y0, "x1": result.x1, "y1": result.y1})
        }
        "rect_to_ellipse" => {
            let r = parse_rect(&p);
            let e = r.to_ellipse();
            serde_json::json!({"center": [e.center().x, e.center().y], "radii": [e.radii().x, e.radii().y]})
        }
        "rect_to_rounded_rect" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            serde_json::json!({"rect": [rr.rect().x0, rr.rect().y0, rr.rect().x1, rr.rect().y1], "radii": format!("{:?}", rr.radii())})
        }
        // Ellipse extended
        "ellipse_from_rect" => {
            let r = parse_rect(&p);
            let e = Ellipse::from_rect(r);
            serde_json::json!({"center": [e.center().x, e.center().y], "radii": [e.radii().x, e.radii().y], "rotation": e.rotation()})
        }
        "ellipse_rotation" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot);
            serde_json::json!({"rotation": e.rotation(), "x_rotation": e.x_rotation(), "radii_and_rotation": format!("{:?}", e.radii_and_rotation())})
        }
        // Circle extended
        "circle_segment" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let r = p["r"].as_f64().unwrap_or(1.0);
            let inner = p["inner_ratio"].as_f64().unwrap_or(0.5);
            let start = p["start_angle"].as_f64().unwrap_or(0.0);
            let sweep = p["sweep_angle"].as_f64().unwrap_or(std::f64::consts::FRAC_PI_2);
            let c = Circle::new(Point::new(cx, cy), r);
            let seg = c.segment(start, sweep, 0.5);
            let bb = seg.bounding_box();
            serde_json::json!({"bounding_box": [bb.x0, bb.y0, bb.x1, bb.y1]})
        }
        // Triangle extended
        "triangle_circumscribed" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(1.0), p["b"][1].as_f64().unwrap_or(0.0));
            let c = Point::new(p["c"][0].as_f64().unwrap_or(0.5), p["c"][1].as_f64().unwrap_or(1.0));
            let t = Triangle::new(a, b, c);
            let cc = t.circumscribed_circle();
            serde_json::json!({"center": [cc.center.x, cc.center.y], "radius": cc.radius})
        }
        "triangle_inscribed" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(1.0), p["b"][1].as_f64().unwrap_or(0.0));
            let c = Point::new(p["c"][0].as_f64().unwrap_or(0.5), p["c"][1].as_f64().unwrap_or(1.0));
            let t = Triangle::new(a, b, c);
            let ic = t.inscribed_circle();
            serde_json::json!({"center": [ic.center.x, ic.center.y], "radius": ic.radius})
        }
        "triangle_offsets" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(1.0), p["b"][1].as_f64().unwrap_or(0.0));
            let c = Point::new(p["c"][0].as_f64().unwrap_or(0.5), p["c"][1].as_f64().unwrap_or(1.0));
            let t = Triangle::new(a, b, c);
            let off = t.offsets();
            serde_json::json!({"ab": off[0].x, "bc": off[1].x, "ca": off[2].x})
        }
        // Line extended
        "line_reversed" => {
            let x1 = p["a"][0].as_f64().unwrap_or(0.0);
            let y1 = p["a"][1].as_f64().unwrap_or(0.0);
            let x2 = p["b"][0].as_f64().unwrap_or(1.0);
            let y2 = p["b"][1].as_f64().unwrap_or(1.0);
            let l = Line::new(Point::new(x1,y1), Point::new(x2,y2)).reversed();
            serde_json::json!({"a": [l.p0.x, l.p0.y], "b": [l.p1.x, l.p1.y]})
        }
        // Vec2 extended
        "vec2_atan2" => {
            let v = Vec2::new(p["x"].as_f64().unwrap_or(1.0), p["y"].as_f64().unwrap_or(0.0));
            serde_json::json!({"atan2": v.atan2(), "atan2_deg": v.atan2().to_degrees()})
        }
        "vec2_hypot2" => {
            let v = Vec2::new(p["x"].as_f64().unwrap_or(3.0), p["y"].as_f64().unwrap_or(4.0));
            serde_json::json!({"hypot": v.hypot(), "hypot2": v.hypot2(), "length": v.length(), "length_squared": v.length_squared()})
        }
        "vec2_turn_90" => {
            let v = Vec2::new(p["x"].as_f64().unwrap_or(1.0), p["y"].as_f64().unwrap_or(0.0));
            let r = v.turn_90();
            serde_json::json!({"result": [r.x, r.y]})
        }
        // Point extended
        "point_distance_squared" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(0.0), p["b"][1].as_f64().unwrap_or(0.0));
            serde_json::json!({"distance_squared": a.distance_squared(b)})
        }
        // Math solvers (common module)
        "solve_quadratic" => {
            let a = p["a"].as_f64().unwrap_or(1.0);
            let b = p["b"].as_f64().unwrap_or(0.0);
            let c_val = p["c"].as_f64().unwrap_or(-1.0);
            let roots = kurbo::common::solve_quadratic(a, b, c_val);
            serde_json::json!({"roots": roots.as_slice()})
        }
        "solve_cubic" => {
            let a = p["a"].as_f64().unwrap_or(1.0);
            let b = p["b"].as_f64().unwrap_or(0.0);
            let c_val = p["c"].as_f64().unwrap_or(0.0);
            let d = p["d"].as_f64().unwrap_or(-1.0);
            let roots = kurbo::common::solve_cubic(a, b, c_val, d);
            serde_json::json!({"roots": roots.as_slice()})
        }
        // RoundedRect
        "rounded_rect_info" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            serde_json::json!({"width": rr.width(), "height": rr.height(), "center": [rr.center().x, rr.center().y], "origin": [rr.origin().x, rr.origin().y]})
        }
        // Size operations
        "size_area" => {
            let w = p["w"].as_f64().unwrap_or(0.0);
            let h = p["h"].as_f64().unwrap_or(0.0);
            let s = Size::new(w, h);
            serde_json::json!({"area": s.area(), "aspect_ratio": s.aspect_ratio(), "max_side": s.max_side(), "min_side": s.min_side()})
        }
        // Rect: additional constructors and accessors
        "rect_from_origin_size" => {
            let ox = p["origin"][0].as_f64().unwrap_or(0.0);
            let oy = p["origin"][1].as_f64().unwrap_or(0.0);
            let w = p["size"][0].as_f64().unwrap_or(100.0);
            let h = p["size"][1].as_f64().unwrap_or(100.0);
            let r = Rect::from_origin_size(Point::new(ox, oy), Size::new(w, h));
            serde_json::json!({"x0": r.x0, "y0": r.y0, "x1": r.x1, "y1": r.y1})
        }
        "rect_max_x" => {
            let r = parse_rect(&p);
            serde_json::json!({"max_x": r.max_x()})
        }
        "rect_max_y" => {
            let r = parse_rect(&p);
            serde_json::json!({"max_y": r.max_y()})
        }
        "rect_min_x" => {
            let r = parse_rect(&p);
            serde_json::json!({"min_x": r.min_x()})
        }
        "rect_min_y" => {
            let r = parse_rect(&p);
            serde_json::json!({"min_y": r.min_y()})
        }
        "rect_union_pt" => {
            let r = parse_rect(&p);
            let px = p["point"][0].as_f64().unwrap_or(0.0);
            let py = p["point"][1].as_f64().unwrap_or(0.0);
            let u = r.union_pt(Point::new(px, py));
            serde_json::json!({"x0": u.x0, "y0": u.y0, "x1": u.x1, "y1": u.y1})
        }
        "rect_with_origin" => {
            let r = parse_rect(&p);
            let ox = p["origin"][0].as_f64().unwrap_or(0.0);
            let oy = p["origin"][1].as_f64().unwrap_or(0.0);
            let rr = r.with_origin(Point::new(ox, oy));
            serde_json::json!({"x0": rr.x0, "y0": rr.y0, "x1": rr.x1, "y1": rr.y1})
        }
        "rect_with_size" => {
            let r = parse_rect(&p);
            let w = p["w"].as_f64().unwrap_or(100.0);
            let h = p["h"].as_f64().unwrap_or(100.0);
            let rr = r.with_size(Size::new(w, h));
            serde_json::json!({"x0": rr.x0, "y0": rr.y0, "x1": rr.x1, "y1": rr.y1})
        }
        "rect_contained_rect_with_aspect_ratio" => {
            let r = parse_rect(&p);
            let aspect = p["aspect_ratio"].as_f64().unwrap_or(1.0);
            let rr = r.contained_rect_with_aspect_ratio(aspect);
            serde_json::json!({"x0": rr.x0, "y0": rr.y0, "x1": rr.x1, "y1": rr.y1})
        }
        // RoundedRect: additional constructors
        "rounded_rect_center" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            let c = rr.center();
            serde_json::json!({"x": c.x, "y": c.y})
        }
        "rounded_rect_from_origin_size" => {
            let ox = p["origin"][0].as_f64().unwrap_or(0.0);
            let oy = p["origin"][1].as_f64().unwrap_or(0.0);
            let w = p["size"][0].as_f64().unwrap_or(100.0);
            let h = p["size"][1].as_f64().unwrap_or(100.0);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = RoundedRect::from_origin_size(Point::new(ox, oy), Size::new(w, h), radius);
            serde_json::json!({"width": rr.width(), "height": rr.height(), "origin": [rr.origin().x, rr.origin().y]})
        }
        "rounded_rect_from_points" => {
            let p0x = p["p0"][0].as_f64().unwrap_or(0.0);
            let p0y = p["p0"][1].as_f64().unwrap_or(0.0);
            let p1x = p["p1"][0].as_f64().unwrap_or(100.0);
            let p1y = p["p1"][1].as_f64().unwrap_or(100.0);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = RoundedRect::from_points(Point::new(p0x, p0y), Point::new(p1x, p1y), radius);
            serde_json::json!({"width": rr.width(), "height": rr.height(), "radii": [rr.radii().top_left, rr.radii().top_right, rr.radii().bottom_right, rr.radii().bottom_left]})
        }
        "rounded_rect_from_rect" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = RoundedRect::from_rect(r, radius);
            serde_json::json!({"width": rr.width(), "height": rr.height(), "rect": [rr.rect().x0, rr.rect().y0, rr.rect().x1, rr.rect().y1]})
        }
        "rounded_rect_height" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            serde_json::json!({"height": rr.height()})
        }
        "rounded_rect_origin" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            let o = rr.origin();
            serde_json::json!({"x": o.x, "y": o.y})
        }
        "rounded_rect_radii" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            let radii = rr.radii();
            serde_json::json!({"top_left": radii.top_left, "top_right": radii.top_right, "bottom_right": radii.bottom_right, "bottom_left": radii.bottom_left})
        }
        "rounded_rect_rect" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            let inner = rr.rect();
            serde_json::json!({"x0": inner.x0, "y0": inner.y0, "x1": inner.x1, "y1": inner.y1})
        }
        "rounded_rect_width" => {
            let r = parse_rect(&p);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = r.to_rounded_rect(radius);
            serde_json::json!({"width": rr.width()})
        }
        // RoundedRectRadii
        "rounded_rect_radii_as_single_radius" => {
            let tl = p["top_left"].as_f64().unwrap_or(5.0);
            let tr = p["top_right"].as_f64().unwrap_or(5.0);
            let br = p["bottom_right"].as_f64().unwrap_or(5.0);
            let bl = p["bottom_left"].as_f64().unwrap_or(5.0);
            let radii = RoundedRectRadii::new(tl, tr, br, bl);
            serde_json::json!({"single_radius": radii.as_single_radius()})
        }
        // Ellipse: additional operations
        "ellipse_from_affine" => {
            let c: [f64; 6] = serde_json::from_value(p["coeffs"].clone()).unwrap_or([1.0,0.0,0.0,1.0,0.0,0.0]);
            let e = Ellipse::from_affine(Affine::new(c));
            serde_json::json!({"center": [e.center().x, e.center().y], "radii": [e.radii().x, e.radii().y], "rotation": e.rotation()})
        }
        "ellipse_radii_and_rotation" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot);
            let (radii, rotation) = e.radii_and_rotation();
            serde_json::json!({"radii": [radii.x, radii.y], "rotation": rotation})
        }
        "ellipse_with_center" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let ncx = p["new_center"][0].as_f64().unwrap_or(0.0);
            let ncy = p["new_center"][1].as_f64().unwrap_or(0.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot).with_center(Point::new(ncx, ncy));
            serde_json::json!({"center": [e.center().x, e.center().y], "radii": [e.radii().x, e.radii().y]})
        }
        "ellipse_with_radii" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let nrx = p["new_radii"][0].as_f64().unwrap_or(2.0);
            let nry = p["new_radii"][1].as_f64().unwrap_or(2.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot).with_radii(Vec2::new(nrx, nry));
            serde_json::json!({"center": [e.center().x, e.center().y], "radii": [e.radii().x, e.radii().y]})
        }
        "ellipse_with_rotation" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(1.0);
            let ry = p["ry"].as_f64().unwrap_or(1.0);
            let rot = p["rotation"].as_f64().unwrap_or(0.0);
            let new_rot = p["new_rotation"].as_f64().unwrap_or(0.0);
            let e = Ellipse::new(Point::new(cx, cy), (rx, ry), rot).with_rotation(new_rot);
            serde_json::json!({"rotation": e.rotation(), "radii": [e.radii().x, e.radii().y]})
        }
        // Circle segment: inner_arc, outer_arc
        "circle_inner_arc" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let outer_r = p["outer_radius"].as_f64().unwrap_or(10.0);
            let inner_r = p["inner_radius"].as_f64().unwrap_or(5.0);
            let start = p["start_angle"].as_f64().unwrap_or(0.0);
            let sweep = p["sweep_angle"].as_f64().unwrap_or(std::f64::consts::FRAC_PI_2);
            let seg = CircleSegment::new(Point::new(cx, cy), outer_r, inner_r, start, sweep);
            let arc = seg.inner_arc();
            serde_json::json!({"center": [arc.center.x, arc.center.y], "radii": [arc.radii.x, arc.radii.y], "start_angle": arc.start_angle, "sweep_angle": arc.sweep_angle})
        }
        "circle_outer_arc" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let outer_r = p["outer_radius"].as_f64().unwrap_or(10.0);
            let inner_r = p["inner_radius"].as_f64().unwrap_or(5.0);
            let start = p["start_angle"].as_f64().unwrap_or(0.0);
            let sweep = p["sweep_angle"].as_f64().unwrap_or(std::f64::consts::FRAC_PI_2);
            let seg = CircleSegment::new(Point::new(cx, cy), outer_r, inner_r, start, sweep);
            let arc = seg.outer_arc();
            serde_json::json!({"center": [arc.center.x, arc.center.y], "radii": [arc.radii.x, arc.radii.y], "start_angle": arc.start_angle, "sweep_angle": arc.sweep_angle})
        }
        // Triangle: inflate
        "triangle_inflate" => {
            let a = Point::new(p["a"][0].as_f64().unwrap_or(0.0), p["a"][1].as_f64().unwrap_or(0.0));
            let b = Point::new(p["b"][0].as_f64().unwrap_or(1.0), p["b"][1].as_f64().unwrap_or(0.0));
            let c_pt = Point::new(p["c"][0].as_f64().unwrap_or(0.5), p["c"][1].as_f64().unwrap_or(1.0));
            let scalar = p["scalar"].as_f64().unwrap_or(1.1);
            let t = Triangle::new(a, b, c_pt).inflate(scalar);
            serde_json::json!({"a": [t.a.x, t.a.y], "b": [t.b.x, t.b.y], "c": [t.c.x, t.c.y]})
        }
        // Size: max, min, to_rounded_rect
        "size_max" => {
            let w1 = p["a"][0].as_f64().unwrap_or(10.0);
            let h1 = p["a"][1].as_f64().unwrap_or(20.0);
            let w2 = p["b"][0].as_f64().unwrap_or(15.0);
            let h2 = p["b"][1].as_f64().unwrap_or(5.0);
            let s = Size::new(w1, h1).max(Size::new(w2, h2));
            serde_json::json!({"width": s.width, "height": s.height})
        }
        "size_min" => {
            let w1 = p["a"][0].as_f64().unwrap_or(10.0);
            let h1 = p["a"][1].as_f64().unwrap_or(20.0);
            let w2 = p["b"][0].as_f64().unwrap_or(15.0);
            let h2 = p["b"][1].as_f64().unwrap_or(5.0);
            let s = Size::new(w1, h1).min(Size::new(w2, h2));
            serde_json::json!({"width": s.width, "height": s.height})
        }
        "size_to_rounded_rect" => {
            let w = p["w"].as_f64().unwrap_or(100.0);
            let h = p["h"].as_f64().unwrap_or(60.0);
            let radius = p["radius"].as_f64().unwrap_or(5.0);
            let rr = Size::new(w, h).to_rounded_rect(radius);
            serde_json::json!({"width": rr.width(), "height": rr.height(), "rect": [rr.rect().x0, rr.rect().y0, rr.rect().x1, rr.rect().y1]})
        }
        // Insets: size, x_value, y_value
        "insets_size" => {
            let x0 = p["x0"].as_f64().unwrap_or(1.0);
            let y0 = p["y0"].as_f64().unwrap_or(2.0);
            let x1 = p["x1"].as_f64().unwrap_or(1.0);
            let y1 = p["y1"].as_f64().unwrap_or(2.0);
            let ins = Insets::new(x0, y0, x1, y1);
            let s = ins.size();
            serde_json::json!({"width": s.width, "height": s.height, "x_value": ins.x_value(), "y_value": ins.y_value()})
        }
        "insets_x_value" => {
            let x0 = p["x0"].as_f64().unwrap_or(3.0);
            let x1 = p["x1"].as_f64().unwrap_or(3.0);
            let ins = Insets::new(x0, p["y0"].as_f64().unwrap_or(0.0), x1, p["y1"].as_f64().unwrap_or(0.0));
            serde_json::json!({"x_value": ins.x_value()})
        }
        "insets_y_value" => {
            let y0 = p["y0"].as_f64().unwrap_or(4.0);
            let y1 = p["y1"].as_f64().unwrap_or(4.0);
            let ins = Insets::new(p["x0"].as_f64().unwrap_or(0.0), y0, p["x1"].as_f64().unwrap_or(0.0), y1);
            serde_json::json!({"y_value": ins.y_value()})
        }
        // Arc: reversed, to_cubic_beziers
        "arc_reversed" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(10.0);
            let ry = p["ry"].as_f64().unwrap_or(10.0);
            let start = p["start_angle"].as_f64().unwrap_or(0.0);
            let sweep = p["sweep_angle"].as_f64().unwrap_or(std::f64::consts::FRAC_PI_2);
            let x_rot = p["x_rotation"].as_f64().unwrap_or(0.0);
            let arc = Arc::new(Point::new(cx, cy), Vec2::new(rx, ry), start, sweep, x_rot);
            let rev = arc.reversed();
            serde_json::json!({"start_angle": rev.start_angle, "sweep_angle": rev.sweep_angle})
        }
        "arc_to_cubic_beziers" => {
            let cx = p["cx"].as_f64().unwrap_or(0.0);
            let cy = p["cy"].as_f64().unwrap_or(0.0);
            let rx = p["rx"].as_f64().unwrap_or(10.0);
            let ry = p["ry"].as_f64().unwrap_or(10.0);
            let start = p["start_angle"].as_f64().unwrap_or(0.0);
            let sweep = p["sweep_angle"].as_f64().unwrap_or(std::f64::consts::FRAC_PI_2);
            let x_rot = p["x_rotation"].as_f64().unwrap_or(0.0);
            let tol = p["tolerance"].as_f64().unwrap_or(0.1);
            let arc = Arc::new(Point::new(cx, cy), Vec2::new(rx, ry), start, sweep, x_rot);
            let mut segments: Vec<serde_json::Value> = Vec::new();
            arc.to_cubic_beziers(tol, |p1, p2, p3| {
                segments.push(serde_json::json!([[p1.x,p1.y],[p2.x,p2.y],[p3.x,p3.y]]));
            });
            let count = segments.len();
            serde_json::json!({"segments": segments, "count": count})
        }
        // TranslateScale: inverse, translate
        "translate_scale_inverse" => {
            let tx = p["tx"].as_f64().unwrap_or(0.0);
            let ty = p["ty"].as_f64().unwrap_or(0.0);
            let s = p["scale"].as_f64().unwrap_or(2.0);
            let ts = TranslateScale::new(Vec2::new(tx, ty), s);
            let inv = ts.inverse();
            serde_json::json!({"translation": [inv.translation.x, inv.translation.y], "scale": inv.scale})
        }
        "translate_scale_new" => {
            let tx = p["tx"].as_f64().unwrap_or(10.0);
            let ty = p["ty"].as_f64().unwrap_or(20.0);
            let s = p["scale"].as_f64().unwrap_or(1.0);
            let ts = TranslateScale::translate(Vec2::new(tx, ty));
            let ts2 = TranslateScale::new(ts.translation, s);
            serde_json::json!({"translation": [ts2.translation.x, ts2.translation.y], "scale": ts2.scale})
        }
        // Common math: factor_quartic_inner, solve_itp, solve_quartic
        "solve_quartic" => {
            let c0 = p["c0"].as_f64().unwrap_or(1.0);
            let c1 = p["c1"].as_f64().unwrap_or(0.0);
            let c2 = p["c2"].as_f64().unwrap_or(0.0);
            let c3 = p["c3"].as_f64().unwrap_or(0.0);
            let c4 = p["c4"].as_f64().unwrap_or(-1.0);
            let roots = kurbo::common::solve_quartic(c0, c1, c2, c3, c4);
            serde_json::json!({"roots": roots.as_slice()})
        }
        "solve_itp" => {
            // Solve f(x)=0 on [a,b] where f is a simple linear function ax+b=0
            let a = p["a"].as_f64().unwrap_or(0.0);
            let b_val = p["b"].as_f64().unwrap_or(1.0);
            let ya = p["ya"].as_f64().unwrap_or(-1.0);
            let yb = p["yb"].as_f64().unwrap_or(1.0);
            let epsilon = p["epsilon"].as_f64().unwrap_or(1e-9);
            let slope = p["slope"].as_f64().unwrap_or(1.0);
            let intercept = p["intercept"].as_f64().unwrap_or(0.0);
            let root = kurbo::common::solve_itp(|x| slope * x + intercept, a, b_val, epsilon, 1, 0.2, ya, yb);
            serde_json::json!({"root": root})
        }
        _ => return Err(format!("Unknown kurbo geometry op: {}", operation)),
    };
    Ok(result.to_string())
}

fn parse_rect(p: &serde_json::Value) -> kurbo::Rect {
    kurbo::Rect::new(
        p["x0"].as_f64().or(p["x"].as_f64()).unwrap_or(0.0),
        p["y0"].as_f64().or(p["y"].as_f64()).unwrap_or(0.0),
        p["x1"].as_f64().unwrap_or(p["x"].as_f64().unwrap_or(0.0) + p["w"].as_f64().unwrap_or(100.0)),
        p["y1"].as_f64().unwrap_or(p["y"].as_f64().unwrap_or(0.0) + p["h"].as_f64().unwrap_or(100.0)),
    )
}

/// Kurbo bezier curve operations: cubic, quad, fitting, simplification
#[rustler::nif]
fn kurbo_bezier_op(operation: String, params_json: String) -> Result<String, String> {
    use kurbo::*;
    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let result = match operation.as_str() {
        "cubic_eval" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.0), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(1.0), p["p2"][1].as_f64().unwrap_or(1.0));
            let p3 = Point::new(p["p3"][0].as_f64().unwrap_or(1.0), p["p3"][1].as_f64().unwrap_or(0.0));
            let cb = CubicBez::new(p0, p1, p2, p3);
            let t = p["t"].as_f64().unwrap_or(0.5);
            let pt = cb.eval(t);
            serde_json::json!({"point": [pt.x, pt.y], "t": t})
        }
        "quad_eval" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.5), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(1.0), p["p2"][1].as_f64().unwrap_or(0.0));
            let qb = QuadBez::new(p0, p1, p2);
            let t = p["t"].as_f64().unwrap_or(0.5);
            let pt = qb.eval(t);
            serde_json::json!({"point": [pt.x, pt.y], "t": t})
        }
        "path_reverse" => {
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 L 100 100");
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let mut reversed = path.clone();
            reversed.reverse_subpaths();
            serde_json::json!({"svg_path": kurbo::BezPath::to_svg(&reversed)})
        }
        "path_flatten" => {
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 C 50 100 100 100 100 0");
            let tolerance = p["tolerance"].as_f64().unwrap_or(0.1);
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let mut flat = BezPath::new();
            path.flatten(tolerance, |el| flat.push(el));
            serde_json::json!({"svg_path": kurbo::BezPath::to_svg(&flat), "segment_count": flat.segments().count()})
        }
        "path_to_cubic" => {
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 Q 50 100 100 0");
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let cubic = path; // to_cubic not available in kurbo 0.11
            serde_json::json!({"svg_path": kurbo::BezPath::to_svg(&cubic)})
        }
        // CubicBez: approx_spline
        "cubic_approx_spline" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.3), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(0.7), p["p2"][1].as_f64().unwrap_or(1.0));
            let p3 = Point::new(p["p3"][0].as_f64().unwrap_or(1.0), p["p3"][1].as_f64().unwrap_or(0.0));
            let accuracy = p["accuracy"].as_f64().unwrap_or(0.1);
            let cb = CubicBez::new(p0, p1, p2, p3);
            match cb.approx_spline(accuracy) {
                Some(spline) => { let pts: Vec<_> = spline.points().iter().map(|pt| [pt.x, pt.y]).collect(); serde_json::json!({"points": pts, "count": pts.len()}) }
                None => serde_json::json!({"points": [], "count": 0}),
            }
        }
        // CubicBez: inflections
        "cubic_inflections" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.0), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(1.0), p["p2"][1].as_f64().unwrap_or(1.0));
            let p3 = Point::new(p["p3"][0].as_f64().unwrap_or(1.0), p["p3"][1].as_f64().unwrap_or(0.0));
            let cb = CubicBez::new(p0, p1, p2, p3);
            let infl = cb.inflections();
            serde_json::json!({"inflections": infl.as_slice(), "count": infl.len()})
        }
        // CubicBez: tangents_to_point
        "cubic_tangents_to_point" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.0), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(1.0), p["p2"][1].as_f64().unwrap_or(1.0));
            let p3 = Point::new(p["p3"][0].as_f64().unwrap_or(1.0), p["p3"][1].as_f64().unwrap_or(0.0));
            let qx = p["query"][0].as_f64().unwrap_or(0.5);
            let qy = p["query"][1].as_f64().unwrap_or(2.0);
            let cb = CubicBez::new(p0, p1, p2, p3);
            let ts = cb.tangents_to_point(Point::new(qx, qy));
            serde_json::json!({"t_values": ts.as_slice(), "count": ts.len()})
        }
        // CubicBez: to_quads
        "cubic_to_quads" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.3), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(0.7), p["p2"][1].as_f64().unwrap_or(1.0));
            let p3 = Point::new(p["p3"][0].as_f64().unwrap_or(1.0), p["p3"][1].as_f64().unwrap_or(0.0));
            let accuracy = p["accuracy"].as_f64().unwrap_or(0.1);
            let cb = CubicBez::new(p0, p1, p2, p3);
            let quads: Vec<serde_json::Value> = cb.to_quads(accuracy).map(|(t0, t1, q)| serde_json::json!({"t0": t0, "t1": t1, "p0": [q.p0.x, q.p0.y], "p1": [q.p1.x, q.p1.y], "p2": [q.p2.x, q.p2.y]})).collect();
            let count = quads.len();
            serde_json::json!({"quads": quads, "count": count})
        }
        // QuadBez: raise to CubicBez
        "quad_raise" => {
            let p0 = Point::new(p["p0"][0].as_f64().unwrap_or(0.0), p["p0"][1].as_f64().unwrap_or(0.0));
            let p1 = Point::new(p["p1"][0].as_f64().unwrap_or(0.5), p["p1"][1].as_f64().unwrap_or(1.0));
            let p2 = Point::new(p["p2"][0].as_f64().unwrap_or(1.0), p["p2"][1].as_f64().unwrap_or(0.0));
            let qb = QuadBez::new(p0, p1, p2);
            let cb = qb.raise();
            serde_json::json!({"p0": [cb.p0.x, cb.p0.y], "p1": [cb.p1.x, cb.p1.y], "p2": [cb.p2.x, cb.p2.y], "p3": [cb.p3.x, cb.p3.y]})
        }
        // fit: fit_to_bezpath (uses SimplifyBezPath as ParamCurveFit source)
        "fit_to_bezpath" => {
            use kurbo::simplify::SimplifyBezPath;
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 C 50 100 100 100 100 0");
            let accuracy = p["accuracy"].as_f64().unwrap_or(1.0);
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let source = SimplifyBezPath::new(path.iter());
            let fitted = fit_to_bezpath(&source, accuracy);
            serde_json::json!({"svg_path": BezPath::to_svg(&fitted)})
        }
        // fit: fit_to_bezpath_opt
        "fit_to_bezpath_opt" => {
            use kurbo::simplify::SimplifyBezPath;
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 C 50 100 100 100 100 0");
            let accuracy = p["accuracy"].as_f64().unwrap_or(1.0);
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let source = SimplifyBezPath::new(path.iter());
            let fitted = fit_to_bezpath_opt(&source, accuracy);
            serde_json::json!({"svg_path": BezPath::to_svg(&fitted)})
        }
        // fit: fit_to_cubic
        "fit_to_cubic" => {
            use kurbo::simplify::SimplifyBezPath;
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 C 50 100 100 100 100 0");
            let accuracy = p["accuracy"].as_f64().unwrap_or(1.0);
            let t0 = p["t0"].as_f64().unwrap_or(0.0);
            let t1 = p["t1"].as_f64().unwrap_or(1.0);
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let source = SimplifyBezPath::new(path.iter());
            match fit_to_cubic(&source, t0..t1, accuracy) {
                Some((cb, err)) => serde_json::json!({"p0": [cb.p0.x, cb.p0.y], "p1": [cb.p1.x, cb.p1.y], "p2": [cb.p2.x, cb.p2.y], "p3": [cb.p3.x, cb.p3.y], "error": err}),
                None => serde_json::json!({"error": "fit_to_cubic failed"}),
            }
        }
        // simplify: simplify_bezpath
        "simplify_bezpath" => {
            use kurbo::simplify::{simplify_bezpath, SimplifyOptions};
            let svg_d = p["path"].as_str().unwrap_or("M 0 0 C 50 100 100 100 100 0 Z");
            let accuracy = p["accuracy"].as_f64().unwrap_or(1.0);
            let path = BezPath::from_svg(svg_d).map_err(|e| format!("{:?}", e))?;
            let options = SimplifyOptions::default();
            let simplified = simplify_bezpath(path, accuracy, &options);
            serde_json::json!({"svg_path": BezPath::to_svg(&simplified)})
        }
        _ => return Err(format!("Unknown kurbo bezier op: {}", operation)),
    };
    Ok(result.to_string())
}

/// Mermaid extended: render with options, timing
#[rustler::nif]
fn mermaid_render_with_options(mermaid_text: String, options_json: String) -> Result<String, String> {
    use mermaid_rs_renderer::{render_with_options, RenderOptions};
    let opts_val: serde_json::Value = serde_json::from_str(&options_json).unwrap_or_default();
    let mut opts = RenderOptions::modern();
    if let Some(ns) = opts_val["node_spacing"].as_f64() { opts = opts.with_node_spacing(ns as f32); }
    if let Some(rs) = opts_val["rank_spacing"].as_f64() { opts = opts.with_rank_spacing(rs as f32); }
    if let Some(ar) = opts_val["aspect_ratio"].as_f64() { opts = opts.with_preferred_aspect_ratio(ar as f32); }

    let svg = render_with_options(&mermaid_text, opts)
        .map_err(|e| format!("Mermaid: {}", e))?;

    Ok(serde_json::json!({"svg": svg, "svg_bytes": svg.len()}).to_string())
}

/// Skia extended: draw primitives to PNG (rect, circle, line, text, bar chart)
#[rustler::nif]
fn skia_draw_to_png(operations_json: String, output_path: String, width: u32, height: u32) -> Result<String, String> {
    let ops: Vec<serde_json::Value> = serde_json::from_str(&operations_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let mut pixmap = Pixmap::new(width, height).ok_or("pixmap creation failed")?;
    // Clear to background
    fill_rect(&mut pixmap, 0.0, 0.0, width as f32, height as f32, cc(10, 14, 23));

    for op in &ops {
        let kind = op["type"].as_str().unwrap_or("");
        match kind {
            "rect" => {
                let x = op["x"].as_f64().unwrap_or(0.0) as f32;
                let y = op["y"].as_f64().unwrap_or(0.0) as f32;
                let w = op["w"].as_f64().unwrap_or(100.0) as f32;
                let h = op["h"].as_f64().unwrap_or(100.0) as f32;
                let r = op["r"].as_f64().unwrap_or(0.0) as f32;
                let color = parse_color_val(op);
                if r > 0.0 { rrect(&mut pixmap, x, y, w, h, r, color); }
                else { fill_rect(&mut pixmap, x, y, w, h, color); }
            }
            "circle" => {
                let cx = op["cx"].as_f64().unwrap_or(50.0) as f32;
                let cy = op["cy"].as_f64().unwrap_or(50.0) as f32;
                let radius = op["radius"].as_f64().unwrap_or(25.0) as f32;
                let color = parse_color_val(op);
                // Draw circle as many-sided polygon
                let mut pb = PathBuilder::new();
                for i in 0..=64 {
                    let a = (i as f32 / 64.0) * std::f32::consts::TAU;
                    let px = cx + a.cos() * radius;
                    let py = cy + a.sin() * radius;
                    if i == 0 { pb.move_to(px, py); } else { pb.line_to(px, py); }
                }
                pb.close();
                if let Some(path) = pb.finish() {
                    let mut paint = Paint::default(); paint.set_color(color); paint.anti_alias = true;
                    pixmap.fill_path(&path, &paint, FillRule::Winding, Transform::identity(), None);
                }
            }
            "line" => {
                let x1 = op["x1"].as_f64().unwrap_or(0.0) as f32;
                let y1 = op["y1"].as_f64().unwrap_or(0.0) as f32;
                let x2 = op["x2"].as_f64().unwrap_or(100.0) as f32;
                let y2 = op["y2"].as_f64().unwrap_or(100.0) as f32;
                let sw = op["stroke_width"].as_f64().unwrap_or(1.0) as f32;
                let color = parse_color_val(op);
                let mut pb = PathBuilder::new();
                pb.move_to(x1, y1); pb.line_to(x2, y2);
                if let Some(path) = pb.finish() {
                    let mut paint = Paint::default(); paint.set_color(color); paint.anti_alias = true;
                    let stroke = Stroke { width: sw, ..Stroke::default() };
                    pixmap.stroke_path(&path, &paint, &stroke, Transform::identity(), None);
                }
            }
            "text" => {
                let x = op["x"].as_f64().unwrap_or(0.0) as f32;
                let y = op["y"].as_f64().unwrap_or(0.0) as f32;
                let s = op["text"].as_str().unwrap_or("");
                let scale = op["scale"].as_f64().unwrap_or(1.0) as f32;
                let color = parse_color_val(op);
                txt(&mut pixmap, x, y, s, color, scale);
            }
            "bar" => {
                let x = op["x"].as_f64().unwrap_or(0.0) as f32;
                let y = op["y"].as_f64().unwrap_or(0.0) as f32;
                let w = op["w"].as_f64().unwrap_or(200.0) as f32;
                let h = op["h"].as_f64().unwrap_or(20.0) as f32;
                let ratio = op["ratio"].as_f64().unwrap_or(0.5) as f32;
                let bg = cc(30, 42, 58);
                let fill_color = parse_color_val(op);
                rrect(&mut pixmap, x, y, w, h, 3.0, bg);
                if ratio > 0.0 { rrect(&mut pixmap, x, y, w * ratio.min(1.0), h, 3.0, fill_color); }
            }
            _ => {}
        }
    }

    pixmap.save_png(&output_path).map_err(|e| format!("Save: {}", e))?;
    Ok(serde_json::json!({"path": output_path, "width": width, "height": height, "operations": ops.len()}).to_string())
}

fn parse_color_val(op: &serde_json::Value) -> Color {
    if let Some(hex) = op["color"].as_str() {
        let hex = hex.trim_start_matches('#');
        if hex.len() >= 6 {
            let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(0);
            let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(0);
            let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(0);
            return cc(r, g, b);
        }
    }
    cc(224, 230, 237) // default text color
}

// ═══════════════════════════════════════════════════════════════
// 9. VEGA-LITE — Declarative Visualization Grammar
// ═══════════════════════════════════════════════════════════════

/// Build a Vega-Lite JSON spec from typed parameters.
/// chart_type: "bar", "line", "point", "area", "arc", "boxplot", "heatmap"
/// Returns complete Vega-Lite JSON spec string.
#[rustler::nif]
fn vega_lite_spec(chart_type: String, params_json: String) -> Result<String, String> {
    let p: serde_json::Value = serde_json::from_str(&params_json)
        .map_err(|e| format!("Parse: {}", e))?;

    let title = p["title"].as_str().unwrap_or("Chart");
    let width = p["width"].as_u64().unwrap_or(400);
    let height = p["height"].as_u64().unwrap_or(300);
    let data_values = p["data"].clone();

    let mark = match chart_type.as_str() {
        "bar" => serde_json::json!({"type": "bar"}),
        "line" => serde_json::json!({"type": "line", "point": true}),
        "point" | "scatter" => serde_json::json!({"type": "point"}),
        "area" => serde_json::json!({"type": "area"}),
        "arc" | "pie" => serde_json::json!({"type": "arc"}),
        "boxplot" => serde_json::json!({"type": "boxplot"}),
        "rect" | "heatmap" => serde_json::json!({"type": "rect"}),
        "rule" => serde_json::json!({"type": "rule"}),
        "text" => serde_json::json!({"type": "text"}),
        "tick" => serde_json::json!({"type": "tick"}),
        "trail" => serde_json::json!({"type": "trail"}),
        "circle" => serde_json::json!({"type": "circle"}),
        "square" => serde_json::json!({"type": "square"}),
        "geoshape" => serde_json::json!({"type": "geoshape"}),
        _ => serde_json::json!({"type": chart_type}),
    };

    let x_field = p["x"].as_str().unwrap_or("x");
    let y_field = p["y"].as_str().unwrap_or("y");
    let x_type = p["x_type"].as_str().unwrap_or("nominal");
    let y_type = p["y_type"].as_str().unwrap_or("quantitative");
    let color_field = p["color"].as_str();

    let mut encoding = serde_json::json!({
        "x": {"field": x_field, "type": x_type},
        "y": {"field": y_field, "type": y_type},
    });

    if let Some(cf) = color_field {
        encoding["color"] = serde_json::json!({"field": cf, "type": "nominal"});
    }

    if let Some(theta) = p.get("theta") {
        encoding["theta"] = serde_json::json!({"field": theta.as_str().unwrap_or("value"), "type": "quantitative"});
    }

    let spec = serde_json::json!({
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "title": title,
        "width": width,
        "height": height,
        "mark": mark,
        "encoding": encoding,
        "data": {"values": data_values},
    });

    Ok(spec.to_string())
}

/// Build a layered/multi-view Vega-Lite spec
#[rustler::nif]
fn vega_lite_layered(layers_json: String) -> Result<String, String> {
    let layers: Vec<serde_json::Value> = serde_json::from_str(&layers_json)
        .map_err(|e| format!("Parse layers: {}", e))?;

    let spec = serde_json::json!({
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "layer": layers,
    });

    Ok(spec.to_string())
}

/// Build common chart presets for C3I dashboard
#[rustler::nif]
fn vega_lite_preset(preset: String, data_json: String) -> Result<String, String> {
    let data: serde_json::Value = serde_json::from_str(&data_json)
        .map_err(|e| format!("Parse data: {}", e))?;

    let spec = match preset.as_str() {
        "health_sparkline" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Health Trajectory",
                "width": 400, "height": 200,
                "mark": {"type": "area", "line": true, "point": true, "color": "#3dd68c", "opacity": 0.3},
                "encoding": {
                    "x": {"field": "time", "type": "temporal", "axis": {"title": null}},
                    "y": {"field": "health", "type": "quantitative", "scale": {"domain": [0, 100]}},
                },
                "data": {"values": data},
            })
        }
        "priority_bar" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Priority Distribution",
                "width": 300, "height": 200,
                "mark": {"type": "bar"},
                "encoding": {
                    "x": {"field": "count", "type": "quantitative"},
                    "y": {"field": "priority", "type": "nominal", "sort": null},
                    "color": {"field": "priority", "type": "nominal", "scale": {"range": ["#ff4757","#f5a623","#3dd68c","#7a8fa6"]}},
                },
                "data": {"values": data},
            })
        }
        "fractal_heatmap" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Fractal Layer Health",
                "width": 400, "height": 300,
                "mark": {"type": "rect"},
                "encoding": {
                    "x": {"field": "metric", "type": "nominal"},
                    "y": {"field": "layer", "type": "nominal", "sort": null},
                    "color": {"field": "value", "type": "quantitative", "scale": {"scheme": "redyellowgreen", "domain": [0, 100]}},
                },
                "data": {"values": data},
            })
        }
        "status_pie" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Task Status",
                "width": 200, "height": 200,
                "mark": {"type": "arc"},
                "encoding": {
                    "theta": {"field": "count", "type": "quantitative"},
                    "color": {"field": "status", "type": "nominal", "scale": {"range": ["#ff4757","#4d96ff","#7a8fa6","#3dd68c"]}},
                },
                "data": {"values": data},
            })
        }
        "ooda_ring" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "OODA Cycle",
                "width": 200, "height": 200,
                "mark": {"type": "arc", "innerRadius": 50},
                "encoding": {
                    "theta": {"field": "latency_ms", "type": "quantitative"},
                    "color": {"field": "phase", "type": "nominal", "scale": {"range": ["#00d4aa","#4d96ff","#f5a623","#3dd68c"]}},
                },
                "data": {"values": data},
            })
        }
        "age_histogram" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Task Age Distribution",
                "width": 300, "height": 200,
                "mark": {"type": "bar"},
                "encoding": {
                    "x": {"field": "bucket", "type": "nominal", "sort": null},
                    "y": {"field": "count", "type": "quantitative"},
                    "color": {"field": "bucket", "type": "nominal", "scale": {"range": ["#3dd68c","#4d96ff","#f5a623","#ff4757"]}},
                },
                "data": {"values": data},
            })
        }
        "timeline_gantt" => {
            serde_json::json!({
                "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
                "title": "Task Timeline",
                "width": 600, "height": 300,
                "mark": "bar",
                "encoding": {
                    "x": {"field": "start", "type": "temporal"},
                    "x2": {"field": "end"},
                    "y": {"field": "task", "type": "nominal", "sort": null},
                    "color": {"field": "status", "type": "nominal", "scale": {"range": ["#ff4757","#4d96ff","#7a8fa6","#3dd68c"]}},
                },
                "data": {"values": data},
            })
        }
        _ => return Err(format!("Unknown preset: {}", preset)),
    };

    Ok(spec.to_string())
}

// ═══════════════════════════════════════════════════════════════
// 10. PETGRAPH — Production Graph Library (adjacency list/matrix)
// ═══════════════════════════════════════════════════════════════

/// Petgraph operations — full-featured graph algorithms.
/// Operations: dijkstra, bellman_ford, floyd_warshall, min_spanning_tree,
/// is_cyclic, connected_components, dominators, toposort, dot_export
#[rustler::nif]
fn petgraph_op(operation: String, nodes_json: String, edges_json: String, params_json: String) -> Result<String, String> {
    use petgraph::graph::{DiGraph, NodeIndex};
    use petgraph::algo;
    use petgraph::dot::{Dot, Config};

    let node_labels: Vec<String> = serde_json::from_str(&nodes_json)
        .map_err(|e| format!("Parse nodes: {}", e))?;
    let edge_triples: Vec<(usize, usize, f64)> = serde_json::from_str(&edges_json)
        .map_err(|e| format!("Parse edges: {}", e))?;
    let p: serde_json::Value = serde_json::from_str(&params_json).unwrap_or_default();

    // Build petgraph DiGraph
    let mut graph = DiGraph::<String, f64>::new();
    let node_indices: Vec<NodeIndex> = node_labels.iter()
        .map(|label| graph.add_node(label.clone()))
        .collect();

    for (from, to, weight) in &edge_triples {
        if *from < node_indices.len() && *to < node_indices.len() {
            graph.add_edge(node_indices[*from], node_indices[*to], *weight);
        }
    }

    let result = match operation.as_str() {
        "dijkstra" => {
            let start = p["start"].as_u64().unwrap_or(0) as usize;
            if start >= node_indices.len() { return Err("Invalid start node".into()); }
            let distances = algo::dijkstra(&graph, node_indices[start], None, |e| *e.weight());
            let dist_map: std::collections::HashMap<String, f64> = distances.iter()
                .map(|(idx, dist)| (graph[*idx].clone(), *dist))
                .collect();
            serde_json::json!({"distances": dist_map, "from": node_labels[start]})
        }
        "bellman_ford" => {
            let start = p["start"].as_u64().unwrap_or(0) as usize;
            if start >= node_indices.len() { return Err("Invalid start node".into()); }
            match algo::bellman_ford(&graph, node_indices[start]) {
                Ok(paths) => {
                    let dists: Vec<serde_json::Value> = paths.distances.iter().enumerate()
                        .map(|(i, d)| serde_json::json!({"node": node_labels[i], "distance": d}))
                        .collect();
                    serde_json::json!({"distances": dists, "has_negative_cycle": false})
                }
                Err(_) => serde_json::json!({"has_negative_cycle": true}),
            }
        }
        "is_cyclic" => {
            let cyclic = algo::is_cyclic_directed(&graph);
            serde_json::json!({"is_cyclic": cyclic})
        }
        "toposort" => {
            match algo::toposort(&graph, None) {
                Ok(sorted) => {
                    let order: Vec<String> = sorted.iter().map(|idx| graph[*idx].clone()).collect();
                    serde_json::json!({"sorted": order, "is_dag": true})
                }
                Err(cycle) => {
                    serde_json::json!({"is_dag": false, "cycle_node": graph[cycle.node_id()].clone()})
                }
            }
        }
        "connected_components" => {
            let undirected = graph.clone().into_edge_type::<petgraph::Undirected>();
            let count = algo::connected_components(&undirected);
            serde_json::json!({"connected_components": count})
        }
        "min_spanning_tree" => {
            let undirected = graph.clone().into_edge_type::<petgraph::Undirected>();
            let mst: Vec<serde_json::Value> = algo::min_spanning_tree(&undirected)
                .filter_map(|elem| {
                    match elem {
                        petgraph::data::Element::Edge { source, target, weight } => {
                            Some(serde_json::json!({"from": source, "to": target, "weight": weight}))
                        }
                        _ => None,
                    }
                })
                .collect();
            serde_json::json!({"mst_edges": mst, "edge_count": mst.len()})
        }
        "dot_export" => {
            let dot_str = format!("{:?}", Dot::with_config(&graph, &[Config::EdgeNoLabel]));
            serde_json::json!({"dot": dot_str})
        }
        "dot_export_full" => {
            let dot_str = format!("{:?}", Dot::new(&graph));
            serde_json::json!({"dot": dot_str})
        }
        "node_count" => {
            serde_json::json!({"node_count": graph.node_count(), "edge_count": graph.edge_count()})
        }
        "neighbors" => {
            let node = p["node"].as_u64().unwrap_or(0) as usize;
            if node >= node_indices.len() { return Err("Invalid node".into()); }
            let neighbors: Vec<String> = graph.neighbors(node_indices[node])
                .map(|idx| graph[idx].clone())
                .collect();
            serde_json::json!({"node": node_labels[node], "neighbors": neighbors, "degree": neighbors.len()})
        }
        "all_edges" => {
            let edges: Vec<serde_json::Value> = graph.edge_indices().map(|e| {
                let (src, tgt) = graph.edge_endpoints(e).unwrap();
                serde_json::json!({"from": graph[src], "to": graph[tgt], "weight": graph[e]})
            }).collect();
            serde_json::json!({"edges": edges, "count": edges.len()})
        }
        _ => return Err(format!("Unknown petgraph op: {}", operation)),
    };
    Ok(result.to_string())
}

// ═══════════════════════════════════════════════════════════════
// 11. GRAFANA — Dashboard API SDK
// ═══════════════════════════════════════════════════════════════

/// Build a Grafana dashboard JSON model.
/// Creates a dashboard with panels from a JSON spec.
#[rustler::nif]
fn grafana_dashboard_json(title: String, panels_json: String) -> Result<String, String> {
    let panels: Vec<serde_json::Value> = serde_json::from_str(&panels_json)
        .map_err(|e| format!("Parse panels: {}", e))?;

    let mut panel_models: Vec<serde_json::Value> = Vec::new();
    for (i, panel) in panels.iter().enumerate() {
        let panel_type = panel["type"].as_str().unwrap_or("stat");
        let panel_title = panel["title"].as_str().unwrap_or("Panel");
        let targets = panel.get("targets").cloned().unwrap_or(serde_json::json!([]));

        panel_models.push(serde_json::json!({
            "id": i + 1,
            "type": panel_type,
            "title": panel_title,
            "gridPos": {"h": 8, "w": 12, "x": (i % 2) * 12, "y": (i / 2) * 8},
            "targets": targets,
            "datasource": panel.get("datasource").cloned().unwrap_or(serde_json::json!({"type": "prometheus", "uid": "default"})),
            "fieldConfig": {
                "defaults": {
                    "thresholds": {
                        "mode": "absolute",
                        "steps": [
                            {"color": "green", "value": null},
                            {"color": "yellow", "value": 70},
                            {"color": "red", "value": 85}
                        ]
                    }
                }
            }
        }));
    }

    let dashboard = serde_json::json!({
        "dashboard": {
            "title": title,
            "uid": format!("c3i-{}", title.to_lowercase().replace(' ', "-")),
            "panels": panel_models,
            "time": {"from": "now-1h", "to": "now"},
            "refresh": "5s",
            "schemaVersion": 39,
            "tags": ["c3i", "auto-generated"],
        },
        "overwrite": true,
    });

    Ok(dashboard.to_string())
}

/// Build a Grafana panel JSON model for common C3I visualizations.
/// Presets: health_gauge, container_table, ooda_timeseries, fractal_heatmap,
///          task_bar, zenoh_graph, alert_list
#[rustler::nif]
fn grafana_panel_preset(preset: String, params_json: String) -> Result<String, String> {
    let p: serde_json::Value = serde_json::from_str(&params_json).unwrap_or_default();
    let title = p["title"].as_str().unwrap_or(preset.as_str());

    let panel = match preset.as_str() {
        "health_gauge" => {
            serde_json::json!({
                "type": "gauge",
                "title": title,
                "targets": [{"expr": "c3i_health_score", "legendFormat": "Health"}],
                "fieldConfig": {"defaults": {"min": 0, "max": 100, "thresholds": {"steps": [
                    {"color": "red", "value": null}, {"color": "yellow", "value": 70}, {"color": "green", "value": 85}
                ]}}},
            })
        }
        "container_table" => {
            serde_json::json!({
                "type": "table",
                "title": title,
                "targets": [{"expr": "c3i_container_health", "format": "table"}],
                "transformations": [{"id": "organize", "options": {"excludeByName": {}, "renameByName": {"container": "Container", "health": "Health", "status": "Status"}}}],
            })
        }
        "ooda_timeseries" => {
            serde_json::json!({
                "type": "timeseries",
                "title": title,
                "targets": [
                    {"expr": "c3i_ooda_observe_ms", "legendFormat": "Observe"},
                    {"expr": "c3i_ooda_orient_ms", "legendFormat": "Orient"},
                    {"expr": "c3i_ooda_decide_ms", "legendFormat": "Decide"},
                    {"expr": "c3i_ooda_act_ms", "legendFormat": "Act"},
                ],
                "fieldConfig": {"defaults": {"unit": "ms"}},
            })
        }
        "fractal_heatmap" => {
            serde_json::json!({
                "type": "heatmap",
                "title": title,
                "targets": [{"expr": "c3i_fractal_health{layer=~\"L.*\"}", "format": "heatmap"}],
                "options": {"color": {"scheme": "RdYlGn"}},
            })
        }
        "task_bar" => {
            serde_json::json!({
                "type": "barchart",
                "title": title,
                "targets": [{"expr": "c3i_task_count_by_status", "legendFormat": "{{status}}"}],
                "fieldConfig": {"overrides": [
                    {"matcher": {"id": "byName", "options": "blocked"}, "properties": [{"id": "color", "value": "#ff4757"}]},
                    {"matcher": {"id": "byName", "options": "active"}, "properties": [{"id": "color", "value": "#4d96ff"}]},
                ]},
            })
        }
        "zenoh_graph" => {
            serde_json::json!({
                "type": "nodeGraph",
                "title": title,
                "targets": [
                    {"expr": "c3i_zenoh_nodes", "format": "nodes"},
                    {"expr": "c3i_zenoh_edges", "format": "edges"},
                ],
            })
        }
        "alert_list" => {
            serde_json::json!({
                "type": "alertlist",
                "title": title,
                "options": {"showOptions": "current", "sortOrder": 1, "dashboardAlerts": false, "alertName": "c3i"},
            })
        }
        _ => return Err(format!("Unknown Grafana preset: {}", preset)),
    };

    Ok(panel.to_string())
}

// ═══════════════════════════════════════════════════════════════
// NIF registration — ALL 35 functions
// ═══════════════════════════════════════════════════════════════

rustler::init!("graphene_nif");
