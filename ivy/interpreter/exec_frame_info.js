define('ivy/interpreter/exec_frame_info', [
	'ivy/bytecode',
	'ivy/location'
], function(
	Bytecode,
	Location
) {
var OpCode = Bytecode.OpCode;
return FirClass(
	function ExecFrameInfo() {
		var inst = firPODCtor(this, arguments);
		if( inst ) return inst;

		this.callableName = null;
		this.location = Location();
		this.instrIndex = 0;
		this.opcode = OpCode.InvalidOpcode;
	}, {
		toString: function() {
			return "Module: " + this.location.fileName + ":" + this.instrIndex + ", callable: " + this.callableName + ", opcode: " + this.opcode;
		}
	});
});