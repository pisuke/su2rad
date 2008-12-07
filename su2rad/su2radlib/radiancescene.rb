require "exportbase.rb"
require "context.rb"

class RadianceScene < ExportBase

    def initialize
        @model = Sketchup.active_model
        
        $inComponent = [false]
        @@materialContext = MaterialContext.new()
        
        resetState()
        initLog()
        
        @radOpts = RadianceOptions.new()
        @sky = RadianceSky.new()
        
        setExportDirectory()
    end

    
    def initLog
        line1 = "###  su2rad.rb export  ###" 
        line2 = "###  %s  ###" % Time.now.asctime
        super([line1,line2])
        printf "\n\n%s\n" % line1
        Sketchup.set_status_text(line1)
    end
    

    def confirmExportDirectory
        ## show user dialog for export options
        ud = UserDialog.new()
        _setDialogOptions(ud)
        if ud.show('export options') == true
            _applyDialogResults(ud)
        else
            uimessage('export canceled')
            return false
        end
        ## use test directory in debug mode
        if $DEBUG 
            setTestDirectory()
        end
        return true
    end
   
    def _setDialogOptions(ud)
        ud.addOption("export path", $export_dir)
        ud.addOption("scene name", $scene_name)
        ud.addOption("show options", $SHOWRADOPTS) 
        ud.addOption("all views", $EXPORTALLVIEWS) 
        ud.addOption("mode", $MODE, "by group|by layer|by color")
        ud.addOption("textures", $TEXTURES)
        ud.addOption("triangulate", $TRIANGULATE)
        if $REPLMARKS != '' and File.exists?($REPLMARKS)
            ud.addOption("global coords", $MAKEGLOBAL) 
        end
        #if $RAD != ''
        #    ud.addOption("run preview", $PREVIEW)
        #end
    end
    
    def _applyDialogResults(ud)
        $export_dir = cleanPath(ud.results[0])
        $scene_name = ud.results[1] 
        $SHOWRADOPTS = ud.results[2] 
        $EXPORTALLVIEWS = ud.results[3] 
        ## TODO: fill views_to_export list
        
        $MODE = ud.results[4]
        $TEXTURES = ud.results[5]
        $TRIANGULATE = ud.results[6]
        if $REPLMARKS != '' and File.exists?($REPLMARKS)
            $MAKEGLOBAL = ud.results[7]
        end
        #if $RAD != ''
        #    $PREVIEW = ud.result[7]
        #end
    end

    
    def createMainScene(references, faces_text, parenttrans=nil)
        ## top level scene split in references (*.rad) and faces ('objects/*_faces.rad')
        if $MODE != 'by group'
            ## start with replacement files for components
            ref_text = @@components.join("\n")
            ref_text += "\n"
        else
            ref_text = ""
        end
        ## create 'objects/*_faces.rad' file
        if faces_text != ''
            faces_filename = getFilename("objects/#{$scene_name}_faces.rad")
            if createFile(faces_filename, faces_text)
                xform = "!xform objects/#{$scene_name}_faces.rad"
            else
                msg = "ERROR creating file '#{faces_filename}'"
                uimessage(msg)
                xform = "## " + msg
            end
            references.push(xform)
        end
        ref_text += references.join("\n")
        ## add materials and sky at top of file
        ref_text = "!xform ./materials.rad\n" + ref_text
        if @sky.filename != ''
            ref_text = "!xform #{@sky.filename} \n" + ref_text
        end
        ref_filename = getFilename("#{$scene_name}.rad")
        if not createFile(ref_filename, ref_text)
            msg = "\n## ERROR: error creating file '%s'\n" % filename
            uimessage(msg)
            return msg
        end
    end
    

    def startExport(selected_only=0)
        scene_dir = File.join($export_dir,$scene_name)
        if not confirmExportDirectory or not removeExisting(scene_dir)
            return
        end
        @radOpts.skytype = @sky.skytype
        if $SHOWRADOPTS == true
            @radOpts.showDialog
        end
        
        ## check if global coord system is required
        if $MODE != 'by group'
            uimessage("export mode '#{$MODE}' requires global coordinates")
            $MAKEGLOBAL = true
        elsif $REPLMARKS == '' or not File.exists?($REPLMARKS)
            if $MAKEGLOBAL == false
                uimessage("WARNING: 'replmarks' not found.")
                uimessage("=> global coordinates will be used in files")
                $MAKEGLOBAL = true
            end
        end
        export(selected_only)
    end


    
    def export(selected_only=0)
        
        ## write sky first for <scene>.rad file
        @sky.skytype = @radOpts.skytype
        @sky.export()
        
        ## export geometry
        if selected_only != 0
            entities = []
            Sketchup.active_model.selection.each{|e| entities = entities + [e]}
        else
            entities = Sketchup.active_model.entities
        end
        $globaltrans = Geom::Transformation.new
        @@nameContext.push($scene_name) 
        sceneref = exportByGroup(entities, Geom::Transformation.new)
        saveFilesByColor()
        saveFilesByLayer()
        @@nameContext.pop()
        @@materialContext.export()
        createRifFile()
        writeLogFile()
    end
   
    
    def saveFilesByColor
        if $MODE != 'by color'
            return
        end
        references = []
        @@byColor.each_pair { |name,lines|
            if lines.length == 0
                next
            end
            skm = @@materialContext.getByName(name)
            name = remove_spaces(name)
            if doTextures(skm)
                uimessage("material='#{skm}' texture='#{skm.texture}'", 2)
                references.push(obj2mesh(name, lines))
            else
                filename = getFilename("objects/#{name}.rad")
                if not createFile(filename, lines.join("\n"))
                    uimessage("Error: could not create file '#{filename}'")
                else
                    references.push("!xform objects/#{name}.rad")
                end
            end
        }
        createMainScene(references, '')
    end

    def obj2mesh(name, lines)
        objfile = getFilename("objects/#{name}.obj")
        uimessage("creating obj file '#{objfile}'")
        if not createFile(objfile, lines.join("\n"))
            msg = "Error: could not create file '#{objfile}'"
            uimessage(msg)
            return "## #{msg}"
        else
            begin
                rtmfile = getFilename("objects/#{name}.rtm")
                cmd = "#{$OBJ2MESH} #{objfile} #{rtmfile}"
                uimessage("converting obj to rtm (cmd='#{cmd}')", 2)
                f = IO.popen(cmd)
                f.close()
                if File.exists?(rtmfile)
                    return "\n#{name} mesh #{name}_obj\n1 objects/#{name}.rtm\n0\n0"
                else
                    msg = "Error: could not convert obj file '#{objfile}'"
                    uimessage(msg, -2)
                    return "## #{msg}"
                end
            rescue
                msg = "Error converting obj file '#{name}.obj'"
                uimessage(msg, -2)
                return "## #{msg}"
            end
        end
    end
    
    def saveFilesByLayer
        if $MODE != 'by layer'
            return
        end
        references = []
        @@byLayer.each_pair { |name,lines|
            if lines.length == 0
                next
            end
            name = remove_spaces(name)
            filename = getFilename("objects/#{name}.rad")
            if not createFile(filename, lines.join("\n"))
                uimessage("Error: could not create file '#{filename}'")
            else
                references.push("\n!xform objects/#{name}.rad")
            end
        }
        createMainScene(references, '')
    end
    
    def runPreview
        ##TODO: preview
        if $RAD == '' or $PREVIEW != true
            return
        end
        dir, riffile = File.split(getFilename("%s.rif" % $scene_name))
        #Dir.chdir("#{$export_dir}/#{$scene_name}")
        #cmd = "%s -o x11 %s" % [$RAD, riffile]
    end
    
    def getRifObjects
        text = ''
        if @sky.filename != ''
            text += "objects=\t#{@sky.filename}\n"
        end
        i = 0
        j = 0
        line = ""
        Dir.foreach(getFilename("objects")) { |f|
            if f[0,1] == '.'
                next
            elsif f[-4,4] == '.rad'
                line += "\tobjects/#{f}"
                i += 1
                j += 1
                if i == 3
                    text += "objects=#{line}\n"
                    i = 0
                    line = ""
                end
                if j == 63
                    uimessage("too many objects for rif file")
                    break
                end
            end
        }
        if line != ""
            text += "objects=#{line}\n"
        end
        return text
    end
    
    def createRifFile
        text =  "# scene input file for rad\n"
        text += @radOpts.getRadOptions
        text += "\n"
        project = remove_spaces(File.basename($export_dir))
        text += "PICTURE=      images/#{project}\n" 
        text += "OCTREE=       octrees/#{$scene_name}.oct\n"
        text += "AMBFILE=      ambfiles/#{$scene_name}.amb\n"
        text += "REPORT=       3 logfiles/#{$scene_name}.log\n"
        text += "scene=        #{$scene_name}.rad\n"
        text += "materials=    materials.rad\n\n"
        text += "%s\n\n" % exportViews()
        text += getRifObjects
        text += "\n"
        
        filename = getFilename("%s.rif" % $scene_name)
        if not createFile(filename, text)
            uimessage("Error: Could not create rif file '#{filename}'")
        end
    end
        
    def exportViews
        viewLines = []
        viewLines.push(createViewFile(@model.active_view.camera, $scene_name))
        if $EXPORTALLVIEWS == true
            pages = @model.pages
            pages.each { |page|
                if page == @model.pages.selected_page
                    next
                elsif page.use_camera? == true
                    name = remove_spaces(page.name)
                    viewLines.push(createViewFile(page.camera, name))
                end
            }
        end
        return viewLines.join("\n")
    end

    def _getViewLine(c)
        text =  "-vp %.3f %.3f %.3f  " % [c.eye.x*$UNIT,c.eye.y*$UNIT,c.eye.z*$UNIT]
        text += "-vd %.3f %.3f %.3f  " % [c.zaxis.x,c.zaxis.y,c.zaxis.z]
        text += "-vu %.3f %.3f %.3f  " % [c.up.x,c.up.y,c.up.z]
        imgW = Sketchup.active_model.active_view.vpwidth.to_f
        imgH = Sketchup.active_model.active_view.vpheight.to_f
        aspect = imgW/imgH
        if c.perspective?
            type = '-vtv'
            if aspect > 1.0
                vv = c.fov
                vh = getFoVAngle(vv, imgH, imgW)
            else
                vh = c.fov
                vv = getFoVAngle(vh, imgW, imgH)
            end
        else
            type = '-vtl'
            vv = c.height*$UNIT
            vh = vv*aspect
        end
        text += "-vv %.3f -vh %.3f" % [vv, vh]
        text = "rvu #{type} " + text
        return text
    end
    
    def createViewFile(c, viewname)
        filename = getFilename("views/%s.vf" % viewname)
        if not createFile(filename, getViewLine(c))
            msg = "## Error: Could not create view file '#{filename}'"
            uimessage(msg)
            return msg
        else
            return "view=   #{viewname} -vf views/#{viewname}.vf" 
        end
    end
    
    def getFoVAngle(ang1, side1, side2)
        ang1_rad = ang1*Math::PI/180.0
        dist = side1 / (2.0*Math::tan(ang1_rad/2.0))
        ang2_rad = 2 * Math::atan2(side2/(2*dist), 1)
        ang2 = (ang2_rad*180.0)/Math::PI
        return ang2
    end
end
