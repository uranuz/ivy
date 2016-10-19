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
	NotEqual,
	LTEqual,
	GTEqual,

	// Frame data load/ store
	StoreLocal,
	LoadLocal,

	// Preparing and calling directives
	LoadDirective,
	CallDirective

	// Import another module
	ImportModule,
	ImportFrom


}