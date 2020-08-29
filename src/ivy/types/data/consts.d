module ivy.types.data.consts;

enum IvyDataType: ubyte {
	Undef,
	Null,
	Boolean,
	Integer,
	Floating,
	String,
	Array,
	AssocArray,
	ClassNode,
	CodeObject,
	Callable,
	ExecutionFrame,
	DataNodeRange,
	AsyncResult,
	ModuleObject // Used for serialization
}

enum NodeEscapeState: ubyte {
	Init, Safe, Unsafe
}