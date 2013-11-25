# glyph-thicken2d
Some solvers will not accept 2D grid blocks as input for 2D analysis. Instead, these solvers require an equivalent, 3D grid that is one cell thick.

This glyph script thickens a 2D grid into a one cell deep, 3D grid. All boundary conditions in the 2D grid are automatically transfered to the corresponding extruded domains in the resulting 3D grid.

![Thicken2d Banner Image](../master/images/banner.png  "thicken2d banner Image")


### Table of Contents
* [Running The Script](#running-the-script)
* [Configuring The Script](#configuring-the-script)
* [Script Limitations](#script-limitations)
* [Sourcing This Script](#sourcing-this-script)
    * [pw::Thicken2D Library Docs](#pwthicken2d-library-docs)
    * [pw::Thicken2D Library Usage Examples](#pwthicken2d-library-usage-examples)
        * [Thickening a 2D Grid for the COBALT Solver](#thickening-a-2d-grid-for-the-cobalt-solver)
* [Disclaimer](#disclaimer)


## Running The Script

* Build a 2D grid. The CAE dimension **must** be set to 2.
* Apply boundary conditions to the appropriate connectors.
* Execute this script.


## Configuring The Script

You can change the script's default behavior by editing the configuration options
set in **pw::Thicken2D::run**. See the the [pw::Thicken2D Library Docs](#pwthicken2d-library-docs) section for details.


## Script Limitations

Pointwise does not support 2D mode for some of the CAE solvers that require thickened 2D grids. This script cannot be used for these solvers. Instead, the 2D grids will need to be thickened manually using Pointwise's block extrusion tools.


## Sourcing This Script

It is possible to source this script in your own Glyph scripts and use it as a library.

To source this script add the following lines to your script:

    set disableAutoRun_Thicken2D 1 ;# disable the autorun
    source "/some/path/to/your/copy/of/Thicken2Dto3D.glf"]

See the script `test/test01.glf` for an example.


### pw::Thicken2D Library Docs

```Tcl
proc pw::Thicken2D::setVerbose { val }
```
Sets the level of runtime trace information dumped by the script.
<dl>
  <dt><code>val</code></dt>
  <dd>If set to 1, full trace information is dumped. If set to 0, only minimal trace information is dumped. (default: 0)</dd>
</dl>
<br/>

```Tcl
proc pw::Thicken2D::setExtDirection { val }
```
Sets the extrusion direction.
<dl>
  <dt><code>val</code></dt>
  <dd>The extrusion direction vector as a Tcl list of three floating point values {dx dy dz}. (default: {0 0 1})</dd>
</dl>
<br/>

```Tcl
proc pw::Thicken2D::setExtDistance { val }
```
Sets the extrusion distance.
<dl>
  <dt><code>val</code></dt>
  <dd>The total extrusion distance traversed by all steps combined. (default: 1.0)</dd>
</dl>
<br/>

```Tcl
proc pw::Thicken2D::setExtSteps { val }
```
Sets the number of extrusion steps.
<dl>
  <dt><code>val</code></dt>
  <dd>The number of extrusion steps. (default: 1)</dd>
</dl>
<br/>

```Tcl
proc pw::Thicken2D::setMinSidewallBc { solverName bcName bcType {bcId "null"} }
```
For a given solver, sets the boundary condition that will be applied to the min side wall domains in the thickened grid.

See **pw::Thicken2D::setSidewallBc** for more details.
<br/>

```Tcl
proc pw::Thicken2D::setMaxSidewallBc { solverName bcName bcType {bcId "null"} }
```
For a given solver, sets the boundary condition that will be applied to the max side wall domains in the thickened grid.

See **pw::Thicken2D::setSidewallBc** for more details.
<br/>

```Tcl
proc pw::Thicken2D::setSidewallBc { solverName bcName bcType {bcId "null"} {minMax "both"} }
```
For a given solver, sets the boundary condition that will be applied to the min, max, or to both side wall domains in the thickened grid.
<dl>
  <dt><code>solverName</code></dt>
  <dd>Name of the solver for which this entry is being made. Must be one of the solver names returned by
    <b>[pw::Application getCAESolverNames]</b></dd>
  <dt><code>bcName</code></dt>
  <dd>The side wall BC name. This can be any name allowed by the targeted solver.  If the boundary condition already
      exisits, it will be used as-is (the `bcType` and `bcId` values are ignored). If the boundary condition does not
      exit, it is created using the `bcType` and `bcId` values.</dd>
  <dt><code>bcType</code></dt>
  <dd>The solver specific boundary condition type.</dd>
  <dt><code>bcId</code></dt>
  <dd>An integer, user-defined boundary condition id. If the id is set to *null*, a unique value is automatically
      assigned.</dd>
  <dt><code>minMax</code></dt>
  <dd>Indicates the side wall for which this BC is intended. One of `min`, `max`, or `both`.</dd>
</dl>

By default, the following side wall boundary condition entries are created;
```Tcl
    pw::Thicken2D::setSidewallBc "GASP" "Side Wall" "1st Order Extrapolation"

    pw::Thicken2D::setMinSidewallBc "CGNS" "Side Wall Min" "Wall"
    pw::Thicken2D::setMaxSidewallBc "CGNS" "Side Wall Max" "Wall"
```

The Min and Max versions of this proc are wrappers around **pw::Thicken2D::setSidewallBc** as detailed below.
```Tcl
   pw::Thicken2D::setMinSidewallBc "CGNS" "Side Wall Min" "Wall"
   # is equivalent to
   pw::Thicken2D::setSidewallBc "CGNS" "Side Wall Min" "Wall" "null" "min"

   pw::Thicken2D::setMaxSidewallBc "CGNS" "Side Wall Max" "Wall"
   # is equivalent to
   pw::Thicken2D::setSidewallBc "CGNS" "Side Wall Max" "Wall" "null" "max"
```

The min domains are the domains from the original 2D grid. The max domains are opposite the min domains on the other end of the extruded 3D grid. For an example, see the boundary condition assignments in the banner image above.

The side wall boundary conditions are optional. Side wall boundary conditions will only be assigned by the script if appropriate solver entries are added.
<br/>

```Tcl
proc pw::Thicken2D::thicken { domsToThicken }
```
Thickens a 2D grid into an extruded 3D grid.
<dl>
  <dt><code>domsToThicken</code></dt>
  <dd>A list of 2D blocks (domains) to thicken.</dd>
</dl>

All boundary conditions in the 2D grid are automatically transfered to the corresponding extruded domains in the resulting 3D grid.

See also, **pw::Thicken2D::setExtDirection**, **proc pw::Thicken2D::setExtDistance**, **proc pw::Thicken2D::setExtSteps**, **pw::Thicken2D::setMinSidewallBc**, **pw::Thicken2D::setMaxSidewallBc**, **pw::Thicken2D::setSidewallBc**.
<br/>

### pw::Thicken2D Library Usage Examples

#### Thickening a 2D Grid for the COBALT Solver

```Glyph
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
```

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
