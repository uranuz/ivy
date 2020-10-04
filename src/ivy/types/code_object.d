module ivy.types.code_object;

/** Debugging info */
struct SourceMapItem
{
	size_t line; // Source code line index
	size_t startInstr; // Index of first instruction
}

/**
	Code object is inner runtime representation of chunk of source file.
	Usually it's representation of directive or module.
	Code object consists of list of instructions and other metadata
*/
class CodeObject
{
	import ivy.bytecode: Instruction;
	import ivy.types.module_object: ModuleObject;
	import ivy.types.symbol.iface: ICallableSymbol;

	import std.exception: enforce;

	ICallableSymbol _symbol;
	Instruction[] _instrs; // Plain list of instructions
	ModuleObject _moduleObject; // Module object which contains this code object

	SourceMapItem[] _sourceMap; // Debugging info (source map sorted by line)
	SourceMapItem[] _revSourceMap; // Debugging info (source map sorted by startInstr)

public:
	this(ICallableSymbol symbol, ModuleObject moduleObject)
	{
		this._symbol = symbol;
		this._moduleObject = moduleObject;

		enforce(this._symbol !is null, `Expected code object symbol`);
		enforce(this._moduleObject !is null, `Expected module object`);
	}

	ICallableSymbol symbol() @property {
		return this._symbol;
	}

	ModuleObject moduleObject() @property {
		return this._moduleObject;
	}

	size_t addInstr(Instruction instr, size_t line)
	{
		size_t index = this._instrs.length;
		this._instrs ~= instr;
		this._addSourceMapItem(line, index);
		return index;
	}

	void setInstrArg(size_t index, size_t arg)
	{
		enforce(
			index < this._instrs.length,
			"Cannot set argument 0 of instruction, because instruction not exists!");
		this._instrs[index].arg = arg;
	}

	size_t getInstrCount() {
		return this._instrs.length;
	}

	// Get line where code object instruction is located
	size_t getInstrLine(size_t instrIndex)
	{
		auto sMap = this._checkRevSourceMap();
		auto lowerB = sMap.lowerBound(SourceMapItem(0, instrIndex));
		if( lowerB.length < this._revSourceMap.length ) {
			return this._revSourceMap[lowerB.length].line;
		}
		return 0;
	}

	static auto _sourceMapByLinePred(SourceMapItem one, SourceMapItem other) {
		return one.line < other.line;
	}

	static auto _sourceMapByAddrPred(SourceMapItem one, SourceMapItem other) {
		return one.startInstr < other.startInstr;
	}

	void _addSourceMapItem(size_t line, size_t instrIndex)
	{
		import std.range: assumeSorted;
		import std.array: insertInPlace;
		auto sMap = assumeSorted!_sourceMapByLinePred(_sourceMap);
		auto trisectMap = sMap.trisect(SourceMapItem(line));
		size_t afterPos = trisectMap[0].length + trisectMap[1].length;
		if( trisectMap[1].length == 0 ) {
			this._sourceMap.insertInPlace(afterPos, SourceMapItem(line, instrIndex));
		} else if( trisectMap[1][0].startInstr > instrIndex ) {
			// If we find some addre that goes before current at the line then patch it
			this._sourceMap[trisectMap[0].length].startInstr = instrIndex;
		}
	}

	auto _checkRevSourceMap()
	{
		import std.algorithm: sort;
		import std.range: assumeSorted;
		if( this._revSourceMap.length == 0)
		{
			this._revSourceMap = this._sourceMap.dup;
			this._revSourceMap.sort!_sourceMapByAddrPred();
		}
		return assumeSorted!_sourceMapByAddrPred(this._revSourceMap);
	}

	override bool opEquals(Object o)
	{
		auto rhs = cast(typeof(this)) o;
		if( rhs is null )
			return false;

		// Very shallow checks for equality, but think enough
		if( this.symbol.name != rhs.symbol.name ) {
			return false;
		}

		// At least want to see the same number of instructions
		if( this._instrs.length != rhs._instrs.length ) {
			return false;
		}
		if( (this.moduleObject is null) != (rhs.moduleObject is null) ) {
			return false;
		}
		// Must be from the same module
		if( this.moduleObject.symbol.name && this.moduleObject.symbol.name != rhs.moduleObject.symbol.name ) {
			return false;
		}
		return true; // They are equal at the first look
	}
}