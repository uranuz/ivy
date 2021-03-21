///Module consists of declarations related to Ivy bytecode
module ivy.bytecode;

enum OpCode: ubyte
{
	InvalidCode, // Used to check if code of operation was not properly set

	Nop,

	// Load constant data from code
	LoadConst,

	// Stack operations
	PopTop,
	SwapTwo,
	DubTop,

	// General unary operations opcodes
	UnaryMin,
	UnaryPlus,
	UnaryNot,

	// Arithmetic binary operations opcodes
	Add,
	Sub,
	Mul,
	Div,
	Mod,

	// Comparision operations opcodes
	Equal,
	NotEqual,
	LT,
	GT,
	LTEqual,
	GTEqual,

	// Frame data load/ store
	StoreName,
	StoreGlobalName,
	LoadName,

	// Work with attributes
	StoreAttr,
	LoadAttr,

	// Data construction opcodes
	MakeArray,
	MakeAssocArray,
	MakeClass,

	// Array or assoc array operations
	StoreSubscr,
	LoadSubscr,
	LoadSlice,

	// Arrays or strings concatenation
	Concat,
	Append,
	Insert,

	// Flow control opcodes
	JumpIfTrue,
	JumpIfFalse,
	JumpIfTrueOrPop,
	JumpIfFalseOrPop,
	Jump,
	Return,

	// Loop initialization and execution
	GetDataRange,
	RunLoop,

	// Import another module
	ImportModule,
	FromImport,
	LoadFrame,

	// Preparing and calling directives
	MakeCallable,
	RunCallable,
	Await
}

// Minimal element of bytecode is instruction opcode with optional arg
struct Instruction
{
	import std.json: JSONValue;

	OpCode opcode = OpCode.InvalidCode; // So... it's instruction opcode
	size_t arg; // One arg for now

	string name() @property
	{
		import std.conv: text;
		return this.opcode.text;
	}

	string toString()
	{
		import std.conv: text;
		return this.name ~ ": " ~ this.arg.text;
	}

	JSONValue toStdJSON() {
		return JSONValue([JSONValue(this.opcode), JSONValue(this.arg)]);
	}
}
