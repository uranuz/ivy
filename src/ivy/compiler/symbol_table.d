module ivy.compiler.symbol_table;

struct SymbolWithFrame
{
	import ivy.types.symbol.iface: ICallableSymbol;

	ICallableSymbol symbol;
	SymbolTableFrame frame;
}

class SymbolTableFrame
{
	import trifle.location: Location;

	import ivy.types.symbol.iface: IIvySymbol, ICallableSymbol;
	
	import ivy.compiler.errors: IvyCompilerException;

	import std.exception: enforce;

	alias enf = enforce!IvyCompilerException;

private:
	SymbolTableFrame _moduleFrame;

	IIvySymbol[string] _symbols;
	SymbolTableFrame[string] _childFrames; // <location string> -> SymbolTableFrame

public:
	this(SymbolTableFrame moduleFrame) {
		_moduleFrame = moduleFrame;
	}

	IIvySymbol localLookup(string name) {
		return _symbols.get(name, null);
	}

	IIvySymbol lookup(string name)
	{
		if( IIvySymbol symb = _symbols.get(name, null) ) {
			return symb;
		}

		// We need to try to look in module symbol table
		if( IIvySymbol symb = moduleLookup(name) ) {
			return symb;
		}

		if( !_moduleFrame ) {
			return null;
		}

		return _moduleFrame.lookup(name);
	}

	IIvySymbol moduleLookup(string name)
	{
		import ivy.types.symbol.module_: ModuleSymbol;

		import std.algorithm: splitter;
		import std.string: join;
		import std.range: take, drop;
		import std.array: array;

		auto splittedName = splitter(name, ".").array;
		for( size_t i = 1; i <= splittedName.length; ++i )
		{
			string namePart = splittedName[].take(i).join(".");
			ICallableSymbol symb = cast(ICallableSymbol) _symbols.get(namePart, null);
			if( symb is null )
				continue;
			SymbolTableFrame childFrame = _childFrames.get(symb.location.toString(), null);
			if( childFrame is null )
				continue;
			string modSymbolName = splittedName[].drop(i).join(".");
			if( IIvySymbol childSymbol = childFrame.lookup(modSymbolName) )
				return childSymbol;
		}
		return null;
	}

	void add(IIvySymbol symb)
	{
		enf(symb.name !in _symbols, `Symbol with name "` ~ symb.name ~ `" already declared in current scope`);
		_symbols[symb.name] = symb;
	}

	SymbolTableFrame getChildFrame(Location loc)
	{
		string locStr = loc.toString();

		SymbolTableFrame childFrame = _childFrames.get(locStr, null);
		enf(childFrame !is null, `No child frame found with given location: ` ~ locStr);
		return childFrame;
	}

	SymbolWithFrame getChildFrame(string name)
	{
		SymbolWithFrame res;

		res.symbol = cast(ICallableSymbol) _symbols.get(name, null);
		if( res.symbol is null ) {
			return res;
		}
		res.frame = getChildFrame(res.symbol.location);
		return res;
	}

	SymbolTableFrame newChildFrame(ICallableSymbol symb, SymbolTableFrame moduleFrame)
	{
		this.add(symb); // Add symbol to table

		string locStr = symb.location.toString();

		enf(
			locStr !in _childFrames,
			`Child frame already exists with location: ` ~ locStr);

		// For now consider if this frame has no module frame - so it is module frame itself
		SymbolTableFrame childFrame = new SymbolTableFrame(moduleFrame);
		_childFrames[locStr] = childFrame;

		return childFrame;
	}

	SymbolTableFrame newChildFrame(ICallableSymbol symb) {
		return newChildFrame(symb, _moduleFrame? _moduleFrame: this);
	}

	void clear()
	{
		_symbols.clear();
		_childFrames.clear();
	}

	string toPrettyStr()
	{
		string result;

		result ~= "\r\nSYMBOLS:\r\n";
		foreach( name, symb; _symbols )
		{
			result ~= name ~ (symb.location.toString() in _childFrames? ` (with frame)`: null) ~ "\r\n";
		}

		/*
		result ~= "\r\nFRAMES:\r\n";
		foreach( locStr, frame; _childFrames ) {
			result ~= locStr ~ ":\r\n" ~ frame.toPrettyStr();
		}
		*/

		if( !_moduleFrame ) {
			result ~= "\r\nNO MODULE FRAME\r\n";
		} else {
			result ~= "\r\nMODULE FRAME SYMBOLS:\r\n" ~ _moduleFrame.toPrettyStr() ~ "\r\n";
		}

		result ~= "\r\n";

		return result;
	}
}