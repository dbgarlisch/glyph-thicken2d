# glyph-thicken2d
Some solvers will not accept 2D grid blocks as input for 2D analysis. Instead, these solvers require an equivalent, 3D grid that is one cell thick.

This glyph script thickens a 2D grid into a one cell deep, 3D grid. All boundary conditions in the 2D grid are automatically transfered to the corresponding extruded domains in the resulting 3D grid.

![Thicken2d Banner Image](../master/images/banner.png  "thicken2d banner Image")


### Table of Contents
* [Running The Script](#running-the-script)
* [Configuring The Script](#configuring-the-script)
    * [**extDirection**](#extdirection)
    * [**extDistance**](#extdistance)
    * [**extNumSteps**](#extnumsteps)
    * [**sideWallBcInfo**](#sidewallbcinfo)
    * [**verbose**](#verbose)
* [Limitations](#limitations)
* [Disclaimer](#disclaimer)


## Running The Script

* Build a 2D grid. The CAE dimension **must** be set to 2.
* Apply boundary conditions to the appropriate connectors.
* Execute this script.


## Configuring The Script

Several configuration variables are located at the top of the script.
* [**extDirection**](#extdirection)
* [**extDistance**](#extdistance)
* [**extNumSteps**](#extnumsteps)
* [**sideWallBcInfo**](#sidewallbcinfo)
* [**verbose**](#verbose)

You can edit these values to change the script's behavior as described below.

#### **extDirection**
This setting specifies the extrusion direction vector as a Tcl list of three floating point values `{dx dy dz}`.

    default:
    set extDirection   {0 0 1}

#### **extDistance**
This floating point value controls the block extrusion distance. This is the total thickness of the block traversed by all steps.

    default:
    set extDistance    1

#### **extNumSteps**
This integer value controls the number of block extrusion steps. The thickness of each step will be equal to **extDistance**/**extNumSteps**.

    default:
    set extNumSteps    1

#### **sideWallBcInfo**
This Tcl array controls which (if any) solver specific boundary conditions are applied to the min and max domains of the extruded 3D grid. The min domains are the domains from the original 2D grid. The max domains are opposite the min domains on the other end of the extruded 3D grid.

The side wall boundary conditions are defined by adding one or two entries in the **sideWallBcInfo** array. Each entry maps to a list of three values `{BcName BcType BcId}` where;
* `BcName` - The boundary condition name. This can be any value allowed by Pointwise. If the boundary condition already exisits, it will be used as-is (the `bcType` and `bcId` values are ignored). If the boundary condition does not exit, it is created using the `bcType` and `bcId` values specified.
* `BcType` - A solver specific boundary condition type.
* `BcId` - An integer, user-defined boundary condition id. If the id is set to *null*, a unique value is automatically assigned.

To assign the same boundary condition to both the min and max side walls, add a single entry to the **sideWallBcInfo** array using just the CAE solver's name as the array key.

    set sideWallBcInfo(SolverName) {BcName BcType BcId}

To assign different boundary conditions to the min and max side walls, add two entries to the **sideWallBcInfo** array. One entry should use the CAE solver's name followed by *,min* as the array key. The other entry should use the CAE solver's name followed by *,max* as the array key.

    set sideWallBcInfo(SolverName,min) {BcName BcType BcId}
    set sideWallBcInfo(SolverName,max) {BcName BcType BcId}

The side wall boundary conditions are optional. Side wall boundary conditions will only be assigned by the script if appropriate solver entries are found in the **sideWallBcInfo** array.

    default:
    set sideWallBcInfo(GASP)     {"Side Wall" "1st Order Extrapolation" "null"}

    set sideWallBcInfo(CGNS,min) {"Side Wall Min" "Wall" "null"}
    set sideWallBcInfo(CGNS,max) {"Side Wall Max" "Wall" "null"}

#### **verbose**
This integer value controls the level of runtime trace information dumped by the script.

If set to 1, full trace information is dumped. This is useful for debugging.

If set to 0, only minimal trace information is dumped.

    default:
    set verbose 0


## Limitations

Pointwise does not support 2D mode for some of the CAE solvers that require thickened 2D grids. This script cannot be used for these solvers. Instead, the 2D grids will need to be thickened manually using Pointwise's block extrusion tools.


## Disclaimer
Scripts are freely provided. They are not supported products of
Pointwise, Inc. Some scripts have been written and contributed by third
parties outside of Pointwise's control.

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, WITH REGARD TO THESE SCRIPTS. TO THE MAXIMUM EXTENT PERMITTED
BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY
FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS
INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR
INABILITY TO USE THESE SCRIPTS EVEN IF POINTWISE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE FAULT OR NEGLIGENCE OF
POINTWISE.
