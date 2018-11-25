module ivy.compiler.module_repository;

import ivy.common;
import ivy.compiler.common;
import ivy.parser.parser;
import ivy.parser.node: IvyNode;
import ivy.compiler.errors: IvyCompilerException;

class CompilerModuleRepository
{
	import ivy.parser.lexer_tools: TextForwardRange;
	import ivy.common: LocationConfig;

	alias TextRange = TextForwardRange!(string, LocationConfig());
	alias LogerMethod = void delegate(LogInfo);
private:
	string[] _importPaths;
	string _fileExtension;
	LogerMethod _logerMethod;

	IvyNode[string] _moduleTrees;

public:
	this(string[] importPaths, string fileExtension, LogerMethod logerMethod = null)
	{
		_importPaths = importPaths;
		_fileExtension = fileExtension;
		_logerMethod = logerMethod;
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		CompilerModuleRepository moduleRepo;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			if( moduleRepo._logerMethod !is null ) {
				moduleRepo._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
			}
			return msg;
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	void loadModuleFromFile(string moduleName)
	{
		import std.algorithm: splitter, startsWith;
		import std.array: array, join;
		import std.range: only, chain, empty, front;
		import std.path: buildNormalizedPath, isAbsolute;
		import std.file: read, exists, isFile, isDir;

		loger.write("loadModuleFromFile attempt to load module: ", moduleName);

		string fileName;
		string[] existingFiles;
		foreach( importPath; _importPaths )
		{
			if( !isAbsolute(importPath) )
				continue;

			string fileNameNoExt = buildNormalizedPath( only(importPath).chain( moduleName.splitter('.') ).array );
			// The module name is given. Try to build path to it
			fileName = fileNameNoExt ~ _fileExtension;

			// Check if file name is not empty and located in root path
			if( fileName.empty || !fileName.startsWith( buildNormalizedPath(importPath) ) )
				loger.error(`Incorrect path to module: `, fileName);

			if( exists(fileName) && isFile(fileName) ) {
				existingFiles ~= fileName;
			} else if( exists(fileNameNoExt) && isDir(fileNameNoExt) ) {
				// If there is no file with exact name then try to find folder with this path
				// and check if there is file with name <moduleName> and <_fileExtension>
				fileName = buildNormalizedPath(fileNameNoExt, moduleName.splitter('.').back) ~ _fileExtension;
				if( exists(fileName) && isFile(fileName) ) {
					existingFiles ~= fileName;
				}
			}
		}

		if( existingFiles.length == 0 )
			loger.error(`Cannot load module `, moduleName, ". Searching in import paths:\n", _importPaths.join(",\n") );
		else if( existingFiles.length == 1 )
			fileName = existingFiles.front; // Success
		else
			loger.error(`Found multiple source files in import paths matching module name `, moduleName,
				". Following files matched:\n", existingFiles.join(",\n") );

		loger.write("loadModuleFromFile loading module from file: ", fileName);
		string fileContent = cast(string) read(fileName);

		auto parser = new Parser!(TextRange)(fileContent, fileName, _logerMethod);

		_moduleTrees[moduleName] = parser.parse();
	}

	IvyNode getModuleTree(string name)
	{
		if( name !in _moduleTrees ) {
			loadModuleFromFile( name );
		}

		if( name in _moduleTrees ) {
			return _moduleTrees[name];
		} else {
			return null;
		}
	}

	/// Clears parsed tree when we no longer need it
	void clearCache()
	{
		foreach( IvyNode node; _moduleTrees ) {
			if( node ) {
				node.destroy();
			}
		}
		_moduleTrees.clear();
	}
}
