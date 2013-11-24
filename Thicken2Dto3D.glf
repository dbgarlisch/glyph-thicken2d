#
# Copyright 2013 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

package require PWI_Glyph

#############################################################################
# THICKEN 2D GRID SCRIPT - POINTWISE
#############################################################################
# Written by David Garlisch
# v1.0: 25 Oct 2013
# v1.1: 31 Oct 2013


#############################################################################
#-- User Defined Parameters
#############################################################################

# Set to 0/1 to disable/enable TRACE messages
set verbose 1

# Controls extrusion direction, distance, and number of steps
set extDirection   {0 0 1}
set extDistance    1
set extNumSteps    1

# Controls which BCs are used for extrusion base/top domains
#   * Use SolverName entry to specify same BC for both base and top.
#   * Use SolverName,min entry to specify base BC.
#   * Use SolverName,max entry to specify top BC.
array set extSideWallBcInfo {} ;#{"BCName" "BCType" Id}

set extSideWallBcInfo(GASP)     {"Side Wall" "1st Order Extrapolation" "null"}

set extSideWallBcInfo(CGNS,min) {"Side Wall Min" "Wall" "null"}
set extSideWallBcInfo(CGNS,max) {"Side Wall Max" "Wall" "null"}

# Add new extSideWallBcInfo entries above this line.
# BCs are applied to the side wall domains ONLY if the solver is found in
# extSideWallBcInfo()


#############################################################################
#-- Helper Procs
#############################################################################

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
  global verbose
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

  global extDirection
  global extDistance
  global extNumSteps
  global bcExtrusionBase
  global bcExtrusionTop

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
proc getExtrudedDom { fromCon domVarName } {
  upvar $domVarName dom
  global origDoms

  # get all domains using the current connector
  set doms [pw::Domain getDomainsFromConnectors [list $fromCon]]
  set foundDom 0
  foreach dom $doms {
    if { -1 == [lsearch -sorted $origDoms $dom] } {
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
proc getRegBc { dom con bcVarName } {
  global reg2BcMap
  upvar $bcVarName bc
  set ret 0
  set pairs [array get reg2BcMap "$dom,$con"]
  if { 2 == [llength $pairs] } {
    set bc [lindex $pairs 1]
    set ret 1
  }
  return $ret
}


#############################################################################
#-- MAIN
#############################################################################

if { 2 != [pw::Application getCAESolverDimension] } {
  fatalMsg "This script requires a 2D grid."
}

set solverName [pw::Application getCAESolver]

# BCs applied to orig/opposing (base/top) doms in extruded blocks.
set bcExtrusionBase "null"
set bcExtrusionTop "null"
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

puts "**** Preprocessing 2D grid..."

array set con2DomsMap {} ;# maps a con from 2D grid to its doms
array set reg2BcMap {}   ;# maps a 2D register to its BC

# Capture a sorted list of all the 2D grid's domains
set allDoms [lsort [pw::Grid getAll -type pw::Domain]]
# Only keep the visible and selectable domains
set origDoms {}
foreach dom $allDoms {
  if { ![pw::Display isLayerVisible [$dom getLayer]] } {
    continue
  } elseif { ![$dom getEnabled] } {
    continue
  } else {
    lappend origDoms $dom
  }
}

# Process the 2D grid's connectors
foreach con [pw::Grid getAll -type pw::Connector] {
  set doms [pw::Domain getDomainsFromConnectors [list $con]]
  foreach dom $doms {
    set bc [pw::BoundaryCondition getByEntities [list [list $dom $con]]]
    if { [$bc getName] == "Unspecified" } {
      # skip registers without a named BC applied
      continue
    }
    traceMsg "\{[$dom getName] [$con getName]\} has bc [bcToString $bc]"
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
pw::Application setCAESolver $solverName 3
traceMsg "Solver '$solverName' switched to 3D mode."

foreach dom $origDoms {
  extrudeDomain $dom
}

puts "**** Transferring BCs to the extruded domains..."

# Process original BC connectors and transfer the BC to the extruded domain.
foreach bcCon $bcCons {
  # Get the one or two domains from the original 2D grid that were on either
  # side of $bcCon. These domains were extuded to blocks in the 3D grid.
  set bcDoms $con2DomsMap($bcCon)

  # Get the domain ($extrudedDom) that was created by the extrusion of $bcCon.
  if { [getExtrudedDom $bcCon extrudedDom] } {
    # drop through
  } elseif { [isInternalCon $con $bcDoms] } {
    warningMsg "Skipping internal connector [$bcCon getName]!"
    continue
  } else {
    errorMsg "Could not find extruded domain for [$bcCon getName]!"
  }
  traceMsg "Move BC from [$bcCon getName] to [$extrudedDom getName]"
  foreach bcDom $bcDoms {
    # Get the block ($extrudedBlk) that was created by the extrusion of $bcDom.
    if { ![getExtrudedBlk $bcDom extrudedBlk] } {
      fatalMsg "Could not find extruded block for [$bcDom getName]!"
    }
    # Get the BC associated with the 2D register
    if { [getRegBc $bcDom $bcCon bc] } {
      # The BC on the 2D register {$bcDom $bcCon} must be transferred to the 3D
      # register {$extrudedBlk $extrudedDom}.
      $bc apply [list [list $extrudedBlk $extrudedDom]]
    }
  }
}


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
