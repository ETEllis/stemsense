# Logo generation notes

Mode: OpenAI built-in image generation, `logo-brand` workflow  
Selected direction: opposing stems + fixed scrub cursor

Four passes were evaluated:

1. Opposing directional stems forming an S around a media timeline.
2. Two-stem spatial sensing field with a central inference point.
3. Combined spatial field and S-flow.
4. Targeted refinement of pass one; selected as the raster master and then rebuilt as production SVG geometry.

## Selected refinement prompt

> Use case: logo-brand  
> Asset type: final StemSense iOS app icon and primary product mark  
> Input image: Image 1 is the edit target.  
> Primary request: Keep Image 1's exact core concept and recognizable geometry—two opposing chartreuse bent stems forming an S-flow around a horizontal media scrub datum—but refine it into a production-flat logo. Change only the visual finish and optical balance: remove every glow, gradient, blur, highlight, texture, and shadow; make all chartreuse elements exactly solid #DFFF5F, the canvas exactly solid #090B0A, and the center cursor exactly solid #F5F7EE. Simplify the center white cursor from a plus into one small precise circular scrub point. Make the upper and lower bent stems perfectly balanced counterparts with consistent stroke width and clean vector edges. Reduce the detached horizontal end ticks slightly so the overall silhouette stays compact.  
> Composition/framing: centered with 18% outer padding; strong at 32 px  
> Constraints: edit only as specified; preserve the opposing S-flow and horizontal scrub datum; no text, no H silhouette, no literal earbuds, no new shapes, no mockup, no 3D, no border, no watermark. Use only three perfectly flat solid colors.

The generated master is retained in `Generated/`. The canonical shipping geometry is `StemSense-mark.svg`; it removes raster lighting drift and guarantees exact palette values and small-size clarity.
