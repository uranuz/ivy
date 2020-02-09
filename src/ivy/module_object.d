module ivy.module_object;

/**
	Module is inner runtime representation of source file.
	It consists of list of constants, list of code objects and other data
*/
class ModuleObject
{
	import ivy.interpreter.data_node: IvyData, IvyDataType, NodeEscapeState;
	import ivy.code_object: CodeObject;

	string _name; // Module name that used to reference it in source code
	string _fileName; // Source file name for this module
	size_t _entryPointIndex; // Index of callable in _consts that is entry point to module

	IvyData[] _consts; // List of constant data for this module

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
	size_t addConst(IvyData data)
	{
		import std.range: back;
		size_t index = _consts.length;
		_consts ~= data;
		_consts.back.escapeState = NodeEscapeState.Safe; // Consider all constants are Safe by default
		return index;
	}

	IvyData getConst(size_t index)
	{
		import std.conv: text;
		assert( index < _consts.length, `There is no constant with index ` ~ index.text ~ ` in module "` ~ _name ~ `"`);
		return _consts[index];
	}

	CodeObject mainCodeObject() @property
	{
		import std.conv: text;
		assert( _entryPointIndex < _consts.length, `Cannot get main code object, because there is no constant with index ` ~ _entryPointIndex.text );
		assert( _consts[_entryPointIndex].type == IvyDataType.CodeObject, `Cannot get main code object, because const with index ` ~ _entryPointIndex.text ~ ` is not code object`  );

		return _consts[_entryPointIndex].codeObject;
	}
}