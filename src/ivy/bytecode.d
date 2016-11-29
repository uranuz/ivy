///Module consists of declarations related to Ivy bytecode
module ivy.bytecode;

enum OpCode: ubyte {
	InvalidCode, // Used to check if code of operation was not properly set

	Nop,

	// Load constant data from code
	LoadConst,

	// Arithmetic binary operations opcodes
	Add,
	Sub,
	Mul,
	Div,
	Mod,

	// Arrays or strings concatenation
	Concat,
	Append,

	// General unary operations opcodes
	UnaryMin,
	UnaryPlus,
	UnaryNot,

	// Logical binary operations opcodes
	And,
	Or,
	Xor,

	// Comparision operations opcodes
	LT,
	GT,
	Equal,
	LTEqual,
	GTEqual,

	// Array or assoc array operations
	LoadSubscr,
	StoreSubscr,

	// Frame data load/ store
	StoreName,
	StoreLocalName,
	LoadName,

	// Preparing and calling directives
	LoadDirective,
	CallDirective,

	// Import another module
	ImportModule,
	ImportFrom,

	// Flow control opcodes
	JumpIfTrue,
	JumpIfFalse,
	Jump,
	Return,

	// Stack operations
	PopTop,

	// Loop initialization and execution
	InitLoop,
	RunIter

}

// Minimal element of bytecode is instruction opcode with optional args
struct Instruction
{
	OpCode opcode; // So... it's instruction opcode
	uint[1] args; // One arg for now
}
