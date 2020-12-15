-- wxWidgets configuration file for premake5
--
-- Copyright (C) 2017-2020 Ulrich Telle <ulrich@telle-online.de>
--
-- Based on the script for premake4 created by
-- laurent.humbertclaude@gmail.com and v.krishnakumar@gmail.com 

-- Optional environment variable specifying the wxWidgets version
newoption {
  trigger     = "wx_ver",
  value       = "3.1",
  description = "Version of the wxWidgets build to be used"
}

-- Optional environment variable pointing to the root directory of wxWidgets installation
newoption {
  trigger     = "wx_env",
  value       = "WXWIN",
  description = "Environment variable for the root of the wxWidgets build to be used"
}

-- Optional root directory of wxWidgets installation
newoption  {
  trigger     = "wx_root",
  value       = "PATH",
  description = "Path to wxWidgets root directory, by default, environment variable WXWIN will be used or wx-config found in path on POSIX"
}

-- Target directory for the build files generated by premake5
newoption {
  trigger     = "builddir",
  value       = "build",
  description = "Directory for the generated build files"
}

-- Option to select monolithic wxWidgets build
newoption {
  trigger     = "monolithic",
  description = "Monolithic wxWidgets build"
}

if not _OPTIONS["wx_ver"] then
   _OPTIONS["wx_ver"] = "3.1"
end

if not _OPTIONS["wx_env"] then
   _OPTIONS["wx_env"] = "WXWIN"
end

wxMonolithic = ((_ACTION == "gmake" or _ACTION == "gmake2") and _OPTIONS["monolithic"])

-- Determine version of Visual Studio action
msvc_useProps = false
vc_version = "";
if _ACTION == "vs2003" then
  vc_version = 7
elseif _ACTION == "vs2005" then
  vc_version = 8
elseif _ACTION == "vs2008" then
  vc_version = 9
elseif _ACTION == "vs2010" then
  vc_version = 10
elseif _ACTION == "vs2012" then
  vc_version = 11
elseif _ACTION == "vs2013" then
  vc_version = 12
elseif _ACTION == "vs2015" then
  vc_version = 14
elseif _ACTION == "vs2017" then
  vc_version = 15
elseif _ACTION == "vs2019" then
  vc_version = 16
end

is_msvc = false
msvc_useProps = false
wx_compiler = "gcc"
if ( vc_version ~= "" ) then
  is_msvc = true
  wx_compiler = "vc"
  msvc_useProps = vc_version >= 10
  vc_with_ver = "vc"..vc_version
end

require('vstudio')
require('gmake2')

premake.api.register {
  name = "wxUseProps",
  scope = "project",
  kind = "boolean",
  default = false
}

local function wxPropertySheets(prj)
--  if premake.wxProject ~= nil and premake.wxProject then 
  if prj.wxUseProps then 
    premake.push('<ImportGroup Label="PropertySheets">')
    if premake.wxSetupProps ~= nil and premake.wxSetupProps ~= '' then
      premake.w('<Import Project="' .. premake.wxSetupProps .. '" />')
    else
      premake.w('<Import Project="wx_setup.props" />')
    end
    premake.w('<Import Project="wx_local.props" Condition="Exists(\'wx_local.props\')" />')
    premake.pop('</ImportGroup>')
  end
end

premake.override(premake.vstudio.vc2010.elements, "project", function(base, prj)
	local calls = base(prj)
	table.insertafter(calls, premake.vstudio.vc2010.importExtensionSettings, wxPropertySheets)
	return calls
end)

premake.override(premake.modules.gmake2, "target", function(base, cfg, toolset)
  local targetpath = string.gsub(premake.project.getrelative(cfg.project, cfg.buildtarget.directory), ' ', '_')
  premake.outln('TARGETDIR = ' .. targetpath)
  premake.outln('TARGET = $(TARGETDIR)/' .. cfg.buildtarget.name)
end)
  
premake.override(premake.modules.gmake2, "objdir", function(base, cfg, toolset)
  local objpath = string.gsub(premake.project.getrelative(cfg.project, cfg.objdir), ' ', '_')
  premake.outln('OBJDIR = ' .. objpath)
end)

-- Activate loading of separate props file
if (msvc_useProps) then
--  premake.wxProject = true
end

local function wxSetTargetDirectory(arch, build)
  -- Target directory
  if (is_msvc) then
    targetdir (BUILDDIR .. "/bin/" .. vc_with_ver .. "/" .. arch .. "/" .. build)
  else
    targetdir (BUILDDIR .. "/bin/gcc" .. "/" .. arch .. "/" .. build)
  end
end

-- The wx_config the parameters are.
--   Root      : path to wx root folder. Can be left empty if WXWIN is defined
--               or if wx-config is accessible.
--   Debug     : "yes" use debug version of wxwidgets. Default to "no"
--   Version   : one of '2.8', '2.9', '3.0', '3.1'. Default to '3.1'
--   Static    : indicates how wx is to be linked. Values are
--               either "yes" for static linking or "no" for shared linking, Default to "no"
--   Unicode   : use "yes" for unicode or "no" for ansi version.
--               ansi version only available up to 2.8
--               Default to "yes"
--   Universal : use universal configuration. Default to "no"
--   Libs      : a list of wx libraries that you want to link with.
--               eg: "aui,media,html"
--               Default to "richtext,aui,xrc,qa,html,adv,core,xml,net"; base is implicit
--   Arch      : architecture ("Win32" or "Win64", default "Win32")
--   WindowsCompiler : compiler used to compile windows libraries ( "vc" or "gcc" )
 
function wx_config(options)

  local wrongParam = false
  local allowedWxOptions = {"Root", "Debug", "Host", "Version", "Static", "Unicode", "Universal", "Libs", "Arch", "WindowsCompiler" }
  for option in pairs(options) do
    if not table.contains(allowedWxOptions, option) then
      print ("unrecognized option '"..option.. "'")
      wrongParam = true
    end
  end
  if wrongParam then print("valid options are : '" .. table.concat(allowedWxOptions, "', '").."'") end
 
  wx_config_Private( options.Root or "",
                     options.Debug or "",
                     options.Host or "",
                     options.Version or "3.1",
                     options.Static or "",
                     options.Unicode or "yes",
                     options.Universal or "",
                     options.Libs or "richtext,aui,xrc,qa,html,adv,core,xml,net", -- base is implicit, std not valid
                     options.Arch or "Win32",
                     options.WindowsCompiler or "vc"
                   )
end
 
function wx_config_Private(wxRoot, wxDebug, wxHost, wxVersion, wxStatic, wxUnicode, wxUniversal, wxLibs, wxArch, wxWindowsCompiler)
    -- some options are not allowed for newer version of wxWidgets
    if wxVersion > "2.8" then -- alphabetical comparison may fail...
        wxUnicode = "yes"
    end
 
    --wx_root=PATH override wxRoot parameter
    if _OPTIONS and _OPTIONS["wx_root"] then
        print ("seen option '--wx_root=" .. _OPTIONS["wx_root"] .. "' overriding default root = '" .. wxRoot .. "'")
        wxRoot = _OPTIONS["wx_root"]
    end
    -- the environment variable WXWIN override both wxRoot parameter and --wx_root option
    if os.getenv(_OPTIONS["wx_env"]) then wxRoot = "$(".._OPTIONS["wx_env"]..")" end
 
    if wxUnicode == "yes" then defines { "_UNICODE" } end
 
    if wxDebug == "yes" then defines { "__WXDEBUG__" }
    elseif wxDebug == "no" then optimize "On" end
 
    if wxStatic == "yes" then
        -- flags { "StaticRuntime" }
    else
        defines { "WXUSINGDLL" }
    end
 
 
    -- function to compensate lack of wx-config program on windows
    -- but wait, look at http://sites.google.com/site/wxconfig/ for one !
    function wx_config_for_windows(wxWindowsCompiler)
        local wxBuildType = ""  -- buildtype is one of "", "u", "d" or "ud"
        local wxDebugSuffix = "" -- debug buildsuffix is for support libraries only
        if wxUnicode ~= "" then wxBuildType = wxBuildType .. "u" end
        if wxDebug == "yes" then
            wxBuildType = wxBuildType .. "d"
            wxDebugSuffix = "d"
        end
 
        if wxArch == "Win64" then
          wxArchSuffix = "_x64"
        else
          wxArchSuffix = ""
        end
        if (msvc_useProps) then
          local wxLibPath = '$(wxRootDir)\\lib\\$(wxCompilerPrefix)$(wxArchSuffix)_' .. iif(wxStatic == 'yes', 'lib', 'dll')
          -- common defines
          defines{ "__WXMSW__" }
 
          -- common include path
          includedirs {
              path.join("$(wxRootDir)", "include\\msvc"),
              path.join(wxLibPath, "msw$(wxSuffix)"),   -- something like "%WXWIN%\lib\vc_lib\mswud" to find "wx/setup.h"
              path.join("$(wxRootDir)", "include")
            }
 
          -- common library path
          libdirs { wxLibPath }
          local compLibPath = '$(ProjectDir)..\\lib\\$(wxCompilerPrefix)$(wxArchSuffix)_dll'
          debugenvs { "PATH=" .. compLibPath .. ";" .. wxLibPath }
        elseif (wxWindowsCompiler == "gcc") then
          local wxLibPath = '$(wxRootDir)/lib/$(wxCompilerPrefix)$(wxArchSuffix)_' .. iif(wxStatic == 'yes', 'lib', 'dll')
          -- common defines
          defines{ "__WXMSW__" }
 
          -- common include path
          includedirs {
              path.join(wxLibPath, "msw$(wxSuffix)"),   -- something like "%WXWIN%\lib\vc_lib\mswud" to find "wx/setup.h"
              path.join("$(wxRootDir)", "include")
            }
 
          -- common library path
          libdirs { wxLibPath }
          local compLibPath = '$(ProjectDir)../lib/$(wxCompilerPrefix)$(wxArchSuffix)_dll'
          debugenvs { "PATH=" .. compLibPath .. ";" .. wxLibPath }
        else
          local wxLibPath = path.join(wxRoot, "lib")
          wxLibPath = path.join(wxLibPath, wxWindowsCompiler .. wxArchSuffix .. "_" .. iif(wxStatic == 'yes', 'lib', 'dll'))
          -- common defines
          defines{ "__WXMSW__" }
 
          -- common include path
          includedirs {
              path.join(wxLibPath, "msw" .. wxBuildType),   -- something like "%WXWIN%\lib\vc_lib\mswud" to find "wx/setup.h"
              path.join(wxRoot, "include")
            }
 
          -- common library path
          libdirs { wxLibPath }
          local compLibPath = '$(ProjectDir)..\\lib\\' .. wxWindowsCompiler .. wxArchSuffix .. '_dll'
          debugenvs { "PATH=" .. compLibPath .. ";" .. wxLibPath }
        end
 
        -- add the libs (except for MSVC)
        if (wxWindowsCompiler == "gcc") then
          libVersion = string.gsub(wxVersion, '%.', '') -- remove dot from version
          if wxMonolithic then
            links ( "$(wxMonolithicLibName)" )
            if (wxStatic == "yes") then
              -- link with support libraries
              for i, lib in ipairs({"wxjpeg", "wxpng", "wxzlib", "wxtiff",  "wxexpat"}) do
                links { lib.."$(wxSuffixDebug)" }
              end
              links { "wxregex" .. "$(wxSuffix)" }
            end
          else
            for i, lib in ipairs(string.explode(wxLibs, ",")) do
              local libPrefix = '$(wxToolkitLibNamePrefix)'
              if lib == "xml" or lib == "net" or lib == "odbc" then
                libPrefix = '$(wxBaseLibNamePrefix)_'
              end
              links { libPrefix..lib}
            end
            links { "$(wxBaseLibNamePrefix)" } -- base lib
            -- link with support libraries
            for i, lib in ipairs({"wxjpeg", "wxpng", "wxzlib", "wxtiff", "wxexpat"}) do
              links { lib.."$(wxSuffixDebug)" }
            end
            links { "wxregex" .. "$(wxSuffix)" }
          end
          links { "kernel32", "user32", "gdi32", "comdlg32", "winspool", "winmm", "shell32", "shlwapi", "comctl32", "ole32", "oleaut32", "uuid", "rpcrt4", "advapi32", "version", "wsock32", "wininet", "oleacc", "uxtheme" }
        elseif (not is_msvc) then
          libVersion = string.gsub(wxVersion, '%.', '') -- remove dot from version
          links { "wxbase"..libVersion..wxBuildType } -- base lib
          for i, lib in ipairs(string.explode(wxLibs, ",")) do
              local libPrefix = 'wxmsw'
              if lib == "xml" or lib == "net" or lib == "odbc" then
                  libPrefix = 'wxbase'
              end
              links { libPrefix..libVersion..wxBuildType..'_'..lib}
          end
          -- link with support libraries
          for i, lib in ipairs({"wxjpeg", "wxpng", "wxzlib", "wxtiff", "wxexpat"}) do
              links { lib..wxDebugSuffix }
          end
          links { "wxregex" .. wxBuildType }
          links { "kernel32", "user32", "gdi32", "comdlg32", "winspool", "winmm", "shell32", "shlwapi", "comctl32", "ole32", "oleaut32", "uuid", "rpcrt4", "advapi32", "version", "wsock32", "wininet", "oleacc", "uxtheme" }
        end
    end
 
    -- use wx-config to figure out build parameters
    function wx_config_for_posix()
        local configCmd = "wx-config"  -- this is the wx-config command ligne
        if wxRoot ~= "" then configCmd = path.join(wxRoot, "bin/wx-config") end
 
        local function checkYesNo(value, option)
            if value == "" then return "" end
            if value == "yes" or value == "no" then return " --"..option.."="..value end
            error("wx"..option..' can only be "yes", "no" or empty' )
        end
 
        configCmd = configCmd .. checkYesNo(wxDebug, "debug")
        configCmd = configCmd .. checkYesNo(wxStatic, "static")
        configCmd = configCmd .. checkYesNo(wxUnicode, "unicode")
        configCmd = configCmd .. checkYesNo(wxUniversal, "universal")
        if wxHost ~= "" then configCmd = configCmd .. " --host=" .. wxHost end
        if wxVersion ~= "" then configCmd = configCmd .. " --version=" .. wxVersion end
 
        -- set the parameters to the curent configuration
        buildoptions{"`" .. configCmd .." --cxxflags`"}
        linkoptions{"`" .. configCmd .." --libs " .. wxLibs .. "`"}
    end
 
-- BUG: here, using any configuration() function will reset the current filter
--      and apply configuration to all project configuration...
--      see http://industriousone.com/post/add-way-refine-configuration-filter
--      and http://sourceforge.net/tracker/?func=detail&aid=2936443&group_id=71616&atid=531881
--~     configuration "not windows"
--~         wx_config_for_posix()
--~     configuration "vs*"
--~         wx_config_for_windows("vc")
--~     configuration {"windows", "codeblocks or gmake or codelitle"}
--~         wx_config_for_windows("gcc")
    if os.target() ~= "windows" then
        wx_config_for_posix()
    else
        local allowedCompiler = {"vc", "gcc"}
        if not table.contains( allowedCompiler, wxWindowsCompiler) then
            print( "wrong wxWidgets Compiler specified('"..wxWindowsCompiler.."'), should be one of '".. table.concat(allowedCompiler, "', '").."'" )
            wxWindowsCompiler = "vc"
        end
--~  BUG/WISH: I need a function like compiler.get() that return the project/configuration compiler
--~         local wxWindowsCompiler = "vc"
--~  BUG? --cc=compiler standard premake option is not registered in the _OPTIONS array
--~         if _OPTIONS and _OPTIONS["cc"] then
--~             wxWindowsCompiler = _OPTIONS.cc
--~             print("seen option '--cc=" .. _OPTIONS["cc"] .. "' overriding default cc='vc'")
--~         end
        wx_config_for_windows(wxWindowsCompiler)
    end
end

function init_filters()
  filter { "platforms:Win32" }
    system "Windows"
    architecture "x32"

  filter { "platforms:Win64" }
    system "Windows"
    architecture "x64"

  filter { "configurations:Debug*" }
    defines {
      "DEBUG", 
      "_DEBUG"
    }
    symbols "On"
    targetsuffix "d"


  filter { "configurations:Release*" }
    defines {
      "NDEBUG"
    }
    optimize "On"

  filter {}
end

function make_filters(libname,libtarget,wxlibs)
  if (is_msvc) then
    if (msvc_useProps) then
      wxUseProps(true)
      targetname(libtarget .. "$(wxFlavour)")
    else
      targetname(libtarget)
    end
  else
    targetname(libtarget .. "$(wxFlavour)")
  end

  if (is_msvc) then
    defines {
      libname .. "_DLLNAME=$(TargetName)"
    }
  else
    defines {
      libname .. "_DLLNAME=" .. libtarget .. "$(wxSuffixDebug)"
    }
  end

  makesettings { "include config.gcc" }

  if (wx_compiler == "gcc") then
    targetprefix "lib"
    targetextension ".a"
    implibprefix "lib"
    implibextension ".a"
  end

  -- Intermediate directory
  if (is_msvc) then
    objdir (BUILDDIR .. "/obj/" .. vc_with_ver)
  else
    objdir (BUILDDIR .. "/obj/gcc")
  end

  filter { "configurations:Release or Debug or Release wxDLL or Debug wxDLL" }
    kind "StaticLib"
    defines {
      "_LIB",
      "WXMAKINGLIB_" .. libname
    }
  filter { "configurations:Release or Debug", "platforms:Win32" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_lib")
      end
    else
      targetdir("lib/gcc_lib")
    end
  filter { "configurations:Release wxDLL or Debug wxDLL", "platforms:Win32" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_lib_wxdll")
      end
    else
      targetdir("lib/gcc_lib_wxdll")
    end
  filter { "configurations:Release or Debug", "platforms:Win64" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_x64_lib")
      end
    else
      targetdir("lib/gcc_x64_lib")
    end
  filter { "configurations:Release wxDLL or Debug wxDLL", "platforms:Win64" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_x64_lib_wxdll")
      end
    else
      targetdir("lib/gcc_x64_lib_wxdll")
    end

  filter { "configurations:Release DLL or Debug DLL" }
    kind "SharedLib"
    defines {
      "_USRDLL",
      "WXMAKINGDLL_" .. libname
    }

  filter { "configurations:Release DLL or Debug DLL", "platforms:Win32" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_dll")
      end
    else
      targetdir("lib/gcc_dll")
    end
  filter { "configurations:Release DLL or Debug DLL", "platforms:Win64" }
    if (is_msvc) then
      if (msvc_useProps) then
        targetdir("$(wxOutDir)")
      else
        targetdir("lib/vc_x64_dll")
      end
    else
      targetdir("lib/gcc_x64_dll")
    end
    
  filter { "configurations:Debug*" }
    targetsuffix "d"

  filter { "configurations:Release*" }
    targetsuffix ""

  filter { "configurations:Debug", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Debug", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter { "configurations:Debug wxDLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Debug wxDLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter { "configurations:Debug DLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Debug DLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter { "configurations:Release", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Release", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter { "configurations:Release wxDLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Release wxDLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter { "configurations:Release DLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs }
  filter { "configurations:Release DLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }

  filter {}
end

function use_filters(libname, debugcwd, wxlibs)
  if (msvc_useProps) then
    wxUseProps(true)
  end

  makesettings { "include config.gcc" }

  if (wx_compiler == "gcc") then
    implibprefix "lib"
    implibextension ".a"
  end

  -- Intermediate directory
  if (is_msvc) then
    objdir (BUILDDIR .. "/obj/" .. vc_with_ver)
  else
    objdir (BUILDDIR .. "/obj/gcc")
  end

  filter { "configurations:Release or Debug or Release wxDLL or Debug wxDLL" }
    defines {
      "WXUSINGLIB_" .. libname
    }

  filter { "configurations:Release DLL or Debug DLL" }
    defines {
      "WXUSINGDLL_" .. libname
    }

  filter { "configurations:Debug*" }
    targetsuffix "d"
    debugdir(debugcwd)

  filter { "configurations:Release*" }
    targetsuffix ""
    debugdir(debugcwd)

  filter { "configurations:Debug", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win32", "Debug")
  filter { "configurations:Debug", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Debug")

  filter { "configurations:Debug wxDLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win32", "Debug wxDLL")
  filter { "configurations:Debug wxDLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Debug wxDLL")

  filter { "configurations:Debug DLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win32", "Debug DLL")
  filter { "configurations:Debug DLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="yes", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Debug DLL")

  filter { "configurations:Release", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win32", "Release")
  filter { "configurations:Release", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="yes", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Release")

  filter { "configurations:Release wxDLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win32", "Release wxDLL")
  filter { "configurations:Release wxDLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Release wxDLL")

  filter { "configurations:Release DLL", "platforms:Win32" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", WindowsCompiler=wx_compiler, Libs=wxlibs}
    wxSetTargetDirectory("Win32", "Release DLL")
  filter { "configurations:Release DLL", "platforms:Win64" }
    wx_config {Unicode="yes", Version=_OPTIONS["wx_ver"], Static="no", Debug="no", Arch="Win64", WindowsCompiler=wx_compiler, Libs=wxlibs }
    wxSetTargetDirectory("Win64", "Release DLL")

  filter {}
end
