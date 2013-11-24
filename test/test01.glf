#
# Copyright 2013 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#


# ===============================================
# THICKEN 2D GRID TEST SCRIPT
# ===============================================
# Using Thicken2Dto3D.glf as a library

package require PWI_Glyph 2.17

set disableAutoRun_Thicken2D 1
source [file join [file dirname [info script]] "../Thicken2Dto3D.glf"]

pw::Application reset -keep Clipboard
set mode [pw::Application begin ProjectLoader]
$mode initialize [file join [file dirname [info script]] "baffle-test.pw"]
$mode setAppendMode false
$mode load
$mode end
unset mode

pw::Application setCAESolver "COBALT" 2

# Set to 0/1 to disable/enable TRACE messages
pw::Thicken2D::setVerbose 1

# Controls extrusion direction
pw::Thicken2D::setExtDirection {0 0 1}

# Controls extrusion distance
pw::Thicken2D::setExtDistance 2

# Controls extrusion number of steps
pw::Thicken2D::setExtSteps 4

pw::Thicken2D::setMinSidewallBc "COBALT" "Side Wall Min" "Solid Wall" "99"
pw::Thicken2D::setMaxSidewallBc "COBALT" "Side Wall Max" "Solid Wall" "88"

pw::Thicken2D::thicken [pw::Grid getAll -type pw::Domain]

# END SCRIPT

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE
# FAULT OR NEGLIGENCE OF POINTWISE.
#
