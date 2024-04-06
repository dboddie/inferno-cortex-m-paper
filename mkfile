default:V:
	groff -ms -t -Tps -F/tmp/font cortexm.ms > /tmp/cortexm.ps
	ps2pdf /tmp/cortexm.ps /tmp/Three-More-Cortex-M-Inferno-Ports_David-Boddie-2024.pdf
