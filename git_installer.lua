--computercraft
--github file downloader by drPepper
--based on "pastebin" utility from ComputerCraft mod

-- "THE BEER-WARE LICENSE"
-- drPepper@KOPROKUBACH wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, in-game or IRL,
-- and you think this stuff is worth it, you can give me a beer in return
 
if not http then
    printError( "Github Installer requires http API" )
    printError( "Set enableAPI_http to true in ComputerCraft.cfg" )
    return
end
 
local function Download(filepath)
    write( "Connecting to github.com... " )
    local response = http.get(
        "https://raw.githubusercontent.com/"..textutils.urlEncode( filename )
    )
        
    if response then
        print( "Success." )
        
        local sResponse = response.readAll()
        response.close()
        return sResponse
    else
        printError( "Failed." )
    end
end

local function Get(gitPath, localName)
    -- Determine file to download
    local sPath = shell.resolve( localName )
    if fs.exists( sPath ) then
        print( "File already exists" )
        return
    end
    
    -- GET the contents from github
    local res = get(gitPath)
    if res then        
        local file = fs.open( sPath, "w" )
        file.write( res )
        file.close()
        
        print( "Downloaded as "..sFile )
    end
end

--EXAMPLE (uncomment lines you need)
--deleting
--shell.run("rm", "startup")
--shell.run("rm", "sdata")

--server
--get("drpepper240/GPC/master/server.lua", "startup")
--server sdata
--shell.run("pastebin", "get", "", "startup")

--client
--get("drpepper240/GPC/master/client.lua", "startup")


