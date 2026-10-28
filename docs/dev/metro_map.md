# Metro map

The pipeline overview metro map is generated from `assets/metro_map.mmd` using [nf-metro](https://github.com/seqeralabs/nf-metro). If you add or rename pipeline steps, update the `.mmd` source and regenerate the images:

```bash
pip install 'nf-metro==2.1.0'

nf-metro render assets/metro_map.mmd \
  -o docs/images/nf-core-fetchngs_metro_map_grey.svg \
  -o docs/images/nf-core-fetchngs_metro_map_grey.png \
  --raster-width 2240 \
  --logo docs/images/nf-core-fetchngs_logo_light.png
```

Both outputs come from a single layout run. The map's `%%metro style: light` directive sets a `none` background colour, so the PNG has a transparent ground and stays readable in both GitHub light and dark mode.
