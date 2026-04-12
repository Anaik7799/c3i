// Standalone binary for graphene state diagram rendering
// Calls the same render functions as the NIF
fn main() {
    // Re-export the render_all_diagrams logic without NIF wrapper
    let output_dir = std::env::args().nth(1).unwrap_or_else(|| "output".to_string());
    std::fs::create_dir_all(&output_dir).expect("mkdir failed");
    
    // Call the NIF's internal render function by linking to the library
    println!("Use the wireframe-renderer binary instead:");
    println!("  ./sub-projects/c3i/native/wireframe_renderer/target/release/render-wireframes {}", output_dir);
}
