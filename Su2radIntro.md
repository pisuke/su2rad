## Features ##

### What it does ###
  * _su2rad.rb_ can help you create Radiance scene descriptions from SketchUp models.
  * exports faces as polygons not just triangles and quads (even with holes)
  * exports saved view points/perspectives
  * exports by group, by layer or by material
  * creates a nice Radiance project file structure
  * creates a sky description
  * creates field descriptions for numeric evaluations (rtrace input files)
  * imports rtrace results as 3D surface (just for the fun of it)
  * resolves conflicts in material assignments (see below)

### What it does not ###
  * It will not teach nor tell you how to use Radiance. You have to know that.
  * no backface materials
  * no proper material conversion
  * no textures
  * no mirroring ('flipping') of instances
  * no support for artificial lighting
  * no animation

### What it might do (planned features) ###
  * textures
  * replacement of component instances with pre-canned Radiance files
  * lookup of material definitions from library file
  * update feature for already exported scenes
  * support for '-mx' etc of xform ('flipping')



## Known Issues ##

If you think you have found a problem with the script please use
the issue tracker to report it ('Issues' tab above). Check first
that the same issue has not already been reported.

Additionally here is a number of bugs which I am aware of but for
the time being have no idea how to solve:

  * **Nested transformations are still a problem**. - It's getting better, though. Always do a visual check (rvu or picture) of the resulting scene description before you start rtrace calculations. If you actually have a problem in a scene try exporting with global coordinates.
  * **There are no textures!** - Right. There are no textures (yet).
  * **Colors look all wrong.** - A lot of 'colors' in Sketchup rely on textures, so see above. The conversion from Sketchup to Radiance rgb colors is not correct because of my feeble understanding of the principles involved (if anyone could share a few simple scripts I'd be delighted). Anyway you should  use a library of materials. A conversion should only be used as a last resort and then only for small elements. The library and the conversion do need more work but you can use standard material identifiers and simply swap the materials file with one that contains validated definitions.
  * **Transparency is not converted.** - Apparently there is a bug in Sketchup 6 which reports the alpha value of colors wrongly in the API. Once that is fixed in Sketchup it should work.


## History ##

_su2rad.rb_ is still under development.

  * **v00d - 16/03/08** - new 'by layer' and 'by color' modes, new preferences dialog, new material library feature, split in multiple files, added contour lines to numeric import feature, bug fixes and improvements
  * **v00c - 31/10/07** - fixed bug in export of multiple views
  * **v00b - 29/10/07** - bugfixes for Windows, new orientation export and error handling
  * **v00 - 28/10/07** - initial release


## Installation ##

Copy the _su2rad.rb_ file and the _su2radlib_ directory into the Plugins directory of your SketchUp installation (also the _locations.rb_ file if you like).
This should be

  * _/Library/Application Support/Google Sketchup 6/Sketchup/Plugins_ on a Mac
  * _C:/Program Files/Google/Google Sketchup 6/Plugins_ on Windows

Restart Sketchup. The script creates an entry in the _Plugin_ menu called _Radiance_. There you will find options to export the whole scene or just the selected objects.

Read the section on config options below.


## Configuration ##

As of version **00d** there is a preferences dialog in the 'Plugins - Radiance' menu. This dialog allows you to change the defaults for the export options and other global settings. You should know about the following options:

  * **log level** Defines the amount of information in the log file.

  * **replmarks path** This is the full path to the replmarks binary on your system. su2rad relies on replmarks to create the correct xform transformation of groups and component instances. Without replmarks (or if the path is wrong) all entities will be exported to one global co-ordinate system. Works on OS X, not tested on Windows.

  * **global coords** This sets the default value for the “global coords” prompt of the import dialog. You can always change the value in the dialog but with the right setting this variable saves you a click. Use global coords if the !xform transformation does not work correctly. With global coords a reuse of instances is not possible.

  * **triangulate** This options sets the default for export to triangles instead of n-polygons. This might be necessary in some cases where the script would create non planar polygons (due to tolerances) or simple gets confused with the holes. The option is global: either all elements are triangulated or none.

  * **unit** Sets the unit to convert from Sketchup native units (inches) to Radiance scene units. Most Radiance scenes use meters and some scripts assume this as default. To use meters in Radiance **0.0254** is the right _unit_ value. Please note that the native unit in Sketchup is always inches and is not related to the units you set in your preferences when you first open Sketchup.

  * **show options** Set to _true_ if you always want to see the dialog showing the _rad_ options. You can force or suppress the dialog at runtime.

  * **export all views** With this set to true the script will export all Sketchup pages with camera information to view files in the views subdirectory and view= lines in the scene _.rif_ file. The active page will always be the first view in the list. Note that it will not create a new export for each scene. Only the camera settings are used. If you want to export the complete scene you have to do this manually. Can also be changed at run time.

  * **update library** With this option set to _true_ su2rad.rb will write all material descriptions that are not taken from the library to files in the file system next to the Sketchup material file (.skm). Next time the definition will be read from this file. This is an easy way to find out the 'radiance safe' material name of a material and to create templates for existing Sketchup materials. This feature is still very experimental.

  * **supportdir** This ties in with the library setting above. The support directory is the base directory of the Sketchup/Radiance materials and components library. If this is empty no library is created.

  * **system clock** Sketchup has a funny way of setting parameters for the shadow calculations. Although the location sets the longitude and time zone the shadow time is still calculated in UTC. Therefore it's necessary for su2rad.rb to know the time offset of _your computer's system clock_ (not the model location) to UTC. If this is set to nil the gensky command for the sky description will be crated with '-ang alti azi' instead of the more understandable date and time syntax.