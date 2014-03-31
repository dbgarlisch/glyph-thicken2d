# glyph-thicken2d
Some solvers will not accept 2D grid blocks as input for 2D analysis. Instead, these solvers require an equivalent, 3D grid that is one cell thick.

This glyph script thickens a 2D grid into a one cell deep, 3D grid. All boundary conditions in the 2D grid are automatically transfered to the corresponding extruded domains in the resulting 3D grid.

![Thicken2d Banner Image](../master/images/banner.png  "thicken2d banner Image")


### Table of Contents
* [Running The Script](#running-the-script)
    * [Dialog Box Options](#dialog-box-options)
* [Script Limitations](#script-limitations)
* [Sourcing This Script](#sourcing-this-script)
* [Disclaimer](#disclaimer)


## Running The Script

* Build a 2D grid in an XY plane. The CAE dimension **must** be set to 2.
* Apply boundary conditions to the appropriate connectors.
* Execute this script.
* Set the desired options in the dialog box.
* Press OK to thicken the grid.

### Dialog Box Options

<img src="../master/images/dialog.png" width="400px" alt="Thicken2d Dialog Box Image"/>

* **Extrude Steps** - Sets the number of extrusion steps.
* **Extrude Distance** - Sets the total extrusion distance traversed by all steps combined.
* **Min Side BC** - Sets the boundary condition that will be applied to the min side wall domains in the thickened grid.
  * You can select the name of an existing boundary condition using the drop down list (the *Type* and *Id* are displayed).
  * To create a new boundary condition, enter a unique *Name* along with its *Type* and *Id*.
  * Set the *Name* to *Unspecified* to skip the appication of a min side boundary condition.
* **Max Side BC** - Sets the boundary condition that will be applied to the max side wall domains in the thickened grid.
  * You can select the name of an existing boundary condition using the drop down list (the *Type* and *Id* are displayed).
  * To create a new boundary condition, enter a unique *Name* along with its *Type* and *Id*.
  * Set the *Name* to *Unspecified* to skip the appication of a max side boundary condition.
* **Enable verbose output** - Select this option to see detailed runtime information. Unselect this option to see minimal runtime information.


## Script Limitations

The dialog does not support setting the extrusion direction and always extrudes in the +Z direction.

This script cannot be used directly with solvers that do not support 2D grid mode. Instead, the 2D grids will need to be thickened manually using Pointwise's block extrusion tools. However, as a workaround, you can:

* Load your 2D grid into Pointwise.
* Change the CAE solver to one that supports 2D mode (e.g. CGNS).
* Switch the mode to 2D (menu CAE/Set Dimension/2D).
* Thicken the 2D grid with the script.
* Switch solver to the one you really want to use.
* Reset the BC and VC types.


## Sourcing This Script

It is possible to source this script in your own Glyph scripts and use it as a library.

See the [Thicken2D API Docs](Thicken2Dto3D_API.md) for information on how to use this script as a library.


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
