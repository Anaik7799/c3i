namespace Cepaf.UI

open Cepaf.Bio
open Terminal.Gui

/// The Fractal Renderer
/// One function to render ANY part of the system.
module HolonRenderer =

    /// Creates a UI View for a Holon
    /// Recursively builds the interface based on Zoom/Depth
    let rec render (holon: Holon) (depth: int) : View =
        
        // 1. The Container Frame
        let frame = new FrameView(Text = holon.Name)
        
        // 2. Visual Encoding of Vital Signs
        // Color = Health (Green -> Red)
        let color = 
            if holon.Health > 0.8 then ColorScheme.Normal
            elif holon.Health > 0.5 then ColorScheme.Warning
            else ColorScheme.Error
        frame.ColorScheme <- color

        // 3. Smart Content Selection (Level of Detail)
        if depth > 2 then
            // High Detail: Show Sparklines, Metrics
            // Mock: Add label for now
            frame.Add(new Label(Text = sprintf "Health: %.2f | Stress: %.2f" holon.Health holon.Stress))
        else
            // Low Detail: Show Children (Fractal Step)
            // Only render top 3 most salient children to avoid clutter
            let topChildren = 
                holon.Children 
                |> List.sortByDescending (fun c -> c.Salience)
                |> List.truncate 3
            
            let mutable y = 0
            for child in topChildren do
                let childView = render child (depth + 1)
                childView.Y <- Pos.At(y)
                childView.Height <- Dim.Percent(30f)
                childView.Width <- Dim.Fill()
                frame.Add(childView)
                y <- y + 10 // Mock layout logic

        frame :> View
