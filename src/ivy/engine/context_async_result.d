module ivy.engine.context_async_result;

struct ContextAsyncResult
{
	import ivy.types.data.async_result: AsyncResult;
	import ivy.interpreter.interpreter: Interpreter;

	Interpreter interp;
	AsyncResult asyncResult;
}