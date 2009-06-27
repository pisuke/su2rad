require "exportbase.rb"
require "delauney_mod.rb"

class NumericImport < ExportBase
    
    include Delauney
    
    def initialize(filename='')
        @bbox = [0,0,1,1]   ## [xmin,ymin,xmax,ymax]
        @clevels = []       ## list of contour level heights
        @filename = ''      ## values file to be read
        @index_value = 6    ## index of column of df/lux values
        @_labelSide = '+x'  ## display labels to the left (-x) or right (+x)
        @_labelText = 'lux'
        @labelLeaderLength = 4
        @colorStyle = 'roygbiv'
        @alpha = 0.6        ## transparancy of surface colors 
        @lines = []         ## raw lines in values file
        @maxvalue = 0.0     ## max in values
        @scalevalue = 1     ## scale of surface 'height' (e.g. 500lx/m)
        @surface = nil      ## replaced with Sketchup group
        @zOffset = 0.0      ## config for offset of value scale
        @_clstep = 100.0
        if filename != ''
            loadFile(filename)
        end
    end

    def setCLStep
        steps = [0.1,0.2,0.5,1.0,2.0,5.0,10,20,50,100,200,500,1000,2000,5000,10000]
        step = 100.0
        steps.each { |step|
            if @maxvalue / step < 10
                uimessage("step value: '%.2f'" % step, 1)
                break
            end
        }
        @_clstep = step
    end
    
    def addContourLines
        printf "DEBUG: addContourLines\n"
        if @surface == nil
            return
        end
        @clevels = []
        v = 0
        while v < @maxvalue
            v += @_clstep
            z = v/@scalevalue + @zOffset
            @clevels.push([z,v])
        end
        s_ents = @surface.entities
        ents = Sketchup.active_model.entities
        cl = ents.add_group
        unit = getConfig('UNIT')
        @clevels.each { |z,v|
            p1 = [@bbox[0], @bbox[1], z/unit]
            p2 = [@bbox[2], @bbox[1], z/unit]
            p3 = [@bbox[2], @bbox[3], z/unit]
            p4 = [@bbox[0], @bbox[3], z/unit]
            face = cl.entities.add_face [p1,p2,p3,p4]
        }
        polys = []
        @surface.entities.each { |e|
            if e.class == Sketchup::Face
                polys.push(e)
            end
        }
        cl.entities.intersect_with(true, cl.transformation, @surface, @surface.transformation, true, polys)
        ents.erase_entities(cl)
        
        ## finally sort faces into groups    
        _addContourGroups
    end
    
    def _addContourGroups
        printf "DEBUG: _addContourGroups\n"
        ## create groups for contour bands and 'sort' faces into groups
        unit = getConfig('UNIT')
        levels = @clevels.collect { |z,v| z/unit } 
        step = levels[0]                ## XXX find better way to identify step
        
        ## add groups and store in hash indexed by height
        g_dflt = @surface.entities.add_group()
        g_dflt.name = "numeric_dflt"
        groupsHash = Hash.new(g_dflt)
        @clevels.each { |z,v|
            z -= 0.01                   ## reduce z for idx rounding
            idx = Integer( (z/unit)/step )
            g = @surface.entities.add_group()
            g.name = "%s_faces_%d" % [@_labelText, v]
            groupsHash["%02d" % idx] = g
        }
        
        ## faces can't be moved; so we recreate the face inside the
        ## new group and delete the old faces from the parent group
        faces_to_erase = []
        @surface.entities.each { |e|
            if e.class == Sketchup::Face
                z = e.bounds.center.to_a[2]
                idx = Integer(z/step)
                grp = groupsHash["%02d" % idx]
                f = grp.entities.add_face e.vertices
                f.edges.each { |edge| edge.soft=true }
                faces_to_erase.push(e)
            end
        }
        @surface.entities.erase_entities(faces_to_erase)
        if g_dflt.entities.length == 0
            @surface.entities.erase_entities([g_dflt])
        end
        
        ## print some stats for debugging
        if $SU2RAD_DEBUG
            printf "surface stats:\n"
            classes_in_surface = Hash.new(0)
            @surface.entities.each { |e|
                classes_in_surface["%s" % e.class] += 1
            }
            classes_in_surface.each { |k,v| printf " > class '%s': %d\n" % [k,v] }
        end
    end

    def addFalsecolor
        puts "DEBUG: addFalsecolor"
        if @surface == nil
            return
        end
        begin
            bands = {}
            pattern = "%s_faces" % @_labelText
            @surface.entities.each { |e|
                if e.class == Sketchup::Group
                    #puts "group.name='#{e.name}'"
                    if e.name and e.name.index(pattern) == 0
                        bands[e.name] = e
                    end
                end
            }
            
            ## get r,g,b for n materials from color gradient
            materials = Sketchup.active_model.materials
            names = bands.keys()
            names.sort!()
            names.each_index { |i|
                name = names[i]
                v = (i+0.5) / names.length
                r,g,b = _getColorByValue(v)
                m = materials[name] || materials.add(name)
                c = Sketchup::Color.new(r,g,b)
                c.alpha=@alpha
                m.color = c 
                printf "material: %s\n" % m
                bands[name].material = m
                #printf "%s (%.2f): %.2f %.2f %.2f\n" % [name,v,r,g,b] 
            }
            
        rescue => e
            uimessage("Error:\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")])
        end 
        puts "DEBUG: end addFalsecolor"
    end

    def _getColorByValue(value)
        if value == 0.0
            return [0,0,0]
        end
        ## add 0.5 at the top to get red, and limit bottom at x=1.7 to get purple
        if @colorStyle == 'roygbiv'
            shft = 0.5*value + 1.7*(1-value)
        else
            shft = value + 0.2 + 5.5*(1-value)
        end
        ## scale will be multiplied by the cos(x) + 1 
        ## (value from 0 to 2) so it comes up to a max of 255
        scale = 128;
        ## period is 2Pi
        period = 2*Math::PI
        ## x is place along x axis of cosine wave
        x = shft + value * period
        r = colorGradientProcess( ((Math.cos(x) + 1) * scale).floor )
        g = colorGradientProcess( ((Math.cos(x+Math::PI/2) + 1) * scale).floor  )
        b = colorGradientProcess( ((Math.cos(x+Math::PI) + 1) * scale).floor )
        return [r,g,b]
    end
    
    def colorGradientProcess(num)
        ## adjust lightness
        lightness = 0.4
        n = num + lightness * (256 - num)
        return n.floor
        ## turn to hex
        s = n.toString(16);
        ## if no first char, prepend 0
        s = s.length == 1 ? '0' + s : s;
        return s;		
    end
    
    def addLabels
        printf "DEBUG: addLabels\n"
        if @surface == nil
            return
        end
        points = {}
        values = {}
        @clevels.each { |z,v|
            key = "%.2f" % z
            points[key] = []
            values[key] = v
        }
        @surface.entities.each { |e|
            if e.class == Sketchup::Edge
                [e.start.position, e.end.position].each { |p|
                    z = "%.2f" % (p.z*getConfig('UNIT'))
                    if points.has_key?(z)
                        points[z].push([p.x,p.y,p.z])
                    end
                }
            end
        }
        if @_labelSide == '+x'
            dy = @labelLeaderLength
        else
            dy = -1*@labelLeaderLength
        end
        vector = Geom::Vector3d.new(0,dy,@labelLeaderLength)
        points.each_pair { |z,verts|
            if verts.length != 0
                verts.sort!
                if @_labelSide == '+x'
                    p = verts[-1]
                else
                    p = verts[0]
                end
                begin
                    point = Geom::Point3d.new(p[0], p[1], p[2])
                    text = @surface.entities.add_text("%d %s" % [values[z], @_labelText], point)
                    text.vector = vector
                    text.leader_type = 1
                    text.display_leader = true
                    text.arrow_type = 0
                rescue
                    uimessage("Error: could not create label for contour line at '#{z}'", -2)
                end
            end
        }
        return true
    end
    
    def loadFile(filename='')
        if filename == ''
            filename = UI.openpanel("import numeric results", '', '')
        end
        if not filename
            uimessage("import canceled", 0)
            return
        end
        f = File.new(filename)
        text = f.read()
        @lines = text.split("\n")
        f.close()
        @filename = filename
        cleanLines()
        getMaxValue()
        setCLStep()
    end
    
    def confirmDialog
        if @lines.length == 0
            return
        end
        
        ## prepare options
        options = [['contour step', @_clstep,    ''],
                   ['add lables',   'yes',       'yes|no'],
                   ['label text',   @_labelText, ''],
                   ['label side',   @_labelSide, '+x|-x'],
                   ['add colour',   'yes',       'yes|no'],
                   ['alpha value',  @alpha,      '0.1|0.2|0.3|0.4|0.5|0.6|0.7|0.8|0.9|1.0']] 
        prompts = options.collect { |o| o[0] }
        values  = options.collect { |o| o[1] }
        choices = options.collect { |o| o[2] }
        
        ## show and evaluate dialog
        dlg = UI.inputbox(prompts,values,choices, 'graph options')
        if not dlg
            uimessage("import canceled", 0)
            return
        end
        begin
            @_clstep = dlg[0].to_f
        rescue => e
            uimessage("Error evaluating option:\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")])
        end
        _doLables = dlg[1]
        @_labelText = dlg[2]
        @_labelSide = dlg[3]
        _doFalsecolor = dlg[4]
        @alpha = dlg[5].to_f
        
        ## crate graph with new options
        begin
            createMesh()
            if @surface == nil
                uimessage("error: no surface created", -2)
                return
            end
            addContourLines()
            if _doLables == 'yes'
                addLabels()
            end
            if _doFalsecolor == 'yes'
                addFalsecolor()
            end
        rescue => e
            msg = "Error creating graph:\n%s\n\n%s\n" % [$!.message,e.backtrace.join("\n")]
            uimessage(msg, -2)
        end
    end
    
    def confirmDialog_OLD
        msg =  "import mesh of #{@lines.length} values?"
        msg += "\nmax = %.2f" % @maxvalue
        msg += "\nscale = %.2f/m" % @scalevalue
        result = UI.messagebox msg, MB_OKCANCEL, "confirm import"
        if result == 1
            createMesh()
            addContourLines()
            addLabels()
        else
            uimessage("import canceled", 0)
        end
    end
    
    def cleanLines
        newlines = []
        @lines.each { |l|
            parts = l.split()
            begin
                parts.collect! { |p| p.to_f }
                newlines.push(parts)
            rescue
                uimessage("line ignored: '#{l}'", 3)
            end
        }
        ## find index of column with illum values (4 or 7)
        h = Hash.new(0)
        newlines.each { |l|
            h[l.length] = h[l.length] + 1
        }
        if h[4] > h[7]
            @index_value = 3
        end
        uimessage("values found at column index %d" % @index_value, 1) 
        @lines = newlines
    end
    
    def getMaxValue
        if @lines.length == 0
            return
        end
        unit = getConfig('UNIT')
        xs = @lines.collect { |l| l[0] }
        ys = @lines.collect { |l| l[1] }
        xs.sort!
        ys.sort!
        @bbox = [xs[0]/unit, ys[0]/unit, xs[-1]/unit, ys[-1]/unit]
        zs = @lines.collect { |l| l[2] }
        if @zOffset == nil
            n = 0
            zs.each { |z| n += z }
            @zOffset = n / zs.length.to_f
            uimessage("z offset set to '%.2f'" % @zOffset, 0) 
        else
            uimessage("z offset = '#{@zOffset}'", 0)
        end
        values = @lines.collect { |l| l[@index_value] }
        values.sort!
        @maxvalue = values[-1]
        uimessage("maximum value: %.2f" % @maxvalue, 2) 
        max = values[-1]
        divider = 1
        while max > 10:
            max = max / 10.0
            divider *= 10
        end
        if max > 5
            step = 0.2
        elsif max > 2
            step = 0.4
        elsif max > 1
            step = 1.0
        end
        @delta = step
        @scalevalue = divider.to_f / step
    end
    
    def createMesh
        if @lines.length == 0
            return
        end
        uimessage("processing %d values" % @lines.length, 2) 
        points = []
        @lines.each { |l|
            x = l[0]
            y = l[1]
            z = @zOffset
            v = l[@index_value]
            dz = v / @scalevalue
            points.push([x,y,z+dz])
        }
        tris = triangulate(points)
        suPoints = points.collect { |p| Geom::Point3d.new(p[0], p[1], p[2]) }
        mesh = Geom::PolygonMesh.new(points.length, tris.length)
        tris.each { |v|
            mesh.add_polygon(suPoints[v[0]], suPoints[v[1]], suPoints[v[2]])
        }
        scaletrans = Geom::Transformation.new(1/getConfig('UNIT'))
        mesh.transform!(scaletrans)
        uimessage("created mesh", 2) 
        @surface = Sketchup.active_model.entities.add_group
        @surface.entities.add_faces_from_mesh(mesh)
        name = remove_spaces(File.basename(@filename))
        @surface.name = name
        uimessage("added surface group '#{name}' to scene", 2) 
    end
        
end






