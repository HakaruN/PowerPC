#!/usr/bin/tcsh -f
#-------------------------------------------
# qflow exec script for project /home/hakaru/Projects/Verilog/PowerPC/QFLOW3
#-------------------------------------------

# /usr/lib/qflow/scripts/synthesize.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser /home/hakaru/Projects/Verilog/PowerPC/QFLOW3/source/BundleParser.v || exit 1
# /usr/lib/qflow/scripts/placement.sh -d /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/opensta.sh  /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/vesta.sh -a /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/router.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/opensta.sh  -d /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/vesta.sh -a -d /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/migrate.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
/usr/lib/qflow/scripts/drc.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/lvs.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/gdsii.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/cleanup.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
# /usr/lib/qflow/scripts/display.sh /home/hakaru/Projects/Verilog/PowerPC/QFLOW3 BundleParser || exit 1
