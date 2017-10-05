module ivy.code_object;

import ivy.interpreter.data_node: DataNode, DataNodeType;
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

	// Append const to list and return it's index
	// This function can return index of already existing object if it's equal to passed data
	size_t addConst(TDataNode data)
	{
		size_t index = _consts.length;
		_consts ~= data;
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

public:
	this(ModuleObject moduleObj) {
		_moduleObj = moduleObj;
	}

	size_t addInstr(Instruction instr)
	{
		size_t index = _instrs.length;
		_instrs ~= instr;
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
}