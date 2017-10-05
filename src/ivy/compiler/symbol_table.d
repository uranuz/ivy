module ivy.compiler.symbol_table;

import ivy.common;
import ivy.compiler.common;
import ivy.directive_stuff;

enum SymbolKind { DirectiveDefinition, Module };

class Symbol
{
	string name;
	SymbolKind kind;
}

class DirectiveDefinitionSymbol: Symbol
{
	DirAttrsBlock!(true)[] dirAttrBlocks;

public:
	this( string name, DirAttrsBlock!(true)[] dirAttrBlocks )
	{
		this.name = name;
		this.kind = SymbolKind.DirectiveDefinition;
		this.dirAttrBlocks = dirAttrBlocks;
	}
}

class ModuleSymbol: Symbol
{
	SymbolTableFrame symbolTable;

public:
	this( string name, SymbolTableFrame symbolTable )
	{
		this.name = name;
		this.kind = SymbolKind.Module;
		this.symbolTable = symbolTable;
	}
}

class SymbolTableFrame
{
	alias LogerMethod = void delegate(LogInfo);
	Symbol[string] _symbols;
	SymbolTableFrame _moduleFrame;
	SymbolTableFrame[size_t] _childFrames; // size_t - is index of scope start in source code?
	LogerMethod _logerMethod;

public:
	this(SymbolTableFrame moduleFrame, LogerMethod logerMethod)
	{
		_moduleFrame = moduleFrame;
		_logerMethod = logerMethod;
	}

	version(IvyCompilerDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyCompilerException, isDebugMode);
		SymbolTableFrame table;

		void sendLogInfo(LogInfoType logInfoType, string msg) {
			if( table._logerMethod is null ) {
				return; // There is no loger method, so get out of here
			}
			table._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	Symbol localLookup(string name) {
		return _symbols.get(name, null);
	}

	Symbol lookup(string name)
	{
		loger.write(`SymbolTableFrame: Starting compiler symbol lookup: `, name);

		if( Symbol* symb = name in _symbols ) {
			loger.write(`SymbolTableFrame: Symbol: `, name, ` found in frame`);
			return *symb;
		}

		loger.write(`SymbolTableFrame: Couldn't find symbol in frame: `, name);

		// We need to try to look in module symbol table
		if( Symbol symb = moduleLookup(name) ) {
			loger.write(`SymbolTableFrame: Symbol found in imported modules: `, name);
			return symb;
		}

		loger.write(`SymbolTableFrame: Couldn't find symbol in imported modules: `, name);

		if( !_moduleFrame ) {
			loger.write(`SymbolTableFrame: Attempt to find symbol: `, name, ` in module scope failed, because _moduleFrame is null`);
			return null;
		}

		loger.write(`SymbolTableFrame: Attempt to find symbol: `, name, ` in module scope!`);
		return _moduleFrame.lookup(name);
	}

	Symbol moduleLookup(string name)
	{
		import std.algorithm: splitter;
		import std.string: join;
		import std.range: take, drop;
		import std.array: array;

		loger.write(`SymbolTableFrame: Attempt to perform imported modules lookup for symbol: `, name);

		auto splittedName = splitter(name, ".").array;
		for( size_t i = 1; i <= splittedName.length; ++i )
		{
			string namePart = splittedName[].take(i).join(".");
			if( Symbol* symb = namePart in _symbols )
			{
				if( symb.kind == SymbolKind.Module )
				{
					string modSymbolName = splittedName[].drop(i).join(".");
					ModuleSymbol modSymbol = cast(ModuleSymbol) *symb;
					if( Symbol childSymbol = modSymbol.symbolTable.lookup(modSymbolName) )
						return childSymbol;
				}
			}

		}
		return null;
	}

	void add(Symbol symb) {
		_symbols[symb.name] = symb;
	}

	SymbolTableFrame getChildFrame(size_t sourceIndex) {
		return _childFrames.get(sourceIndex, null);
	}

	SymbolTableFrame newChildFrame(size_t sourceIndex)
	{
		loger.internalAssert(sourceIndex !in _childFrames, `Child frame already exists!`);

		// For now consider if this frame has no module frame - so it is module frame itself
		SymbolTableFrame child = new SymbolTableFrame(_moduleFrame? _moduleFrame: this, _logerMethod);
		_childFrames[sourceIndex] = child;
		return child;
	}

	string toPrettyStr()
	{
		import std.conv;
		string result;

		result ~= "\r\nSYMBOLS:\r\n";
		foreach( symbName, symb; _symbols )
		{
			result ~= symbName ~ ": " ~ symb.kind.to!string ~ "\r\n";
		}

		result ~= "\r\nFRAMES:\r\n";

		foreach( index, frame; _childFrames )
		{
			if( frame )
			{
				result ~= "\r\nFRAME with index " ~ index.to!string ~ "\r\n";
				result ~= frame.toPrettyStr();
			}
			else
			{
				result ~= "\r\nFRAME with index " ~ index.to!string ~ " is null\r\n";
			}
		}

		return result;
	}
}