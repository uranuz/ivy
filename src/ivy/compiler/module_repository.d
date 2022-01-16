module ivy.compiler.module_repository;

class CompilerModuleRepository
{
	import trifle.text_forward_range: TextForwardRange;
	import trifle.utils: ensure;

	import ivy.compiler.common;
	import ivy.parser.parser: Parser;
	import ivy.ast.iface: IvyNode;

	import ivy.compiler.errors: IvyCompilerException;

	import ivy.log: LogerMethod;

	alias TextRange = TextForwardRange!string;
	alias ParserT = Parser!(TextRange);
	alias assure = ensure!IvyCompilerException;
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

		ensure(!!importPaths.length, "List of compiler import paths must not be empty!");
	}


	void loadModuleFromFile(string moduleName)
	{
		import std.algorithm: splitter, startsWith;
		import std.array: array, join;
		import std.range: only, chain, empty, front;
		import std.path: buildNormalizedPath, isAbsolute;
		import std.file: read, exists, isFile, isDir;

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
			assure(
				!fileName.empty && fileName.startsWith(buildNormalizedPath(importPath)),
				"Incorrect path to module: ", fileName);

			if( exists(fileName) && isFile(fileName) ) {
				existingFiles ~= fileName;
			}
			/*
			// This mode is considered deprecated
			else if( exists(fileNameNoExt) && isDir(fileNameNoExt) ) {
				// If there is no file with exact name then try to find folder with this path
				// and check if there is file with name <moduleName> and <_fileExtension>
				fileName = buildNormalizedPath(fileNameNoExt, moduleName.splitter('.').back) ~ _fileExtension;
				if( exists(fileName) && isFile(fileName) )
					existingFiles ~= fileName;
			}
			*/
		}

		if( existingFiles.length == 0 )
			assure(false,
				"Cannot load module ", moduleName, ". Searching in import paths:\n", _importPaths.join(",\n") );
		else if( existingFiles.length == 1 )
			fileName = existingFiles.front; // Success
		else
			assure(false,
				"Found multiple source files in import paths matching module name ", moduleName,
				". Following files matched:\n", existingFiles.join(",\n"));


		auto parser = new ParserT(
			cast(string) read(fileName),
			fileName,
			_logerMethod);

		_moduleTrees[moduleName] = parser.parse();
	}

	IvyNode getModuleTree(string moduleName)
	{
		IvyNode node = _moduleTrees.get(moduleName, null);
		if( node is null ) {
			loadModuleFromFile(moduleName);
		}

		node = _moduleTrees.get(moduleName, null);
		assure(node, "Unable to get tree for module: ", moduleName);
		return node;
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
