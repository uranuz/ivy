export enum IvyDataType {
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
	IvyDataRange,
	AsyncResult,
	ModuleObject
}

export enum NodeEscapeState {
	Init,
	Safe,
	Unsafe
}

export enum AsyncResultState {
	'Init',
	'Pending',
	'Success',
	'Error'
}

export enum DateTimeAttr {
	year = "year",
	month = "month",
	day = "day",
	hour = "hour",
	minute = "minute",
	second = "second",
	millisecond = "millisecond",
	dayOfWeek = "dayOfWeek",
	dayOfYear = "dayOfYear",
	utcMinuteOffset = "utcMinuteOffset"
}