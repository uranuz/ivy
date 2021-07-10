///Module consists of declarations related to Ivy bytecode
module ivy.bytecode;

enum OpCode: ubyte
{
	InvalidCode = 0, // Used to check if code of operation was not properly set

	Nop = 1,

	// Load constant data from code
	LoadConst = 2,

	// Stack operations
	PopTop = 3,
	SwapTwo = 4,
	DubTop = 5,

	// General unary operations opcodes
	UnaryMin = 6,
	UnaryPlus = 7,
	UnaryNot = 8,

	// Arithmetic binary operations opcodes
	Add = 9,
	Sub = 10,
	Mul = 11,
	Div = 12,
	Mod = 13,

	// Comparision operations opcodes
	Equal = 14,
	NotEqual = 15,
	LT = 16,
	GT = 17,
	LTEqual = 18,
	GTEqual = 19,

	// Frame data load/ store
	StoreName = 20,
	StoreGlobalName = 21,
	LoadName = 22,

	// Work with attributes
	StoreAttr = 23,
	LoadAttr = 24,

	// Data construction opcodes
	MakeArray = 25,
	MakeAssocArray = 26,
	MakeClass = 27,

	// Array or assoc array operations
	StoreSubscr = 28,
	LoadSubscr = 29,
	LoadSlice = 30,

	// Arrays or strings concatenation
	Concat = 31,
	Append = 32,
	Insert = 33,

	// Flow control opcodes
	JumpIfTrue = 34,
	JumpIfFalse = 35,
	JumpIfTrueOrPop = 36,
	JumpIfFalseOrPop = 37,
	Jump = 38,
	Return = 39,

	// Loop initialization and execution
	GetDataRange = 40,
	RunLoop = 41,

	// Import another module
	ImportModule = 42,
	FromImport = 43,
	LoadFrame = 44,

	// Preparing and calling directives
	MakeCallable = 45,
	RunCallable = 46,
	Await = 47
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
		return this.name ~ " (" ~ (cast(ubyte) this.opcode).text ~ ")" ~ ": " ~ this.arg.text;
	}

	JSONValue toStdJSON() {
		return JSONValue([JSONValue(this.opcode), JSONValue(this.arg)]);
	}
}
