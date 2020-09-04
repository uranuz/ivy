module ivy.types.module_object;

/**
	Module is inner runtime representation of source file.
	It consists of list of module data including constants and code objects
*/
class ModuleObject
{
	import ivy.types.data: IvyData, IvyDataType, NodeEscapeState;
	import ivy.types.code_object: CodeObject;

	import ivy.types.symbol.module_: ModuleSymbol;

	import std.exception: enforce;

	IvyData[] _consts; // List of constant data for this module

public:
	this(ModuleSymbol symbol) {
		this._consts ~= IvyData(new CodeObject(symbol, this));
	}

	ModuleSymbol symbol() @property
	{
		ModuleSymbol modSymbol = cast(ModuleSymbol) this.mainCodeObject.symbol;
		enforce(modSymbol !is null, `Expected module symbol`);
		return modSymbol;
	}
	
	string name() @property {
		return symbol.name;
	}

	string fileName() @property {
		return symbol.fileName;
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
		enforce(index < _consts.length, `There is no constant with index ` ~ index.text ~ ` in module "` ~ symbol.name ~ `"`);
		return _consts[index];
	}

	CodeObject mainCodeObject() @property
	{
		IvyData codeObjNode = this.getConst(0);
		enforce(codeObjNode.type == IvyDataType.CodeObject, `First constant of module object expected to be it's main code object`);

		return codeObjNode.codeObject;
	}
}