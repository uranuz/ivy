module ivy.interpreter.exec_frame_info;

struct ExecFrameInfo
{
	import trifle.location: Location;
	import ivy.bytecode: OpCode;

	string callableName;
	Location location;
	size_t instrIndex;
	OpCode opcode;

	string toString()
	{
		import std.conv: text;
		return "Module: " ~ location.fileName ~ ":" ~ instrIndex.text ~ ", callable: " ~ callableName ~ ", opcode: " ~ opcode.text;
	}
}
