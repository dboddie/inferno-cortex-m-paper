default:V:
	groff -ms -t -Tps -F/tmp/font cortexm.ms > /tmp/cortexm.ps
	ps2pdf /tmp/cortexm.ps /tmp/cortexm.pdf
