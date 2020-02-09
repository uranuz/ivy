module ivy.code_object;

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
	import ivy.directive_stuff: DirAttrsBlock;
	import ivy.interpreter.data_node: IvyData, IvyDataType, NodeEscapeState;
	import ivy.module_object: ModuleObject;

	string _name;
	Instruction[] _instrs; // Plain list of instructions
	DirAttrsBlock[] _attrBlocks;
	ModuleObject _moduleObj; // Module object which contains this code object

	SourceMapItem[] _sourceMap; // Debugging info (source map sorted by line)
	SourceMapItem[] _revSourceMap; // Debugging info (source map sorted by startInstr)

public:
	this(string name, ModuleObject moduleObj)
	{
		assert(name.length > 0, `Expected code object name`);
		assert(moduleObj !is null, `Expected module object`);
		_name = name;
		_moduleObj = moduleObj;
	}

	string name() @property {
		return _name;
	}

	size_t addInstr(Instruction instr, size_t line)
	{
		size_t index = _instrs.length;
		_instrs ~= instr;
		_addSourceMapItem(line, index);
		return index;
	}

	void setInstrArg(size_t index, size_t arg)
	{
		assert( index < _instrs.length, "Cannot set argument 0 of instruction, because instruction not exists!" );
		_instrs[index].arg = arg;
	}

	size_t getInstrCount() {
		return _instrs.length;
	}

	// Get line where code object instruction is located
	size_t getInstrLine(size_t instrIndex)
	{
		auto sMap = _checkRevSourceMap();
		auto lowerB = sMap.lowerBound(SourceMapItem(0, instrIndex));
		if( lowerB.length < _revSourceMap.length ) {
			return _revSourceMap[lowerB.length].line;
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
			_sourceMap.insertInPlace(afterPos, SourceMapItem(line, instrIndex));
		} else if( trisectMap[1][0].startInstr > instrIndex ) {
			// If we find some addre that goes before current at the line then patch it
			_sourceMap[trisectMap[0].length].startInstr = instrIndex;
		}
	}

	auto _checkRevSourceMap()
	{
		import std.algorithm: sort;
		import std.range: assumeSorted;
		if( _revSourceMap.length == 0) {
			_revSourceMap = _sourceMap.dup;
			_revSourceMap.sort!_sourceMapByAddrPred();
		}
		return assumeSorted!_sourceMapByAddrPred(_revSourceMap);
	}

	override bool opEquals(Object o)
	{
		auto rhs = cast(typeof(this)) o;
		if( rhs is null )
			return false;

		// Very shallow checks for equality, but think enough
		if( this._name != rhs._name ) {
			return false;
		}

		// At least want to see the same number of instructions
		if( this._instrs.length != rhs._instrs.length ) {
			return false;
		}
		if( (this._moduleObj is null) != (rhs._moduleObj is null) ) {
			return false;
		}
		// Must be from the same module
		if( this._moduleObj && this._moduleObj._name != rhs._moduleObj._name ) {
			return false;
		}
		return true; // They are equal at the first look
	}
}