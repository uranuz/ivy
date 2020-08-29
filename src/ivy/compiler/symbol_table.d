module ivy.compiler.symbol_table;

class SymbolTableFrame
{
	import ivy.types.symbol.iface: IIvySymbol;
	
	import ivy.compiler.errors: IvyCompilerException;
	import ivy.loger: LogInfo, LogerProxyImpl, LogInfoType;
	
	alias LogerMethod = void delegate(LogInfo);

	SymbolTableFrame _moduleFrame;

	IIvySymbol[string] _symbols;
	SymbolTableFrame[size_t] _childFrames; // size_t - is index of scope start in source code?
	size_t[string] _namedChildFrames;

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

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			import ivy.loger: getShortFuncName;

			if( table._logerMethod !is null ) {
				table._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
			}
			return msg;
		}
	}

	LogerProxy log(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	IIvySymbol localLookup(string name) {
		return _symbols.get(name, null);
	}

	IIvySymbol lookup(string name)
	{
		log.write(`Starting compiler symbol lookup: `, name);

		if( IIvySymbol* symb = name in _symbols ) {
			log.write(`Symbol: `, name, ` found in frame`);
			return *symb;
		}

		log.write(`Couldn't find symbol in frame: `, name);

		// We need to try to look in module symbol table
		if( IIvySymbol symb = moduleLookup(name) ) {
			log.write(`Symbol found in imported modules: `, name);
			return symb;
		}

		log.write(`Couldn't find symbol in imported modules: `, name);

		if( !_moduleFrame ) {
			log.write(`Attempt to find symbol: `, name, ` in module scope failed, because _moduleFrame is null`);
			return null;
		}

		log.write(`Attempt to find symbol: `, name, ` in module scope!`);
		return _moduleFrame.lookup(name);
	}

	IIvySymbol moduleLookup(string name)
	{
		import ivy.types.symbol.module_: ModuleSymbol;

		import std.algorithm: splitter;
		import std.string: join;
		import std.range: take, drop;
		import std.array: array;

		log.write(`SymbolTableFrame: Attempt to perform imported modules lookup for symbol: `, name);

		auto splittedName = splitter(name, ".").array;
		for( size_t i = 1; i <= splittedName.length; ++i )
		{
			string namePart = splittedName[].take(i).join(".");
			if( IIvySymbol* symb = namePart in _symbols )
			{
				ModuleSymbol modSymbol = cast(ModuleSymbol) *symb;
				if( modSymbol is null )
					continue;
				string modSymbolName = splittedName[].drop(i).join(".");
				
				if( IIvySymbol childSymbol = modSymbol.symbolTable.lookup(modSymbolName) )
					return childSymbol;
			}

		}
		return null;
	}

	void add(IIvySymbol symb)
	{
		log.internalAssert(symb.name !in _symbols, `Symbol with name "`, symb.name, `" already declared in current scope`);
		_symbols[symb.name] = symb;
	}

	SymbolTableFrame getChildFrame(size_t sourceIndex)
	{
		SymbolTableFrame child = _childFrames.get(sourceIndex, null);
		log.internalAssert(childFrame !is null, `No child frame found with given source index: `, sourceIndex);
		return child;
	}

	SymbolTableFrame getChildFrame(string name)
	{
		size_t* sourceIndexPtr = name in _namedChildFrames;
		log.internalAssert(childFrame !is null, `No child frame found with given name: `, name);
		return getChildFrame(*sourceIndexPtr);
	}

	SymbolTableFrame newChildFrame(size_t sourceIndex, string name)
	{
		log.internalAssert(sourceIndex !in _childFrames, `Child frame already exists with given source index: `, sourceIndex);

		// For now consider if this frame has no module frame - so it is module frame itself
		SymbolTableFrame child = new SymbolTableFrame(_moduleFrame? _moduleFrame: this, _logerMethod);
		_childFrames[sourceIndex] = child;

		if( name.length )
		{
			log.internalAssert(name !in _namedChildFrames, `Child frame already exists with given name: `, name);
			_namedChildFrames[name] = child;
		}

		return child;
	}

	string toPrettyStr()
	{
		import std.conv;
		string result;

		result ~= "\r\nSYMBOLS:\r\n";
		foreach( symbName, symb; _symbols )
		{
			result ~= symbName ~ "\r\n";
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