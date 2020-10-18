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

enum AsyncResultState: ubyte {
	pending,
	resolved,
	rejected
}

enum DateTimeAttr: string
{
	year = `year`,
	month = `month`,
	day = `day`,
	hour = `hour`,
	minute = `minute`,
	second = `second`,
	millisecond = `millisecond`,
	dayOfWeek = `dayOfWeek`,
	dayOfYear = `dayOfYear`,
	utcMinuteOffset = `utcMinuteOffset`
}
