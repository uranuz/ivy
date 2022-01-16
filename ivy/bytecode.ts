export enum OpCode {
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


export class Instruction {
	opcode: number;
	arg: number;

	constructor(opcode?: number, arg?: number) {
		this.opcode = opcode; // So... it's instruction opcode
		this.arg = arg; // One arg for now
	}

	get name(): string {
		return OpCode[this.opcode];
	}

	toString(): string {
		return this.name + " (" + this.opcode + ")" + ": " + this.arg;
	}
}