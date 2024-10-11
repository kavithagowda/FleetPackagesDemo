Fleet Packages demos
This repo contains scripts that run demos of Fleet Packages. It currently has two different demos, one with an nginx application and the other that focuses on policies.

Setup
The scripts are set up to run against the fleetpackages-demo project. It is set up with four clusters across europe and the US.

To reset the project between runs of the demos, simply run the reset.sh script. It resets some properties that are changed during the test runs and also runs several checks to verify that the project is in good shape for demos.

Nginx
This is a demo that focuses on managing nginx with variants across the different clusters.

Run the demo with the command nginx-demo.sh.

Policy
This is a demo that focuses on policies, both the ones that are built into Kubernetes, but also on policies managed through policy controller.

Run the demo with the command policy-demo.sh.

Suggestions
Simple zsh prompt: PROMPT=“%B%F{240}demo%f %(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )%{$reset_color%}”
