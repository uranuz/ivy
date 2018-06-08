module ivy.code_object;

import ivy.interpreter.data_node: DataNode, DataNodeType, NodeEscapeState;
import ivy.directive_stuff: DirAttrsBlock;

/**
	Module is inner runtime representation of source file.
	It consists of list of constants, list of code objects and other data
*/
class ModuleObject
{
	alias TDataNode = DataNode!string;

	string _name; // Module name that used to reference it in source code
	string _fileName; // Source file name for this module
	size_t _entryPointIndex; // Index of callable in _consts that is entry point to module

	TDataNode[] _consts; // List of constant data for this module

public:
	this(string name, string fileName)
	{
		_name = name;
		_fileName = fileName;
	}
	
	string name() @property {
		return _name;
	}

	string fileName() @property {
		return _fileName;
	}

	// Append const to list and return it's index
	// This function can return index of already existing object if it's equal to passed data
	size_t addConst(TDataNode data)
	{
		import std.range: back;
		size_t index = _consts.length;
		_consts ~= data;
		_consts.back.escapeState = NodeEscapeState.Safe; // Consider all constants are Safe by default
		return index;
	}

	TDataNode getConst(size_t index)
	{
		import std.conv: text;
		assert( index < _consts.length, `There is no constant with index ` ~ index.text ~ ` in module "` ~ _name ~ `"`);
		return _consts[index];
	}

	CodeObject mainCodeObject() @property
	{
		import std.conv: text;
		assert( _entryPointIndex < _consts.length, `Cannot get main code object, because there is no constant with index ` ~ _entryPointIndex.text );
		assert( _consts[_entryPointIndex].type == DataNodeType.CodeObject, `Cannot get main code object, because const with index ` ~ _entryPointIndex.text ~ ` is not code object`  );

		return _consts[_entryPointIndex].codeObject;
	}
}

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

	Instruction[] _instrs; // Plain list of instructions
	DirAttrsBlock!(false)[] _attrBlocks;
	ModuleObject _moduleObj; // Module object which contains this code object

	SourceMapItem[] _sourceMap; // Debugging info (source map sorted by line)
	SourceMapItem[] _revSourceMap; // Debugging info (source map sorted by startInstr)

public:
	this(ModuleObject moduleObj) {
		_moduleObj = moduleObj;
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
}