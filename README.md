# esp-r-nix

esp-r-nix is a Nix Flake which compiles ancient open source energy modelling
software called esp-r[^1] created by the University of Strathclyde. To do this,
it even compiles Radiance[^2], a no longer maintained and similarly ancient and hard
to reproduce program, which is an under-documented runtime dependency of esp-r.

[^1]: https://en.wikipedia.org/wiki/ESP-r
[^2]: https://floyd.lbl.gov/radiance/framed.html

![esp-r](/../images/esp-r.png)

# Usage

###### Locally
1. Clone this repository
2. `nix run .#esp-r`

###### Remotely
`nix run github:matthewcroughan/esp-r-nix#esp-r`
