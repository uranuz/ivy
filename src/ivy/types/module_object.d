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
	import std.json: JSONValue;

	IvyData[] _consts; // List of constant data for this module

public:
	this(ModuleSymbol symbol) {
		this.addConst(IvyData(new CodeObject(symbol, this)));
	}

	// Append const to list and return it's index
	size_t addConst(IvyData data)
	{
		// Get index of added constant
		size_t index = this._consts.length;
		// Consider all constants are Safe by default
		data.escapeState = NodeEscapeState.Safe; 
		this._consts ~= data;
		return index;
	}

	IvyData getConst(size_t index)
	{
		import std.conv: text;
		enforce(index < _consts.length, "There is no constant with index " ~ index.text ~ " in module: " ~ symbol.name);
		return this._consts[index];
	}

	CodeObject mainCodeObject() @property {
		return this.getConst(0).codeObject;
	}

	ModuleSymbol symbol() @property
	{
		ModuleSymbol modSymbol = cast(ModuleSymbol) this.mainCodeObject.symbol;
		enforce(modSymbol !is null, "Expected module symbol");
		return modSymbol;
	}
	
	string name() @property {
		return this.symbol.name;
	}

	string fileName() @property {
		return this.symbol.location.fileName;
	}

	JSONValue toStdJSON()
	{
		import ivy.types.data.conv.ivy_to_std_json: toStdJSON2;
		import ivy.types.data.conv.consts: IvySrlField;
		import std.algorithm: map;
		import std.array: array;

		return JSONValue([
			"consts": JSONValue(map!toStdJSON2(this._consts).array),
			IvySrlField.type: JSONValue(IvyDataType.ModuleObject)
		]);
	}
}