module ivy.js_builder;

import std.getopt: getopt, defaultGetoptPrinter;
import std.file: dirEntries, SpanMode, exists, DirEntry, mkdirRecurse, write, getcwd;
import std.path: extension, dirSeparator, stripExtension, buildNormalizedPath, dirName, setExtension;
import std.algorithm: sort, uniq, splitter, startsWith, map;
import std.range: chain, dropOne;
import std.array: array;
import std.stdio: writeln;
import std.string: join;


import ivy.engine.config: IvyEngineConfig;
import ivy.engine.engine: IvyEngine;
import ivy.types.module_object: ModuleObject;

void main(string[] args)
{
	string sourcePath;
	string basePath = getcwd();
	string outPath;
	string[] importPaths;

	auto optResult = getopt(args,
		"sourcePath", "Path to directory of ivy-files that should be built into JavaScript modules", &sourcePath,
		"basePath", "Path to directory used to resolve ivy module names (working directory by default)", &basePath,
		"outPath", "Output path where to build templates to. Source modules path will be preserved", &outPath,
		"importPath", "Path that used by compiler to resolve module imports (multiple entries allowed)", &importPaths
	);

	bool isError = false;

	if (!sourcePath.length)
	{
		isError = true;
		writeln("Expected sourcePath");
	}
	else if (!exists(sourcePath))
	{
		isError = true;
		writeln("Source path not exists");
	}

	if (!outPath.length)
	{
		isError = true;
		writeln("Expected outPath");
	}

	if( optResult.helpWanted || isError ) {
		defaultGetoptPrinter("Tool that compiles Ivy templates into JavaScript modules", optResult.options);
		return;
	}

	IvyEngineConfig config;
	config.importPaths = ([basePath] ~ importPaths).sort.uniq.array;
	config.clearCache = false;

	writeln("Source path: ", sourcePath);
	writeln("Base path: ", basePath);
	writeln("Import paths: ", config.importPaths);
	writeln("Out path: ", outPath);

	IvyEngine ivyEngine = new IvyEngine(config);

	ivyEngine.loadModulesByPath(sourcePath, basePath);

	foreach(ModuleObject mod; ivyEngine.moduleObjCache.moduleObjects)
		writeJSModule(mod, outPath, config.importPaths);
}

void loadModulesByPath(IvyEngine ivyEngine, string sourcePath, string basePath)
{
	foreach(DirEntry dirEntry; dirEntries(sourcePath, SpanMode.depth, true))
	{
		if( !dirEntry.isFile )
			continue;
		if( dirEntry.name.extension != ".ivy" )
			continue;
		string relPath = dirEntry.name._resolveRelPath(basePath);
		if( !relPath.length )
			continue;
		writeln("Load module by relative path: ", relPath);

		string moduleName = relPath.stripExtension.splitter(dirSeparator).join(".");
		ivyEngine.loadModule(moduleName).then((it) => writeln("Loaded!"), (err) => writeln("Error loading!", err));
	}
}

void writeJSModule(ModuleObject mod, string outPath, string[] importPaths)
{
	string sourceRelPath = mod.fileName._resolveRelPath(importPaths[0]).stripExtension; // 0 - is base path
	if( !sourceRelPath.length )
		return;
	writeln("sourceRelPath: ", sourceRelPath);

	string jsContent = mod.renderJSModule(sourceRelPath, importPaths);
	string contentOutPath = buildNormalizedPath(outPath, sourceRelPath).setExtension("ivy.js");
	string contentOutDir = dirName(contentOutPath);
	mkdirRecurse(contentOutDir);

	writeln("Writing: ", contentOutPath);
	write(contentOutPath, jsContent);
	//writeln(contentOutPath, "\n\n", jsContent);
}

string renderJSModule(ModuleObject mod, string relPath, string[] importPaths)
{	
	import std.algorithm: map;
	import std.array: array;
	import std.json: toJSON, JSONValue;

	string[] deps = ["ivy/engine/singleton"] ~ mod.dependModules.byValue.map!(
		(fileName) => _resolveRelPath(fileName, importPaths).stripExtension
	).array;

	writeln(deps);

	JSONValue jMod = mod.toStdJSON();
	string sMod = toJSON(jMod, true);

	return `define('` ~ relPath ~ `, [
	` ~ deps.map!((it) => "'" ~ it ~ "'").join(",\n") ~ `
], function(ivyEngine) {
	var rawMod = ` ~ sMod ~ `;
	return ivyEngine.loadRawSync(rawMod);
});`;

}

string _resolveRelPath(string path, string basePath)
{
	import std.algorithm: startsWith;
	import std.path: asRelativePath;
	import std.array: array;

	if( !path.startsWith(basePath) )
		return null;
	return path.asRelativePath(basePath).array;
}

string _resolveRelPath(string path, string[] basePaths)
{
	foreach( string basePath; basePaths)
	{
		string relPath = path._resolveRelPath(basePath);
		if( relPath.length )
			return relPath;
	}
	return null;
}