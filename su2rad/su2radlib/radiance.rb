require 'su2radlib/export_modules.rb'

module Radiance
    
    Radiance::Keywords_Geometry = {'bubble'   => true,     'cone' => true,     'cup' => true,
                                   'cylinder' => true, 'instance' => true, 'polygon' => true,
                                   'ring'     => true,   'sphere' => true,    'tube' => true}
    Radiance::Keywords_Material = {'antimatter' => true, 'dielectric' => true, 
                                   'interface'  => true,      'glass' => true,
                                   'glow'       => true,      'light' => true,
                                   'metal'      => true,     'metal2' => true,
                                   'mirror'     => true,       'mist' => true,
                                   'prism1'     => true,     'prism2' => true,
                                   'plastic'    => true,   'plastic2' => true,
                                   'trans'      => true,     'trans2' => true}
    Radiance::Keywords_Pattern  = {'BRTDfunc'   => true,
                                   'brightfunc' => true, 'brightdata' => true, 'brighttext' => true,
                                   'colorfunc'  => true,  'colordata' => true,  'colorpict' => true, 'colortext' => true,
                                   'metfunc'    => true,    'metdata' => true,
                                   'plasfunc'   => true,   'plasdata' => true,
                                   'transfunc'  => true,  'transdata' => true,
                                   'mixfunc'    => true,    'mixdata' => true, 'mixpict' => true, 'mixtext' => true,
                                   'texfunc'    => true,    'texdata' => true}
    Radiance::Keywords_Other  = {'void'  => true,  'alias' => true}
    Radiance::Keywords_Source = {'illum' => true, 'source' => true, 'spotlight' => true}

    class Radiance::Material
        
        attr_reader :name, :comment, :defType, :matType, :text, :preview, :rest, :valid, :required, :filepath
        attr_writer :filepath

        def initialize(text)
            @name = ''
            @comment = ''
            @defType = 'material'
            @matType = nil
            @required = 'void'
            @filepath = ''
            @text = ''
            @rest = ''
            @_group = ''
            @preview = ''
            begin
                @valid = parseText(text)
            rescue => e
                printf "Error in text: '#{text}'\n"
                #msg = "%s\n  %s" % [$!.message,e.backtrace.join("\n  ")]
                #printf "\n#{msg}\n"
                @valid = false
            end
        end
        
        def inspect
            if valid?
                return "#<#{self.class} name=#{@name} type=#{@matType}>"
            else
                return "#<#{self.class} valid=false>"
            end
        end
        
        def getType
            return @matType
        end
        
        def getGroup
            if @_group != ''
                return @_group
            elsif @matType == 'light' || @matType == 'glow'
                return 'light'
            elsif @matType =~ /2\z/
                return $`
            else 
                return @matType
            end
        end
        
        def getPreviewPath
            if @preview != ''
                return @preview
            end
            if @filepath[-4,1] == "."
                filepath = @filepath[0..-5]
            else
                filepath = @filepath
            end
            return File.join(filepath + ".preview", @name + ".jpg")
        end

        def identifier
            return @name
        end
       
        def parseText(text)
            begin
                @valid = _parseText(text)
            rescue => e
                printf "\nError in text: '#{text}'\n"
                #msg = "%s\n%s" % [$!.message,e.backtrace.join("\n")]
                #printf "\n#{msg}\n"
                @valid = false
                @name = ''
                @text = ''
                @rest = text
                @matType = nil
            end
        end
        
        def _parseText(text)
            defparts = []
            parts = text.split()
            valid = false
            @required = parts[0]
            @matType = parts[1]
            @name = parts[2]
            if @matType == 'light' or @matType == 'glow'
                @defType = 'light'
            elsif Radiance::Keywords_Pattern.has_key?(@matType)
                @defType = 'pattern'
            end
            ## now read details 
            if @matType == 'alias'
                @required = parts[3]
                @rest = parts[4..parts.length].join(' ')
                @text = "void alias #{@name} #{@required}"
                @defType = 'alias'
                valid = true
            else
                idx1 = 3
                step1 = Integer(parts[idx1])
                idx2 = 4 + step1
                step2 = Integer(parts[idx2])
                idx3 = 5 + step1 + step2
                nargs = Integer(parts[idx3])
                n = idx3 + nargs
                line1 = parts[idx1...idx2].join(' ')
                line2 = parts[idx2...idx3].join(' ')
                line3 = parts[idx3..n].join(' ')
                @text = ["#{@required} #{@matType} #{@name}", line1, line2, line3].join("\n")
                if parts.length > n+1
                    @rest = parts[n+1..parts.length].join(' ')
                end
                valid = true
            end
            @text.strip!
            if @rest.strip == ''
                @rest = nil
            end
            return valid
        end
        
        def getText(singleline=false)
            ## return formated text with comments or on single line
            if singleline
                return @text.split().join(' ')
            elsif @comment != ''
                return "## %s\n%s\n%s" % [@name, @comment, @text]
            else
                return "## %s\n%s" % [@name,@text]
            end
        end

        def setFilepath(filepath)
            @filepath = filepath
            if File.exists?(getPreviewPath())
                @preview = getPreviewPath()
            end
        end

        def setGroup(group)
            @_group = group
        end
        
        def valid?
            return @valid
        end
        
    end
   
    
    class Radiance::MaterialLibrary

        include RadiancePath

        def initialize(path, log=$stdout)

            @log = log
            @materials = {}
            @files = []
            @defaultPath = path
            addPath(path)
            uimessage("=> %s" % getStats())
        end
        
        def inspect
            return "#<MaterialLibrary materials=%d files=%d" [@materials.length,@files.length]
        end
        
        def addPath(path)
            if FileTest.file?(path)
                updateFromFile(path)
            elsif FileTest.directory?(path)
                uimessage(" searching in '#{path}'", 2)
                paths = []
                Dir.foreach(path) { |f|
                    filePath = File.join(path, f)
                    if f.slice(0,1) == '.'
                        next
                    elsif FileTest.directory?(filePath) == true
                        addPath(filePath)
                    elsif f.downcase.slice(-4,4) == '.rad'
                        updateFromFile(filePath)
                    elsif f.downcase.slice(-4,4) == '.mat'
                        updateFromFile(filePath)
                    end
                }
            else
                uimessage("Warning: not file or directory: '#{path}'", -1)
            end
        end
       
        def createMaterialPreview(mname)
            uimessage("TEST: createMaterialPreview('%s')" % mname, 2) 
            definition = getMaterialWithDependencies(mname)
            uimessage("material definition:\n%s" % definition, 2)
            material = get(mname)
            puts "material:", material
            if material
                path = _createMaterialPreviewImage(mname, definition, material.getPreviewPath)
                return path
            else
                return ""
            end
        end
        
        def _createMaterialPreviewImage(mname, definition, path)
            uimessage("TEST: createMaterialPreviewImage('%s')" % path, 2)
            uimessage("material definition:\n#{definition}", 2)
            lines = ["#!gensky 3 21 12:00 +i",
                     "void light solar 0 0 3 1.04e+06 1.04e+06 1.04e+06",
                     "solar source sun 0 0 4 0.068 -0.62 0.78 0.5",
                     "void brightfunc skyfunc 2 skybr skybright.cal 0 7 4 2.27e+01 7.6e+00 9.73e-01 0.0678 -0.612 0.784",
                     "skyfunc glow skyglow 0 0 4 1 1 1 0",
                     "skyglow source sky 0 0 4 0 0 1 180",
                     "skyfunc glow groundglow 0 0 4 0.2 0.2 0.2 0",
                     "groundglow source ground 0 0 4 0 0 1 180",
                     "void plastic abcdefg 0 0 5 0.8 0.8 0.8 0 0",
                     "abcdefg polygon square 0 0 12 -5 -5 -1 -5 5 -1 5 5 -1 5 -5 -1",
                     definition,
                     "%s sphere testball 0 0 4 0 0 0 1.0" % mname]
            dirname = File.dirname(path)
            if createDirectory(dirname)
                if createFile(path + ".rad", lines.join("\n"))
                    script = ["cd '#{dirname}'",
                              "/usr/local/bin/oconv '#{path}.rad' > '#{path}.oct'",
                              "/usr/local/bin/rpict -x 200 -y 200 -ab 1 -vtv -vp 0 -3 1.5 -vd 0 1 -0.5 -vu 0 0 1 -vv 45 -vh 45 '#{path}.oct' > '#{path}.unf'",
                              "/usr/local/bin/pfilt '#{path}.unf' > '#{path}.hdr'",
                              "/usr/local/bin/ra_ppm '#{path}.hdr' '#{path}.ppm'",
                              "/usr/local/bin/convert -quality 90 '#{path}.ppm' '#{path}'"]
                    ['rad', 'oct', 'unf', 'hdr', 'ppm'].each { |ext|
                        script.push("rm '#{path}.#{ext}'")
                    }
                    ENV['RAYPATH'] = '/usr/local/lib/ray'
                    script.each { |cmd|
                        runSystemCmd(cmd)
                    }
                    return path
                    if createFile(path + ".sh", script.join("\n"))
                        if runSystemCmd("bash '#{path}.sh' > '#{path}.log'") != false
                            #File.delete(path + ".sh")
                            #File.delete(path + ".rad")
                            return path
                        else
                            uimessage("Error running bash file '#{path}.sh'", -2)
                        end
                    end
                else
                    uimessage("Error: Could not create file '#{path}.rad'", -2)
                end
            else
                uimessage("Error: Could not create directory '#{dirname}'", -2)
            end
            return false
        end

        def getStats
            counts = Hash.new(0)
            @materials.each_value { |m|
                counts[m.getType()] += 1
                if not isDefined?(m)
                    counts['undefined'] += 1
                end
            }       
            text = "materials total: %d\n" % @materials.length
            counts.each_pair { |k,v|
                text += "%15s: %d\n" % [k,v]
            }
            return text
        end
        
        def get(mname)
            radname = mname.gsub(/\s+/, '_').gsub(/\W/, '')
            return @materials[radname]
        end
        
        def getByName(mname)
            return get(mname)
        end
        
        def getMaterials
            return @materials.values
        end
        
        def getMaterialWithDependencies(mname)
            radMat = get(mname)
            if not radMat
                return false
            end
            mdef = ""
            while radMat 
                mdef = "%s\n%s" % [radMat.getText(), mdef]
                radMat = get(radMat.required)
            end
            return mdef.strip()
        end
        
        def isDefined?(m)
            req = m.required
            if req == 'void'
                return true
            elsif @materials.has_key?(req)
                return isDefined?(@materials[req])
            else
                return false
            end
        end
        
        def update(dict)
            if dict.class == Hash
                dict.each_pair { |k,m|
                    if m.getGroup() == 'alias' && @materials.has_key?(m.required)
                        req = @materials[m.required]
                        m.setGroup(req.getGroup())
                    end
                    @materials[k] = m
                }
            else
                uimessage("Error: can't update from object type '#{dict.class}'", -2)
            end
        end
        
        def updateFromFile(filepath)
            s = Radiance::RadianceScene.new(filepath)
            sMats = s.materials
            if sMats.length > 0
                uimessage(" > %3d materials in file '%s'" % [sMats.length, filepath], 1)
                #TODO search for preview images
                update(sMats)
                @files.push(filepath)
            else
                uimessage("no materials found in '#{filepath}'", 2)
            end
        end
        
        def uimessage(msg, level=0)
            @log.write("%s\n" % msg)
        end
        
    end

    
    class Radiance::RadianceScene
        
        def initialize(filename=nil)
            @_name = 'undefined'
            @_definitions = []
            @materials = []
            if filename and readFile(filename)
                @_name = filename
            end
        end

        def inspect
            nMat = @materials.length
            nGeo = @_definitions.length - nMat
            return "#<RadianceScene '%s' elements=%d, materials=%d>" % [name,nGeo,nMat]
        end 
        
        def getText
            lines = @_definitions.collect { |e| e.join("\n") }
            text = "##\n## %s\n##\n\n%s" % [@filename, lines.join("\n")]
            return text
        end
        
        def materials
            d = {}
            @materials.each { |m| d[m.name] = m }
            return d
        end
        
        def name
            if @_name == 'undefined'
                return 'undef_%s' % self.object_id
            else
                return @_name
            end
        end
        
        def print
            print getText()
        end

        def readFile(filename)
            begin
                lines = File.new(filename, 'r').readlines()
                text = purgeLines(lines)
                parseSceneText(text, filename)
            rescue => e
                msg = "%s\n  %s" % [$!.message,e.backtrace.join("\n  ")]
                printf "\n#{msg}\n"
                return false
            end
        end

        def _getKeywords(materials_only=false)
            keywords = {'alias' => true}
            keywords.update( Radiance::Keywords_Material )
            keywords.update( Radiance::Keywords_Pattern )
            if materials_only
                return keywords
            end
            keywords.update( Radiance::Keywords_Geometry )
            keywords.update( Radiance::Keywords_Pattern )
            return keywords
        end 
        
        def parseSceneText(text, filename)
            if text.class == Array
                text = text.join(" ")
            end
            words = text.split()
            if words == []
                return
            end
            
            keywords = _getKeywords()
            elements = []
            _current = []
            _oldword = words[0]
            words.each { |word|
                if keywords.has_key?(word)
                    if _current.length > 3
                        _current.pop()
                        elements.push(_current)
                    end
                    _current = [_oldword, word]
                else
                    _current.push(word)
                end
                _oldword = word
            }
            elements.push(_current)
            matTypes = _getKeywords(true)
            elements.each { |line|
                if line.length > 2 and matTypes.has_key?(line[1])
                    m = Radiance::Material.new(line.join(" "))
                    if m.valid?
                        m.setFilepath(filename)
                        @materials.push(m)
                    end
                end
                @_definitions.push(line)
            }
        end

        def purgeLines(lines)
            #lines = find_comments(lines)
            lines.collect! { |l| l.split('#')[0] }
            lines.compact!
            lines.collect! { |l| l.split().join(' ') }
            lines.collect! { |l| l if l != ''}
            lines.compact!
            return lines
        end
        
    end
 

    class Radiance::RifFile

        attr_reader :settings, :filename
            
        def initialize(path='')
            @filename = ''
            @_isValid = true
            @settings = getDefaults()
            if path != ''
                readFile(path)
            end
        end

        def isValid?
            ## return true if file is a correct rif file
            return false
        end
        
        def getDefaults
            d = Hash.new()
            d["Quality"] = 'medium'
            d["Detail"] = 'medium'
            d["Variability"] = 'high'
            d["Indirect"] = 2
            d["Penumbras"] = true
            d["ImageType"] = 'normal'
            d["ImageSizeX"] = 512
            d["ImageSizeY"] = 512
            d["ZoneSize"] = 10.0
            d["ZoneType"] = 'exterior'
            d["Report"] = 0
            d["ReportFile"] = getConfig('SCENENAME') + '.log'
            d["render"] = '' 
            return d
        end
        
        def readFile(path)
            @_isValid = false
            printf "TODO: RifFile.parseFile('%s')\n" % path
            #@_isValid = true
            @filename = path
        end
    end
    
end



module RadianceUtils

    # remove characters not allowed in Radiance from <name>
    def getRadianceIdentifier(name)
        newname = ""
        name.each_byte { |b|
            if b.chr() =~ /[\w.-]/
                newname += b.chr()
            end
        }
        return newname
    end
    
    # check in <word> is key word used in Radiance
    def isRadianceKeyword?(word)
        isKey = false;
        isKey = Radiance::Keywords_Geometry[word] || isKey
        isKey = Radiance::Keywords_Material[word] || isKey
        isKey = Radiance::Keywords_Pattern[word] || isKey
        isKey = Radiance::Keywords_Other[word] || isKey
        isKey = Radiance::Keywords_Source[word] || isKey
        return isKey
    end

    # test if transformation can be created with xform (uniform scale etc)
    def isRadianceTransformation?(trans)
        a = trans.to_a
        vx = Geom::Vector3d.new(a[0..2])
        vy = Geom::Vector3d.new(a[4..6])
        vz = Geom::Vector3d.new(a[8..10])
        lengths = [vx.length, vy.length, vz.length]
        sorted = lengths.sort
        diff = sorted[2] - sorted[0]
        if diff > 0.01
            uimessage("  scale not uniform: sx=%.2f sy=%.2f sz=%.2f\n" % lengths, 2)
            return false
        end
        return true
    end
    
    # return xform command for transformation matrix <trans>
    def xformFromReplmarks(trans, filename, objname, scale)
        #TODO: get mirror axes from trans
        mirror = ""
        
        ## scale is calculated by replmarks
        ## we just check for extrem values
        #a = trans.to_a
        #scale = Geom::Vector3d.new(a[0..2])
        #if scale.length > 10000 or scale.length < 0.0001
        #    uimessage("Warning unusual scale (%.3f) for object '%s'" % [scale.length, objname]) 
        #end
        
        ## transformation
        scaletrans = Geom::Transformation.new(1/scale)
        trans = trans * scaletrans
        a = trans.to_a
        o = a[12..14]
        vx = [o[0]+a[0], o[1]+a[1], o[2]+a[2]]
        vy = [o[0]+a[4]*0.5, o[1]+a[5]*0.5, o[2]+a[6]*0.5]
        marker = "replaceme polygon #{objname}\n0\n0\n9\n"
        marker += "%.6f %.6f %.6f\n" % o
        marker += "%.6f %.6f %.6f\n" % vx 
        marker += "%.6f %.6f %.6f\n" % vy
        
        if filename =~ /\.oct\z/i
            cmd = "echo '#{marker}' | replmarks -s 1.0 -i #{filename} replaceme"
        elsif filename =~ /\.msh\z/i
            cmd = "echo '#{marker}' | replmarks -s 1.0 -I #{filename} replaceme"
        else
            cmd = "echo '#{marker}' | replmarks -s 1.0 -x #{filename} replaceme"
        end
        uimessage("xform cmd='#{cmd}'", 4)
        f = IO.popen(cmd)
        lines = f.readlines
        f.close()
        begin
            xform = lines[2].strip()
            parts = xform.split()
            p1 = parts[0..2]
            p2 = parts[3..30]
            xform = p1.join(" ") + " #{mirror} " + p2.join(" ")
        rescue
            xform = "## ERROR: could not generate '!xform' command for file '#{filename}'"
        end
        return xform

    end
end 



