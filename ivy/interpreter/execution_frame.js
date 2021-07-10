define('ivy/interpreter/execution_frame', [
	'ivy/exception',
	'ivy/location',
	'ivy/utils',
	'ivy/bytecode',
	'ivy/interpreter/exec_frame_info'
], function(
	IvyException,
	Location,
	iutil,
	Bytecode,
	ExecFrameInfo
) {
var
	Instruction = Bytecode.Instruction,
	assure = iutil.ensure.bind(iutil, IvyException);
return FirClass(
function ExecutionFrame(callable, dataDict) {
	assure(callable, "Expected callable object for exec frame");

	this._callable = callable;
	this._instrIndex = 0;
	this._dataDict = dataDict || {};

	this._dataDict["_ivyMethod"] = this._callable.symbol.name;
	this._dataDict["_ivyModule"] = this._callable.moduleSymbol.name;
}, {
	hasValue: function(varName) {
		return this._dataDict.hasOwnProperty(varName);
	},

	getValue: function(varName) {
		assure(
			this.hasValue(varName),
			"Cannot find variable with name \"", varName, "\" in exec frame for symbol \"", this.callable.symbol.name, "\"");
		return this._dataDict[varName];
	},

	setValue: function(varName, value) {
		this._dataDict[varName] = value;
	},

	setJump: function(instrIndex) {
		if( this.callable.isNative )
			return; // Cannot set jump for native directive
		assure(
			instrIndex <= this.callable.codeObject.instrs.length,
			"Cannot jump after the end of code object");
		this._instrIndex = instrIndex;
	},

	nextInstr: function() {
		++this._instrIndex;
	},

	callable: firProperty(function() {
		return this._callable;
	}),

	hasInstrs: firProperty(function() {
		if( this.callable.isNative )
			return false; 
		return this._instrIndex < this.callable.codeObject.instrCount;
	}),

	currentInstr: firProperty(function() {
		if( !this.hasInstrs )
			return Instruction(); // Cannot get instruction for native directive
		return this.callable.codeObject.instrs[this._instrIndex];
	}),

	dict: firProperty(function() {
		return this._dataDict;
	}),

	currentLocation: firProperty(function() {
		var loc = Location();

		loc.fileName = this.callable.moduleSymbol.name;
		loc.lineIndex = this.currentInstrLine;

		return loc;
	}),

	info: firProperty(function() {
		var info = ExecFrameInfo();

		info.callableName = this.callable.symbol.name;
		info.location = this.currentLocation;
		info.instrIndex = this._instrIndex;
		info.opcode = this.currentInstr.opcode;

		return info;
	}),

	toString: function() {
		return "<Exec frame for dir object \"" + this.callable.symbol.name + "\">";
	}
});
});