import std/[sequtils, strutils, os, strformat, osproc, sets, json]
import utils, pdxinfo, nimbledump

type
    BuildKind* = enum SimulatorBuild, DeviceBuild

    PlaydateConf* {.requiresInit.} = object
        kind*: BuildKind
        sdkPath*, pdxName*: string
        nimbleArgs*: seq[string]
        dump*: NimbleDump
        noAutoConfig*, nimDirect*: bool

proc resolvePdx(conf: PlaydateConf): PdxInfo =
  ## Returns the resolved pdxinfo content
  conf.dump.toPdxInfo.join(readPdx("./pdxinfo"))

proc exec*(command: string, args: varargs[string]) =
    ## Executes nimble with the given set of arguments
    let process = startProcess(
        command = command,
        args = args,
        options = {poUsePath, poParentStreams, poEchoCmd}
    )
    if process.waitForExit() != 0:
        let joinedArgs = args.join(" ")
        raise BuildFail.newException(fmt"Command failed: {command} {joinedArgs}")

proc build*(conf: PlaydateConf, args: varargs[string]) =
    ## Executes nimble with the given set of arguments
    let pdx = conf.resolvePdx()
    let baseArgs = @[
      "-d:playdateSdkPath=" & conf.sdkPath.quoteShell,
      "-d:pdxName=" & pdx.name.quoteShell,
      "-d:pdxAuthor=" & pdx.author.quoteShell,
      "-d:pdxDescription=" & pdx.description.quoteShell,
      "-d:pdxBundleId=" & pdx.bundleId.quoteShell,
      "-d:pdxVersion=" & pdx.version.quoteShell,
      "-d:pdxBuildNumber=" & pdx.buildNumber.quoteShell
    ].concat(conf.nimbleArgs).concat(args.toSeq)
    if conf.nimDirect:
        let entryPoints = conf.dump.entryPoints.filterIt(it.fileExists)
        exec("nim", @["c"].concat(baseArgs).concat(entryPoints))
    else:
        exec("nimble", @["build"].concat(baseArgs))

proc pdcPath*(conf: PlaydateConf): string =
    ## Returns the path of the pdc playdate utility
    return conf.sdkPath / "bin" / "pdc"

proc fileAppend*(path, content: string) =
    ## Appends a string to a file
    var handle: File
    doAssert handle.open(path, fmAppend)
    try:
        handle.write(content)
    finally:
        handle.close

proc updateGitIgnore(conf: PlaydateConf) =
    ## Adds entries to the gitignore file

    var toAdd = toHashSet([
        conf.pdxName,
        conf.pdxName & ".zip",
        "source/pdxinfo",
        "source/pdex.*",
        "*.dSYM"
    ])

    const gitIgnore = ".gitignore"

    if not fileExists(gitIgnore):
        writeFile(gitIgnore, "")

    for line in lines(gitIgnore):
        toAdd.excl(line)

    if toAdd.len > 0:
        gitIgnore.fileAppend(toAdd.items.toSeq.join("\n"))

proc updateConfig(conf: PlaydateConf) =
    ## Updates the config.nims file for the project if required

    const configFile = "playdate/build/config"

    if fileExists("config.nims"):
        for line in lines("config.nims"):
            if configFile in line:
                echo "config.nims already references ", configFile, "; skipping build configuration"
                return

    echo "Updating config.nims to include build configurations"

    "configs.nims".fileAppend(&"\n\n# Added by pdn\nimport {configFile}\n")

proc configureBuild(conf: PlaydateConf) =
    if not conf.noAutoConfig:
        conf.updateConfig
        echo "Writing pdxinfo"
        conf.resolvePdx().write
        echo "Updating gitignore"
        conf.updateGitIgnore

proc bundlePDX*(conf: PlaydateConf) =
    ## Bundles pdx file using parent directory name.
    exec(conf.pdcPath, "--version")
    exec(conf.pdcPath, "--verbose", "-sdkpath", conf.sdkPath, "source", conf.dump.name)

proc mv(source, target: string) =
    echo fmt"Moving {source} to {target}"
    if not source.fileExists and not source.dirExists:
        raise BuildFail.newException(fmt"Expecting the file '{source}' to exist, but it doesn't")
    moveFile(source, target)

proc rm(target: string) =
    echo fmt"Removing {target}"
    removeFile(target)

proc rmdir(target: string) =
    echo fmt"Removing {target}"
    removeDir(target)

proc artifactName(conf: PlaydateConf): string =
    ## Returns the artifact name returned by the build
    if defined(windows): conf.dump.name & ".exe" else: conf.dump.name

proc simulatorBuild*(conf: PlaydateConf) =
    ## Performs a build for running on the simulator
    conf.configureBuild()
    conf.build("-d:simulator", "-d:debug", "-o:" & conf.artifactName)
    if defined(windows):
        mv(conf.artifactName, "source" / "pdex.dll")
    elif defined(macosx):
        mv(conf.artifactName, "source" / "pdex.dylib")
        rmdir("source" / "pdex.dSYM")
        mv(conf.dump.name & ".dSYM", "source" / "pdex.dSYM")
    elif defined(linux):
        mv(conf.artifactName, "source" / "pdex.so")
    else:
        raise BuildFail.newException(fmt"Unsupported host platform")

    conf.bundlePDX()

proc runSimulator*(conf: PlaydateConf) =
    ## Executes the simulator
    simulatorBuild(conf)

    if not conf.pdxName.dirExists:
        raise BuildFail.newException(fmt"PDX does not exist: {conf.pdxName.absolutePath}")

    when defined(windows):
        exec(conf.sdkPath / "bin" / "PlaydateSimulator.exe", conf.pdxName)
    elif defined(macosx):
        exec("open", conf.sdkPath / "bin" / "Playdate Simulator.app", conf.pdxName)
    else:
        exec(conf.sdkPath / "bin" / "PlaydateSimulator", conf.pdxName)

proc deviceBuild*(conf: PlaydateConf) =
    ## Performs a build for running on device
    conf.configureBuild()
    conf.build("-d:device", "-d:release", "-o:" & conf.artifactName)
    mv(conf.artifactName, "source" / "pdex.elf")
    rm("game.map")

    conf.bundlePDX()

    let zip = findExe("zip")
    if zip != "":
        exec(zip, "-r", fmt"{conf.pdxName}.zip", conf.pdxName, "-x", "*.so")

proc runClean*(conf: PlaydateConf) =
    ## Removes all cache files and build artifacts
    rmdir("source" / "pdex.dSYM")
    rm("source" / "pdex.dylib")
    rm("source" / "pdex.dll")
    rm("source" / "pdex.so")
    rm("source" / "pdex.bin")
    rm("source" / "pdex.elf")
    rmdir(conf.pdxName)
    rm("source" / "pdex.elf")
    rm(conf.dump.name)
    rm(conf.dump.name & ".exe")
    exec("nimble", "clean")
