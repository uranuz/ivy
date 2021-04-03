module ivy.interpreter.execution_frame;

import ivy.exception: IvyException;

class ExecutionFrame
{
	import trifle.location: Location;
	import trifle.utils: ensure;

	import ivy.types.data: IvyData, IvyDataType;
	import ivy.types.callable_object: CallableObject;

	import ivy.interpreter.exec_frame_info: ExecFrameInfo;
	import ivy.interpreter.exception: IvyInterpretException;
	import ivy.bytecode: Instruction;

	alias assure = ensure!IvyInterpretException;

private:
	// Callable object that is attached to execution frame
	CallableObject _callable;

	// Index of currently executed instruction
	size_t _instrIndex = 0;

public IvyData[string] _dataDict;

public:
	this(CallableObject callable, IvyData[string] dataDict = null)
	{
		this._callable = callable;
		assure(this._callable, "Expected callable object for exec frame");

		this._dataDict = dataDict;
		this._dataDict["_ivyMethod"] = this._callable.symbol.name;
		this._dataDict["_ivyModule"] = this._callable.moduleSymbol.name;
	}

	bool hasValue(string varName) {
		return (varName in this._dataDict) !is null;
	}

	IvyData getValue(string varName)
	{
		IvyData* res = varName in this._dataDict;
		assure(res, "Cannot find variable with name \"" ~ varName ~ "\" in exec frame for symbol \"" ~ this.callable.symbol.name ~ "\"");
		return *res;
	}

	void setValue(string varName, IvyData value) {
		this._dataDict[varName] = value;
	}

	void setJump(size_t instrIndex)
	{
		if( this.callable.isNative )
			return; // Cannot set jump for native directive
		assure(instrIndex <= this.callable.codeObject.instrs.length, "Cannot jump after the end of code object");
		this._instrIndex = instrIndex;
	}

	void nextInstr() {
		++this._instrIndex;
	}

	CallableObject callable() @property
	{
		assure(this._callable, "No callable for global execution frame");
		return this._callable;
	}

	bool hasInstrs() @property
	{
		if( this.callable.isNative )
			return false; 
		return this._instrIndex < this.callable.codeObject.instrCount;
	}

	Instruction currentInstr() @property
	{
		if( !this.hasInstrs )
			return Instruction(); // Cannot get instruction for native directive
		return this.callable.codeObject.instrs[this._instrIndex];
	}

	size_t currentInstrLine() @property
	{
		if( !this.hasInstrs )
			return 0; // Cannot tell instr line for native directive
		return this.callable.codeObject.getInstrLine(this._instrIndex);
	}

	Location currentLocation() @property
	{
		Location loc;

		loc.fileName = this.callable.moduleSymbol.name;
		loc.lineIndex = this.currentInstrLine;

		return loc;
	}

	ExecFrameInfo info() @property
	{
		ExecFrameInfo info;

		info.callableName = this.callable.symbol.name;
		info.location = this.currentLocation;
		info.instrIndex = this._instrIndex;
		info.opcode = this.currentInstr.opcode;

		return info;
	}

	override string toString() {
		return "<Exec frame for dir object \"" ~ this.callable.symbol.name ~ "\">";
	}
}