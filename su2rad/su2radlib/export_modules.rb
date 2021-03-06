
module InterfaceBase

    def initLog(lines=[])
        $SU2RAD_LOG = lines
    end
   
    def getConfig(key)
        return $SU2RAD_CONFIG.get(key)
    end
    
    def getNestingLevel
        return 0
    end
    
    def setConfig(key,value)
        $SU2RAD_CONFIG.set(key, value)
    end
    
    def uimessage(msg, loglevel=0)
        begin
            prefix = "  " * getNestingLevel()
            levels = ["I", "V", "D", "3", "4", "5", "E", "W"]  ## [0,1,2,-2,-1]
            line = "%s[%s] %s" % [prefix, levels[loglevel], msg]
            if loglevel <= $SU2RAD_LOGLEVEL
                Sketchup.set_status_text(line.strip())
                msg.split("\n").each { |l|  printf "%s[%s] %s\n" % [prefix,levels[loglevel],l] }
                $SU2RAD_LOG.push(line)
            end
            if loglevel == -2
                $SU2RAD_COUNTER.add('errors')
            elsif loglevel == -1
                $SU2RAD_COUNTER.add('warnings')
            end
        rescue => e
            printf "## %s" % $!.message
            printf "## %s" % e.backtrace.join("\n## ")
            printf "\n[uimessage rescue] #{msg}\n"
        end
    end
    
    def writeLogFile
        line  = "###  finished: %s  ###" % Time.new()
        line2 = "###  %s  ###" % $SU2RAD_COUNTER.getStatusLine()
        $SU2RAD_LOG.push(line)
        $SU2RAD_LOG.push(line2)
        logname = File.join('logfiles', "%s_export.log" % getConfig('SCENENAME'))
        logname = getFilename(logname)
        if not createFile(logname, $SU2RAD_LOG.join("\n"))
            uimessage("Error: Could not create log file '#{logname}'")
            line = "### creating log file failed: %s  ###" % Time.new()
            printf "%s\n" % line
            Sketchup.set_status_text(line)
        else
            printf "%s\n" % line
            printf "%s\n" % line2
        end
    end
end



module JSONUtils
    
    def escapeCharsJSON(s)
        s.gsub('"','\\\\\\"').gsub("'","\\\\'")
        return s
    end

    def replaceChars(name)
        ## TODO: replace characters in name for save html display
        return name
    end

    def decodeJSON(string)
        string.gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
            [$1.delete('%')].pack('H*')
        end
        return string
    end
    
    def encodeJSON(string)
        string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
            '%' + $1.unpack('H2' * $1.size).join('%').upcase
        end
        return string
    end
    
    def urlEncode(string)
        ## URL-encode from Ruby::CGI
        string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
            '%' + $1.unpack('H2' * $1.size).join('%').upcase
        end.tr(' ', '+')
    end
    
    # ecapeHTML from Ruby::CGI
    #
    # Escape special characters in HTML, namely &\"<>
    #   CGI::escapeHTML('Usage: foo "bar" <baz>')
    #      # => "Usage: foo &quot;bar&quot; &lt;baz&gt;"
    def JSONUtils::escapeHTML(string)
        string.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
    end
    
    def urlDecode(string)
        ## URL-decode from Ruby::CGI
        string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
            [$1.delete('%')].pack('H*')
        end
    end
    
    def getJSONDictionary(dict)
        if(dict == nil)
            return "[]"
        else
            json = "["
            dict.each_pair { |k,v|
                json += "{\"name\":%s,\"value\":%s}," % [toStringJSON(k),toStringJSON(v)]
            }
            json += ']'
        end
        return json
    end

    def toStringJSON(obj)
        if obj.class == Array
            str = "[%s]" % obj.collect{ |e| "%s" % toStringJSON(e) }.join(",")
        elsif obj.class == FalseClass
            str = 'false'
        elsif obj.class == Fixnum or obj.class == Bignum
            str = "%s" % obj
        elsif obj.class == Float
            str = "%f" % obj
        elsif obj.class == Hash
            str = "{%s}" % obj.collect{ |k,v| "%s:%s" % [toStringJSON(k),toStringJSON(v)] }.join(",")
        elsif obj.class == String
            str = "\"%s\"" % obj.to_s
        elsif obj.class == TrueClass
            str = 'true'
        elsif obj.class == Geom::Transformation
            str = obj.to_a.to_s
        else
            str = "\"%s\"" % obj
        end
        return str
    end

    def pprintJSON(json, text="\njson string:")
        ## prettyprint JSON string
        printf "#{text}\n"
        json = json.gsub(/#COMMA#\{/,",\{")
        json = json.gsub(/,/,"\n")
        lines = json.split("\n")
        indent = ""
        lines.each { |line|
            print "%s%s\n" % [indent,line]
            if line.index('{') != nil
                indent += "  "
            elsif line.index('}') != nil
                indent = indent.slice(0..-3)
            end
        }
        printf "\n"
    end
    
    def setOptionsFromString(dlg, params, verbose=false)
        ## set export options from string <p>
        pairs = params.split("&")
        pairs.each { |pair|
            k,v = pair.split("=")
            old = eval("@%s" % k)
            if verbose
                uimessage(" -  %s (old='%s')" % [pair, old], 2)
            end
            if (v == 'true' || v == 'false' || v =~ /\A[+-]?\d+\z/ || v =~ /\A[+-]?\d+\.\d+\z/)
                val = eval("%s" % v)
            else
                val = v
                v = "'%s'" % v
            end
            if val != old
                eval("@%s = %s" % [k,v])
                msg = "#{self.class} new value for @%s: %s" % [k,v]
                uimessage(msg)
            end
        }
    end

    def test_toStringJSON()
        i = 17
        f = 3.14
        s = "string"
        a = [1, 2.3, "four"]
        h = { "one" => 1, "two" => 2, "three" => [1,2,3], "nested" => { "n1" => 11, "n2" => 22 } }
        obj = { "int" => i, "float" => f, "string" => s, "array" => a, "hash" => h }
        printf toStringJSON(obj) + "\n"
    end 

    def vectorToJSON(v)
        return "[%.3f,%.3f,%.3f]" % v
    end
    
end



module RadiancePath
    
    def append_paths(p,f)
        if p[-1,1] == "\\" or p[-1,1] == "/"
            p+f
        else
            p+"\\"+f
        end
    end
    
    def clearDirectory(scene_dir)
        uimessage("clearing directory '#{scene_dir}'",1)
        if not File.exists?(scene_dir)
            return
        end
        Dir.foreach(scene_dir) { |f|
            fpath = File.join(scene_dir, f)
	    if f == '.' or f == '..'
		next
            elsif f[0,1] == '.'
                next
            elsif f == 'textures'
                uimessage("skipping directory 'textures'", 2)
                next
            elsif FileTest.directory?(fpath) == true
                clearDirectory(fpath)
                begin
                    Dir.delete(fpath)
                    uimessage("deleted directory '#{fpath}'", 2)
                rescue
                    uimessage("directory '#{fpath}' not empty")
                end
            elsif FileTest.file?(fpath) == true
		File.delete(fpath)
                uimessage("deleted file '#{fpath}'", 3)
            else
                uimessage("unexpected entry in file system: '#{fpath}'")
            end
        }
    end

    def createDirectory(path)
        if File.exists?(path) and FileTest.directory?(path)
            return true
        else
            uimessage("Creating directory '%s'" % path)
        end
        dirs = []
        while not File.exists?(path)
            dirs.push(path)
            path = File.dirname(path)
        end
        dirs.reverse!
        dirs.each { |p|
            begin 
                Dir.mkdir(p)
            rescue
                uimessage("ERROR creating directory '%s'" %  p, -2)
                return false
            end
        }
    end
   
    def createFile(filename, text)
        ## write 'text' to 'filename' in a save way
        path = File.dirname(filename)
        createDirectory(path)
        if not FileTest.directory?(path)
            return false
        end
        begin
            f = File.new(filename, 'w')
            f.write(text)
            f.close()
            uimessage("created file '%s'" % filename, 1)
        rescue => e
            uimessage("could not create file '%s': %s" % [filename, $!.message], -2)
            return false
        end
        $createdFiles[filename] = 1
        $SU2RAD_COUNTER.add('files')
        return true
    end 
    
    def getFilename(name)
        return File.join(getConfig('SCENEPATH'), name)
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
                cmd = "\"%s\" \"#{objfile}\" \"#{rtmfile}\"" % getConfig('OBJ2MESH')
                result = runSystemCmd(cmd)
                if result == true and File.exists?(rtmfile)
                    return "\n#{name} mesh #{name}_obj\n1 objects/#{name}.rtm\n0\n0"
                else
                    msg = "Error: could not convert obj file '#{objfile}'"
                    uimessage(msg, -2)
                    return "## #{msg}"
                end
            rescue => e
                msg = "Error converting obj file '#{name}.obj'\n%s\n%s" % [$!.message,e.backtrace.join("\n")]
                uimessage(msg, -2)
                return "## #{msg}"
            end
        end
    end
    
    def remove_spaces(s)
        ## remove spaces and other funny chars from names
        for i in (0..s.length)
            if s[i,1] == " " 
                s[i] = "_" 
            end 
        end
        return s.gsub(/\W/, '')
    end
    
    def renameExisting(sceneDir)
        if File.exists?(sceneDir)
            t = Time.new()
            newname = sceneDir + t.strftime("_%y%m%d_%H%M%S")
            begin
                File.rename(sceneDir, newname)
                uimessage("renamed scene directory to '%s'" % newname)
            rescue => e
                uimessage("could not rename directory '%s':\n%s" % [sceneDir, $!.message])
                return false
            end
        end
    end
    
    def runSystemCmd(cmd)
        if $SU2RAD_PLATFORM == 'WIN'
           cmd.gsub!(/\//, '\\')
        end
        uimessage("system cmd= %s" % cmd, 3)
        result = system(cmd)
        uimessage("    result= %s" % result, 3)
        return result
    end

    def setExportDirectory
        ## get name of subdir for Radiance file structure
        page = Sketchup.active_model.pages.selected_page
        if page != nil
            name = remove_spaces(page.name)
        else
            name = "unnamed_scene"
        end
        path = Sketchup.active_model.path
        if path == ''
            ## use user home directory or temp
            if ENV.has_key?('HOME')
                path = ENV['HOME']
            elsif ENV.has_key?('USERPROFILE')
                path = ENV['USERPROFILE']
            elsif ENV.has_key?('HOMEPATH')
                ## home path missing drive letter!?
                path = ENV['HOMEPATH']
            elsif ENV.has_key?('TEMP')
                path = ENV['TEMP']
            end
            path = File.join(path, 'unnamed_project')
        else
            ## remove '.skp' and use as directory
            fname = File.basename(path)
            if fname =~ /\.skp\z/i
                fname = fname.slice(0..-5)
            end
            path = File.join(File.dirname(path), fname)
            setConfig('PROJECT', remove_spaces(fname))
        end
        ## apply to PATHTMPL
        tmpl = getConfig('PATHTMPL')
        tmpl = tmpl.gsub(/\$FILE/, path)
        tmpl = tmpl.gsub(/\$PAGE/, name)
	tmpl = cleanPath(tmpl)
        setConfig('SCENEPATH', File.dirname(tmpl))
        setConfig('SCENENAME', File.basename(tmpl,'.rif'))
    end

    def cleanPath(path)
        if path.slice(-1,1) == File::SEPARATOR
            path = path.slice(0,path.length-1)
        end
	path = path.gsub(/\\/, File::SEPARATOR)
        return path
    end
    
end




