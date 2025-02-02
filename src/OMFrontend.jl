"
  An experimental Julia frontend for the Modelica language
"
module OMFrontend

import Absyn
import SCode
import OpenModelicaParser
using MetaModelica

include("main.jl")

#= Cache for NFModelicaBuiltin. We only use the result once! =#
"""
Cache for NFModelicaBuiltin.
This cache is initialized when the module is loaded.
"""
const NFModelicaBuiltinCache = Dict()

"""
  This function loads builtin Modelica libraries.
"""
function __init__()
  if ! haskey(NFModelicaBuiltinCache, "NFModelicaBuiltin")
    #= Locate the external libraries =#
    packagePath = dirname(realpath(Base.find_package("OMFrontend")))
    packagePath *= "/.."
    pathToLib = packagePath * "/lib/NFModelicaBuiltin.mo"
    #= The external C stuff can be a bit flaky.. =#
    GC.enable(false) 
    p = parseFile(pathToLib, 2 #== MetaModelica ==#)
    @debug "SCode translation"
    s = OMFrontend.translateToSCode(p)
    NFModelicaBuiltinCache["NFModelicaBuiltin"] = s
    #=Enable GC again.=#
    GC.enable(true)
  end
end

function parseFile(file::String, acceptedGram::Int64 = 1)::Absyn.Program
  return OpenModelicaParser.parseFile(file, acceptedGram)
end

function translateToSCode(inProgram::Absyn.Program)::SCode.Program
  return Main.AbsynToSCode.translateAbsyn2SCode(inProgram)
end

"""
  Instantiates a SCode program.
"""
function instSCode(inProgram::SCode.Program)
end


"""
  Instantiates and translates to DAE.
  The element to instantiate should be provided in the following format:
  <component>.<component_1>.<component_2>...
"""
function instantiateSCodeToDAE(elementToInstantiate::String, inProgram::SCode.Program)
  # initialize globals
  Main.Global.initialize()
  # make sure we have all the flags loaded!
#  Main.Flags.new(Flags.emptyFlags)
  local builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  local program = listAppend(builtinSCode, inProgram)
  local path = Main.AbsynUtil.stringPath(elementToInstantiate)
  Main.instClassInProgram(path, program)
end

"""
  Instantiates and translates to the flat model representation
  The element to instantiate should be provided in the following format:
  <component>.<component_1>.<component_2>...
"""
function instantiateSCodeToFM(elementToInstantiate::String, inProgram::SCode.Program)
  # initialize globals
  Main.Global.initialize()
  # make sure we have all the flags loaded!
#  Main.Flags.new(Flags.emptyFlags)
  local builtinSCode = NFModelicaBuiltinCache["NFModelicaBuiltin"]
  local program = listAppend(builtinSCode, inProgram)
  local path = Main.AbsynUtil.stringPath(elementToInstantiate)
  Main.instClassInProgramFM(path, program)
end

function testSpin()
    p = parseFile("./src\\example.mo")
    scodeProgram = translateToSCode(p)
    @debug "Translation to SCode"
    @debug "SCode -> DAE"
    (dae, cache) = instantiateSCodeToDAE("HelloWorld", scodeProgram)
    @debug "After DAE Translation"
  return dae
end

function testSpinDAEExport()
  p = parseFile("example.mo")
  scodeProgram = translateToSCode(p)
  @debug "Translation to SCode"
  @debug "SCode -> DAE"
  (dae, cache) = instantiateSCodeToDAE("HelloWorld", scodeProgram)
  @debug "Exporting to file"
  exportDAERepresentationToFile("testDAE.jl", "$dae")
  @debug "DAE Exported"
end

"""
  Prints the DAE representation to a file
"""
function exportDAERepresentationToFile(fileName::String, contents::String)
  local fdesc = open(fileName, "w")
  write(fdesc, contents)
  close(fdesc)
end

"""
  ```toString(model::FlatModel)```
    Converts the flat model representation to a Julia String, the extra \\n are replaced with \n
"""
function toString(model::Main.FlatModel)
  local res = Main.toString(model)
  local res = replace(res, "\\n" => "\n")
  return res
end

function exportSCodeRepresentationToFile(fileName::String, contents::List{SCode.CLASS})
  local fdesc = open(fileName, "w")
  local processedContents = replace(string(contents), "," => ",\n")
  write(fdesc, processedContents)
  close(fdesc)
end

end # module
