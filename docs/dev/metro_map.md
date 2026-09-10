# Metro map

The pipeline overview metro map is generated from `assets/metro_map.mmd` using [nf-metro](https://github.com/seqeralabs/nf-metro). If you add or rename pipeline steps, update the `.mmd` source and regenerate the images:

```bash
pip install 'nf-metro==2.0.0' cairosvg

# Static SVG
nf-metro render assets/metro_map.mmd \
  -o docs/images/nf-core-fetchngs_metro_map_grey.svg \
  --logo docs/images/nf-core-fetchngs_logo_light.png

# PNG: render with the `light` theme, whose background_color is 'none', so the
# PNG has a transparent ground and stays readable in both GitHub light and dark
# mode. Its chrome palette is identical to nfcore-light. Drop the var() chrome
# CSS cairosvg can't parse.
# Use cairosvg, not rsvg-convert, which ignores dominant-baseline and overlaps labels.
nf-metro render assets/metro_map.mmd \
  -o /tmp/fetchngs_metro_flat.svg \
  --theme light --no-chrome-css \
  --logo docs/images/nf-core-fetchngs_logo_light.png

python -c "import cairosvg; cairosvg.svg2png(
    url='/tmp/fetchngs_metro_flat.svg',
    write_to='docs/images/nf-core-fetchngs_metro_map_grey.png', output_width=2240)"

# Ensure trailing newline on SVG (required by pre-commit)
sed -i '' -e '$a\' docs/images/nf-core-fetchngs_metro_map_grey.svg
```
