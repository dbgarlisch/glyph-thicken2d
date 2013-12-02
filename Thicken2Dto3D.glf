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
pw::Script loadTk

#####################################################################
#                       public namespace procs
#####################################################################
namespace eval pw::Thicken2D {}


#----------------------------------------------------------------------------
proc pw::Thicken2D::run { } {
  pw::_Thicken2D::gui::makeWindow
  tkwait window .
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
proc pw::Thicken2D::setSidewallBc { solverName {bcName "Unspecified"} {bcType "Unspecified"} {bcId "null"} {minMax "both"} } {
  if { -1 == [lsearch -exact [pw::Application getCAESolverNames] $solverName] } {
	pw::_Thicken2D::fatalMsg "Invalid solverName='$solverName' in setSidewallBc!"
  }
  switch $minMax {
  min -
  max {
    set key "$solverName,$minMax"
    set pattern $key
  }
  both {
    set key $solverName
    set pattern "$key*"
  }
  default {
	pw::_Thicken2D::fatalMsg "Invalid minMax='$minMax' in setSidewallBc!"
  }
  }

  if { "Unspecified" == $bcName } {
    array unset pw::_Thicken2D::extSideWallBcInfo $pattern
    pw::_Thicken2D::traceMsg "Removing Side Wall Bc Info for '$key'."
  } else {
    set pw::_Thicken2D::extSideWallBcInfo($key) [list $bcName $bcType $bcId]
    pw::_Thicken2D::traceMsg "Adding extSideWallBcInfo($key) = \{'$bcName' '$bcType' '$bcId'\}."
  }
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
  set verbose 0

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
	# FIXED in 17.1R5
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
} ;# namespace eval pw::_Thicken2D


#####################################################################
#                       private namespace GUI procs
#####################################################################
namespace eval pw::_Thicken2D::gui {

  variable bcNames
  set bcNames [pw::BoundaryCondition getNames]

  variable bcNamesSorted
  set bcNamesSorted [lsort $bcNames]

  variable bcTypes
  set bcTypes [pw::BoundaryCondition getPhysicalTypes]

  variable errors
  array set errors [list]

  variable caeSolver
  set caeSolver [pw::Application getCAESolver]

  variable isVerbose
  set isVerbose 0

  variable extSteps
  set extSteps 1

  variable extDistance
  set extDistance 1.0

  variable minBcName
  set minBcName [lindex $bcNames 0]

  variable minBcType
  set minBcType [lindex $bcTypes 0]

  variable minBcId
  set minBcId null

  variable maxBcName
  set maxBcName [lindex $bcNames 0]

  variable maxBcType
  set maxBcType [lindex $bcTypes 0]

  variable maxBcId
  set maxBcId null

  # widget hierarchy
  variable w
  set w(LabelTitle)          .title
  set w(FrameMain)           .main

    set w(StepsLabel)        $w(FrameMain).stepsLabel
    set w(StepsEntry)        $w(FrameMain).stepsEntry

    set w(DistanceLabel)     $w(FrameMain).distanceLabel
    set w(DistanceEntry)     $w(FrameMain).distanceEntry

    set w(BoundaryLabel)     $w(FrameMain).boundaryLabel
    set w(BcNameLabel)       $w(FrameMain).bcNameLabel
    set w(BcTypeLabel)       $w(FrameMain).bcTypeLabel
    set w(BcIdLabel)         $w(FrameMain).bcIdLabel

    set w(MinBcLabel)        $w(FrameMain).minBcLabel
    set w(MinBcNameCombo)    $w(FrameMain).minBcNameCombo
    set w(MinBcTypeCombo)    $w(FrameMain).minBcTypeCombo
    set w(MinBcIdEntry)      $w(FrameMain).minBcIdEntry

    set w(MaxBcLabel)        $w(FrameMain).maxBcLabel
    set w(MaxBcNameCombo)    $w(FrameMain).maxBcNameCombo
    set w(MaxBcTypeCombo)    $w(FrameMain).maxBcTypeCombo
    set w(MaxBcIdEntry)      $w(FrameMain).maxBcIdEntry

    set w(VerboseCheck)      $w(FrameMain).verboseCheck

  set w(FrameButtons)        .fbuttons
    set w(Logo)              $w(FrameButtons).logo
    set w(OkButton)          $w(FrameButtons).okButton
    set w(CancelButton)      $w(FrameButtons).cancelButton


  #----------------------------------------------------------------------------
  proc checkErrors { } {
    variable errors
    variable w
    if { 0 == [array size errors] } {
      set state normal
    } else {
      set state disabled
    }
    if { [catch {$w(OkButton) configure -state $state} err] } {
      #puts $err
    }
    return 1
  }


  #----------------------------------------------------------------------------
  proc validateInput { val type key } {
    variable errors
    if { [string is $type -strict $val] } {
      array unset errors $key
    } else {
      set errors($key) 1
    }
  }


  #----------------------------------------------------------------------------
  proc validateInteger { val key } {
    validateInput $val integer $key
  }


  #----------------------------------------------------------------------------
  proc validateBcId { val key } {
    if { "null" == $val } {
      # make integer check happy
      set val 0
    }
    validateInteger $val $key
  }


  #----------------------------------------------------------------------------
  proc validateDouble { val key } {
    validateInput $val double $key
  }


  #----------------------------------------------------------------------------
  proc validateString { val key } {
    validateInput $val print $key
  }


  #----------------------------------------------------------------------------
  proc okAction { } {
    variable caeSolver
    variable isVerbose
    variable extDistance
    variable extSteps
    variable minBcName
    variable minBcType
    variable minBcId
    variable maxBcName
    variable maxBcType
    variable maxBcId

    pw::Thicken2D::setVerbose $isVerbose

    # Controls extrusion direction
    pw::Thicken2D::setExtDirection {0 0 1}

    # Controls extrusion distance
    pw::Thicken2D::setExtDistance $extDistance

    # Controls extrusion number of steps
    pw::Thicken2D::setExtSteps $extSteps

    # clear all BC setting for solver
    pw::Thicken2D::setSidewallBc $caeSolver
    pw::Thicken2D::setMinSidewallBc $caeSolver $minBcName $minBcType $minBcId
    pw::Thicken2D::setMaxSidewallBc $caeSolver $maxBcName $maxBcType $maxBcId

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
    pw::Thicken2D::thicken $domsToThicken
  }


  #----------------------------------------------------------------------------
  proc stepsAction { action newVal oldVal } {
    if { -1 != $action } {
      validateInteger $newVal STEPS
      checkErrors
    }
    return 1
  }


  #----------------------------------------------------------------------------
  proc distanceAction { action newVal oldVal } {
    variable extDistance
    if { -1 != $action } {
      validateDouble $newVal DISTANCE
      checkErrors
    }
    return 1
  }


  #----------------------------------------------------------------------------
  proc bcNameAction { which action newVal oldVal } {
    set lwhich [string tolower $which]
    set bcTypeCombo ${which}BcTypeCombo
    set bcIdEntry ${which}BcIdEntry
    set bcTypeVar ${lwhich}BcType
    set bcIdVar ${lwhich}BcId

    variable w
    variable ${lwhich}BcName
    variable ${lwhich}BcType
    variable ${lwhich}BcId
    variable bcNamesSorted

    if { -1 == [lsearch -sorted $bcNamesSorted $newVal] } {
      # bc does not exist, allow type and id values
      $w($bcTypeCombo) configure -state readonly
      $w($bcIdEntry) configure -state normal
      set $bcIdVar null
    } else {
      # bc exists, disallow type and id values
      $w($bcTypeCombo) configure -state disabled
      $w($bcIdEntry) configure -state disabled
      set bc [pw::BoundaryCondition getByName $newVal]
      set $bcTypeVar [$bc getPhysicalType]
      if { "Unspecified" == $newVal } {
	set $bcIdVar ""
      } else {
	set $bcIdVar [$bc getId]
      }
    }
    validateString $newVal "${which}_NAME"
    checkErrors
    return 1
  }


  #----------------------------------------------------------------------------
  proc minBcNameAction { action newVal oldVal } {
    bcNameAction Min $action $newVal $oldVal
    return 1
  }


  #----------------------------------------------------------------------------
  proc maxBcNameAction { action newVal oldVal } {
    bcNameAction Max $action $newVal $oldVal
    return 1
  }


  #----------------------------------------------------------------------------
  proc minBcIdAction { action newVal oldVal } {
    if { -1 != $action } {
      validateBcId $newVal MIN_ID
      checkErrors
    }
    return 1
  }


  #----------------------------------------------------------------------------
  proc maxBcIdAction { action newVal oldVal } {
    if { -1 != $action } {
      validateBcId $newVal MAX_ID
      checkErrors
    }
    return 1
  }


  #----------------------------------------------------------------------------
  proc makeWindow { } {
    variable w
    variable caeSolver
    variable bcNames
    variable bcTypes
    variable minBcName
    variable maxBcName

    set disabledBgColor [ttk::style lookup TEntry -fieldbackground disabled]
    ttk::style map TCombobox -fieldbackground [list disabled $disabledBgColor]

    # create the widgets
    label $w(LabelTitle) -text "Thicken 2D Grid ($caeSolver)"
    setTitleFont $w(LabelTitle)

    frame $w(FrameMain) -padx 15

    label $w(StepsLabel) -text "Extrude Steps" -anchor w
    entry $w(StepsEntry) -textvariable pw::_Thicken2D::gui::extSteps -width 4 \
      -validate key -validatecommand { pw::_Thicken2D::gui::stepsAction %d %P %s }

    label $w(DistanceLabel) -text "Extrude Distance" -anchor w
    entry $w(DistanceEntry) -textvariable pw::_Thicken2D::gui::extDistance -width 8 \
      -validate key -validatecommand { pw::_Thicken2D::gui::distanceAction %d %P %s }

    label $w(BoundaryLabel) -text "Boundary" -anchor w
    label $w(BcNameLabel) -text "Name" -anchor w
    label $w(BcTypeLabel) -text "Type" -anchor w
    label $w(BcIdLabel) -text "Id" -anchor w

    label $w(MinBcLabel) -text "Min Side BC" -anchor w
    ttk::combobox $w(MinBcNameCombo) -values $bcNames -state normal \
      -textvariable pw::_Thicken2D::gui::minBcName -validate key \
      -validatecommand { pw::_Thicken2D::gui::minBcNameAction %d %P %s }
    bind $w(MinBcNameCombo) <<ComboboxSelected>> \
      {pw::_Thicken2D::gui::minBcNameAction 9 $pw::_Thicken2D::gui::minBcName $pw::_Thicken2D::gui::minBcName}
    ttk::combobox $w(MinBcTypeCombo) -values $bcTypes \
      -state readonly -textvariable pw::_Thicken2D::gui::minBcType
    entry $w(MinBcIdEntry) -textvariable pw::_Thicken2D::gui::minBcId -width 4 \
      -validate key -validatecommand { pw::_Thicken2D::gui::minBcIdAction %d %P %s }

    label $w(MaxBcLabel) -text "Max Side BC" -anchor w
    ttk::combobox $w(MaxBcNameCombo) -values $bcNames \
      -state normal -textvariable pw::_Thicken2D::gui::maxBcName -validate key \
      -validatecommand { pw::_Thicken2D::gui::maxBcNameAction %d %P %s }
    bind $w(MaxBcNameCombo) <<ComboboxSelected>> \
      {pw::_Thicken2D::gui::maxBcNameAction 9 $pw::_Thicken2D::gui::maxBcName $pw::_Thicken2D::gui::maxBcName}
    ttk::combobox $w(MaxBcTypeCombo) -values $bcTypes \
      -state readonly -textvariable pw::_Thicken2D::gui::maxBcType
    entry $w(MaxBcIdEntry) -textvariable pw::_Thicken2D::gui::maxBcId -width 4 \
      -validate key -validatecommand { pw::_Thicken2D::gui::maxBcIdAction %d %P %s }

    checkbutton $w(VerboseCheck) -text "Enable verbose output" \
      -variable pw::_Thicken2D::gui::isVerbose -anchor w -padx 20 -state active

    frame $w(FrameButtons) -relief sunken -padx 15 -pady 5

    label $w(Logo) -image [pwLogo] -bd 0 -relief flat
    button $w(OkButton) -text "OK" -width 12 -bd 2 \
      -command { wm withdraw . ; pw::_Thicken2D::gui::okAction ; exit }
    button $w(CancelButton) -text "Cancel" -width 12 -bd 2 \
      -command { exit }

    # lay out the form
    pack $w(LabelTitle) -side top -pady 5
    pack [frame .sp -bd 2 -height 2 -relief sunken] -pady 0 -side top -fill x
    pack $w(FrameMain) -side top -fill both -expand 1 -pady 10

    # lay out the form in a grid
    grid $w(StepsLabel)    -row 0 -column 0 -sticky we -pady 3 -padx 3
    grid $w(StepsEntry)    -row 0 -column 1 -sticky w -pady 3 -padx 3

    grid $w(DistanceLabel) -row 1 -column 0 -sticky we -pady 3 -padx 3
    grid $w(DistanceEntry) -row 1 -column 1 -sticky w -pady 3 -padx 3

    grid $w(BoundaryLabel) -row 2 -column 0 -sticky w -pady 3 -padx 3
    grid $w(BcNameLabel)   -row 2 -column 1 -sticky w -pady 3 -padx 3
    grid $w(BcTypeLabel)   -row 2 -column 2 -sticky w -pady 3 -padx 3
    grid $w(BcIdLabel)     -row 2 -column 3 -sticky w -pady 3 -padx 3

    grid $w(MinBcLabel)     -row 3 -column 0 -sticky we -pady 3 -padx 3
    grid $w(MinBcNameCombo) -row 3 -column 1 -sticky we -pady 3 -padx 3
    grid $w(MinBcTypeCombo) -row 3 -column 2 -sticky we -pady 3 -padx 3
    grid $w(MinBcIdEntry)   -row 3 -column 3 -sticky we -pady 3 -padx 3

    grid $w(MaxBcLabel)     -row 4 -column 0 -sticky we -pady 3 -padx 3
    grid $w(MaxBcNameCombo) -row 4 -column 1 -sticky we -pady 3 -padx 3
    grid $w(MaxBcTypeCombo) -row 4 -column 2 -sticky we -pady 3 -padx 3
    grid $w(MaxBcIdEntry)   -row 4 -column 3 -sticky we -pady 3 -padx 3

    grid $w(VerboseCheck)  -row 5 -columnspan 2 -sticky we -pady 3 -padx 3

    # lay out buttons
    pack $w(CancelButton) $w(OkButton) -pady 3 -padx 3 -side right
    pack $w(Logo) -side left -padx 5

    # give extra space to (only) column
    grid columnconfigure $w(FrameMain) 1 -weight 1

    pack $w(FrameButtons) -fill x -side bottom -padx 0 -pady 0 -anchor s

    # init GUI state for BC data
    minBcNameAction 8 $minBcName $minBcName
    maxBcNameAction 8 $maxBcName $maxBcName

    focus $w(VerboseCheck)
    raise .

    # don't allow window to resize
    wm resizable . 0 0
  }


  #----------------------------------------------------------------------------
  proc setTitleFont { widget {fontScale 1.5} } {
    # set the font for the input widget to be bold and 1.5 times larger than
    # the default font
    variable titleFont
    if { ! [info exists titleFont] } {
      set fontSize [font actual TkCaptionFont -size]
      set titleFont [font create -family [font actual TkCaptionFont -family] \
	-weight bold -size [expr {int($fontScale * $fontSize)}]]
    }
    $widget configure -font $titleFont
  }


  #----------------------------------------------------------------------------
  proc pwLogo {} {
    set logoData "
R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

    return [image create photo -format GIF -data $logoData]
  }
} ;# namespace eval pw::_Thicken2D::gui

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
