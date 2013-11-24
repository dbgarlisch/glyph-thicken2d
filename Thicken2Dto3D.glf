#
# Copyright 2013 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#


# ===============================================
# THICKEN 2D GRID SCRIPT - POINTWISE
# ===============================================
# https://github.com/pointwise/Thicken2D
#
# Vnn: Release Date / Author
# v01: Nov 23, 2013 / David Garlisch
#
# ===============================================

if { ![namespace exists pw::_Thicken2D] } {

package require PWI_Glyph

#####################################################################
#                       public namespace procs
#####################################################################
namespace eval pw::Thicken2D {}


#----------------------------------------------------------------------------
proc pw::Thicken2D::run { } {
  # Capture a list of all the grid's domains
  set allDoms [pw::Grid getAll -type pw::Domain]

  # Only keep the visible and selectable domains
  set domsToThicken {}
  foreach dom $allDoms {
	if { ![pw::Display isLayerVisible [$dom getLayer]] } {
	  continue
	} elseif { ![$dom getEnabled] } {
	  continue
	} else {
	  lappend domsToThicken $dom
	}
  }

  # Set to 0/1 to disable/enable TRACE messages
  setVerbose 0

  # Controls extrusion direction
  setExtDirection {0 0 1}

  # Controls extrusion distance
  setExtDistance 1

  # Controls extrusion number of steps
  setExtSteps 1

  setSidewallBc "GASP" "Side Wall" "1st Order Extrapolation"

  setMinSidewallBc "CGNS" "Side Wall Min" "Wall" "null"
  setMaxSidewallBc "CGNS" "Side Wall Max" "Wall" "null"

  thicken $domsToThicken
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setVerbose { val } {
  set pw::_Thicken2D::verbose $val
  pw::_Thicken2D::traceMsg "Setting verbose = $val."
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setExtDirection { val } {
  if { 3 != [llength $val]} {
	set val {0 0 1}
  }
  set pw::_Thicken2D::extDirection $val
  pw::_Thicken2D::traceMsg "Setting extDirection = \{$val\}."
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setExtDistance { val } {
  if { 0.0 >= $val} {
	set val 1.0
  }
  set pw::_Thicken2D::extDistance $val
  pw::_Thicken2D::traceMsg "Setting extDistance = $val."
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setExtSteps { val } {
  if { 0 >= $val} {
	set val 1
  }
  set pw::_Thicken2D::extNumSteps $val
  pw::_Thicken2D::traceMsg "Setting extNumSteps = $val."
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setMinSidewallBc { solverName bcName bcType {bcId "null"} } {
  setSidewallBc $solverName $bcName $bcType $bcId "min"
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setMaxSidewallBc { solverName bcName bcType {bcId "null"} } {
  setSidewallBc $solverName $bcName $bcType $bcId "max"
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::setSidewallBc { solverName bcName bcType {bcId "null"} {minMax "both"} } {
  if { -1 == [lsearch -exact [pw::Application getCAESolverNames] $solverName] } {
	pw::_Thicken2D::fatalMsg "Invalid solverName='$solverName' in setSidewallBc!"
  }
  switch $minMax {
  min -
  max {
	set key "$solverName,$minMax"
  }
  both {
	set key $solverName
  }
  default {
	pw::_Thicken2D::fatalMsg "Invalid minMax='$minMax' in setSidewallBc!"
  }
  }
  set pw::_Thicken2D::extSideWallBcInfo($key) [list $bcName $bcType $bcId]
  pw::_Thicken2D::traceMsg "Adding extSideWallBcInfo($key) = \{'$bcName' '$bcType' '$bcId'\}."
}


#----------------------------------------------------------------------------
proc pw::Thicken2D::thicken { domsToThicken } {
  if { 2 != [pw::Application getCAESolverDimension] } {
	pw::_Thicken2D::fatalMsg "This script requires a 2D grid."
  }

  pw::_Thicken2D::init

  puts "**** Preprocessing 2D grid..."

  array set con2DomsMap {} ;# maps a con from 2D grid to its doms
  array set reg2BcMap {}   ;# maps a 2D register to its BC

  # Process the 2D grid's connectors
  foreach con [pw::Grid getAll -type pw::Connector] {
	set doms [pw::Domain getDomainsFromConnectors [list $con]]
	foreach dom $doms {
	  set bc [pw::BoundaryCondition getByEntities [list [list $dom $con]]]
	  if { [$bc getName] == "Unspecified" } {
		# skip registers without a named BC applied
		continue
	  }
	  pw::_Thicken2D::traceMsg "\{[$dom getName] [$con getName]\} has bc [pw::_Thicken2D::bcToString $bc]"
	  set reg2BcMap($dom,$con) $bc
	}
	if { 0 != [llength [array get reg2BcMap "*,$con"]] } {
	  # con had at least one BC. Save the $con to $doms mapping.
	  set con2DomsMap($con) $doms
	}
  }

  # Capture the list of connectors that had BCs applied
  set bcCons [array names con2DomsMap]

  puts "**** Converting to a 3D grid..."

  # switch current solver to 3D mode
  pw::Application setCAESolver $pw::_Thicken2D::solverName 3
  pw::_Thicken2D::traceMsg "Solver '$pw::_Thicken2D::solverName' switched to 3D mode."

  # sort list of domains - needed for lsearch
  set domsToThicken [lsort $domsToThicken]

  foreach dom $domsToThicken {
	pw::_Thicken2D::extrudeDomain $dom
  }

  puts "**** Transferring BCs to the extruded domains..."

  # Process original BC connectors and transfer the BC to the extruded domain.
  foreach bcCon $bcCons {
	# Get the one or two domains from the original 2D grid that were on either
	# side of $bcCon. These domains were extuded to blocks in the 3D grid.
	set bcDoms $con2DomsMap($bcCon)

	# Get the domain ($extrudedDom) that was created by the extrusion of $bcCon.
	if { [pw::_Thicken2D::getExtrudedDom $domsToThicken $bcCon extrudedDom] } {
	  # drop through
	} elseif { [pw::_Thicken2D::isInternalCon $con $bcDoms] } {
	  pw::_Thicken2D::warningMsg "Skipping internal connector [$bcCon getName]!"
	  continue
	} else {
	  pw::_Thicken2D::fatalMsg "Could not find extruded domain for [$bcCon getName]!"
	}
	pw::_Thicken2D::traceMsg "Move BC from [$bcCon getName] to [$extrudedDom getName]"
	foreach bcDom $bcDoms {
	  # Get the block ($extrudedBlk) that was created by the extrusion of $bcDom.
	  if { ![pw::_Thicken2D::getExtrudedBlk $bcDom extrudedBlk] } {
		pw::_Thicken2D::fatalMsg "Could not find extruded block for [$bcDom getName]!"
	  }
	  # Get the BC associated with the 2D register
	  if { [pw::_Thicken2D::getRegBc reg2BcMap $bcDom $bcCon bc] } {
		# The BC on the 2D register {$bcDom $bcCon} must be transferred to the 3D
		# register {$extrudedBlk $extrudedDom}.
		$bc apply [list [list $extrudedBlk $extrudedDom]]
	  }
	}
  }
}


#####################################################################
#                       private namespace procs
#####################################################################
namespace eval pw::_Thicken2D {
  # Set to 0/1 to disable/enable TRACE messages
  variable verbose
  set verbose 1

  # Controls extrusion direction
  variable extDirection
  set extDirection   {0 0 1}

  # Controls extrusion distance
  variable extDistance
  set extDistance    1

  # Controls extrusion number of steps
  variable extNumSteps
  set extNumSteps    1

  # Controls which BCs are used for extrusion base/top domains
  #   * Use SolverName entry to specify same BC for both base and top.
  #   * Use SolverName,min entry to specify base BC.
  #   * Use SolverName,max entry to specify top BC.
  # BCs are applied to the side wall domains ONLY if the solver is found
  variable extSideWallBcInfo
  array set extSideWallBcInfo {} ;#{"BCName" "BCType" Id}

  # BC applied to min (base) doms in extruded blocks.
  variable bcExtrusionBase
  set bcExtrusionBase "null"

  # BC applied to max (top) doms in extruded blocks.
  variable bcExtrusionTop
  set bcExtrusionTop "null"

  # Active CAE solver name
  variable solverName
  set solverName {}


  #----------------------------------------------------------------------------
  proc init {} {
	variable solverName
	set solverName [pw::Application getCAESolver]

	variable extSideWallBcInfo
	variable bcExtrusionBase
	variable bcExtrusionTop

	puts "**** Initializing namespace pw::Thicken2D ..."

	if { "" != [array names extSideWallBcInfo -exact $solverName] } {
	  traceMsg "Same BC used for both side walls."
	  lassign $extSideWallBcInfo($solverName) bcName bcType bcId
	  set bcExtrusionBase [getMinMaxBC $bcName $bcType $bcId]
	  set bcExtrusionTop $bcExtrusionBase
	} else {
	  if { "" != [array names extSideWallBcInfo -exact "$solverName,min"] } {
		traceMsg "Using min side wall BC."
		lassign $extSideWallBcInfo($solverName,min) bcName bcType bcId
		set bcExtrusionBase [getMinMaxBC $bcName $bcType $bcId]
	  }
	  if { "" != [array names extSideWallBcInfo -exact "$solverName,max"] } {
		traceMsg "Using max side wall BC."
		lassign $extSideWallBcInfo($solverName,max) bcName bcType bcId
		set bcExtrusionTop [getMinMaxBC $bcName $bcType $bcId]
	  }
	}
  }


  #----------------------------------------------------------------------------
  proc fatalMsg { msg {exitCode -1} } {
	puts "  ERROR: $msg"
	exit $exitCode
  }


  #----------------------------------------------------------------------------
  proc warningMsg { msg {exitCode -1} } {
	puts "  WARNING: $msg"
  }


  #----------------------------------------------------------------------------
  proc traceMsg { msg } {
	variable verbose
	if { $verbose } {
	  puts "  TRACE: $msg"
	}
  }


  #----------------------------------------------------------------------------
  proc getMinMaxBC { bcName {physType null} {id null} } {
	if { [catch {pw::BoundaryCondition getByName $bcName} bc] } {
	  traceMsg "Creating new BC('$bcName' '$physType' $id)."
	  set bc [pw::BoundaryCondition create]
	  $bc setName $bcName
	  if { "null" != $physType } {
		$bc setPhysicalType $physType
	  }
	  if { "null" != $id } {
		$bc setId $id
	  }
	} else {
	  traceMsg "Found existing BC '$bcName'."
	}
	return $bc
  }


  #----------------------------------------------------------------------------
  proc bcToString { bc } {
	return "\{'[$bc getName]' '[$bc getPhysicalType]' [$bc getId]\}"
  }


  #----------------------------------------------------------------------------
  proc edgeContainsCon { edge con } {
	set ret 0
	set cnt [$edge getConnectorCount]
	for {set ii 1} {$ii <= $cnt} {incr ii} {
	  if { "$con" == "[$edge getConnector $ii]" } {
		set ret 1
		break
	  }
	}
	return $ret
  }


  #----------------------------------------------------------------------------
  proc isInternalCon { con doms } {
	foreach dom $doms {
	  set cnt [$dom getEdgeCount]
	  # edge 1 is ALWAYS the outer edge so we can skip it
	  for {set ii 2} {$ii <= $cnt} {incr ii} {
		if { [edgeContainsCon [$dom getEdge $ii] $con] } {
		  return 1
		}
	  }
	}
	return 0
  }


  #----------------------------------------------------------------------------
  proc traceBlockFace { blk faceId } {
	if { [catch {[$blk getFace $faceId] getDomains} doms] } {
	  traceMsg "  Bad faceid = $faceId"
	} else {
	  foreach dom $doms {
		traceMsg "  $faceId = '[$dom getName]'"
	  }
	}
  }


  #----------------------------------------------------------------------------
  proc traceBlockFaces { blk } {
	traceMsg "BLOCK '[$blk getName]'"
	set cnt [$blk getFaceCount]
	for {set ii 1} {$ii <= $cnt} {incr ii} {
	  traceBlockFace $blk $ii
	}
  }


  #----------------------------------------------------------------------------
  proc extrudeDomain { dom } {
	set createMode [pw::Application begin Create]
	  if { [$dom isOfType pw::DomainStructured] } {
		set face0 [lindex [pw::FaceStructured createFromDomains [list $dom]] 0]
		set blk [pw::BlockStructured create]
		set topFaceId KMaximum
	  } else {
		set face0 [lindex [pw::FaceUnstructured createFromDomains [list $dom]] 0]
		set blk [pw::BlockExtruded create]
		set topFaceId JMaximum
	  }
	  $blk addFace $face0
	$createMode end
	unset createMode

	variable extDirection
	variable extDistance
	variable extNumSteps

	set solverMode [pw::Application begin ExtrusionSolver [list $blk]]
	  $solverMode setKeepFailingStep true
	  $blk setExtrusionSolverAttribute Mode Translate
	  $blk setExtrusionSolverAttribute TranslateDirection $extDirection
	  $blk setExtrusionSolverAttribute TranslateDistance $extDistance
	  $solverMode run $extNumSteps
	$solverMode end
	unset solverMode
	unset face0
	traceMsg "----"
	traceMsg "Domain '[$dom getName]' extruded into block '[$blk getName]'"

	# BUG WORKAROUND - extruded block JMaximum is returning wrong face
	if { ![$dom isOfType pw::DomainStructured] } {
	  set topFaceId [$blk getFaceCount]
	}

	variable bcExtrusionBase
	variable bcExtrusionTop

	if { "null" != $bcExtrusionBase } {
	  $bcExtrusionBase apply [list [list $blk $dom]]
	  traceMsg "Applied base BC '[$bcExtrusionBase getName]' to '[$dom getName]'"
	}

	if { "null" != $bcExtrusionTop } {
	  set topDoms [[$blk getFace $topFaceId] getDomains]
	  foreach topDom $topDoms {
		$bcExtrusionTop apply [list [list $blk $topDom]]
		traceMsg "Applied base BC '[$bcExtrusionTop getName]' to '[$topDom getName]'"
	  }
	}
	traceBlockFaces $blk
	return $blk
  }


  #----------------------------------------------------------------------------
  proc getExtrudedDom { domsToThicken fromCon domVarName } {
	upvar $domVarName dom

	# get all domains using the current connector
	set doms [pw::Domain getDomainsFromConnectors [list $fromCon]]
	set foundDom 0
	foreach dom $doms {
	  if { -1 == [lsearch -sorted $domsToThicken $dom] } {
		# $dom was NOT in the original 2D grid, it MUST have been extruded from
		# the original 2D connector $fromCon.
		set foundDom 1
		break
	  }
	}
	return $foundDom
  }


  #----------------------------------------------------------------------------
  proc getExtrudedBlk { fromDom blkVarName } {
	upvar $blkVarName blk
	set ret 0
	set blocks [pw::Block getBlocksFromDomains [list $fromDom]]
	if { 1 == [llength $blocks] } {
	  set blk [lindex $blocks 0]
	  set ret 1
	}
	return $ret
  }


  #----------------------------------------------------------------------------
  proc getRegBc { mapName dom con bcVarName } {
	upvar $mapName reg2BcMap
	upvar $bcVarName bc
	set ret 0
	set pairs [array get reg2BcMap "$dom,$con"]
	if { 2 == [llength $pairs] } {
	  set bc [lindex $pairs 1]
	  set ret 1
	}
	return $ret
  }
}

} ;# ![namespace exists pw::_Thicken2D]


if { ![info exists disableAutoRun_Thicken2D] } {
    pw::Thicken2D::run
}

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
