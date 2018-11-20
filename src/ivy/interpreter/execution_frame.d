module ivy.interpreter.execution_frame;

import ivy.common;
import ivy.interpreter.data_node: IvyData, IvyDataType;
import ivy.interpreter.data_node_types;

enum FrameSearchMode { get, tryGet, set, setWithParents }

class IvyExecutionFrameException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}


struct FrameSearchResult
{
	IvyData parent;
	IvyData node;
}

class ExecutionFrame
{
	alias LogerMethod = void delegate(LogInfo);
//private:
	CallableObject _callableObj;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	IvyData _dataDict;
	bool _isNoscope = false;

	ExecutionFrame _moduleFrame;

	// Loger method for used to send error and debug messages
	LogerMethod _logerMethod;

public:
	this(CallableObject callableObj, ExecutionFrame modFrame, IvyData dataDict, LogerMethod logerMethod, bool isNoscope)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;
		_dataDict = dataDict;
		_logerMethod = logerMethod;
		_isNoscope = isNoscope;
	}

	version(IvyInterpreterDebug)
		enum isDebugMode = true;
	else
		enum isDebugMode = false;

	static struct LogerProxy {
		mixin LogerProxyImpl!(IvyExecutionFrameException, isDebugMode);
		ExecutionFrame frame;

		string sendLogInfo(LogInfoType logInfoType, string msg)
		{
			if( frame._logerMethod !is null ) {
				frame._logerMethod(LogInfo(msg, logInfoType, getShortFuncName(func), file, line));
			}
			return msg;
		}
	}

	LogerProxy loger(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__)	{
		return LogerProxy(func, file, line, this);
	}

	IvyData getValue(string varName)
	{
		import std.algorithm: canFind;
		FrameSearchResult res = this.findValue!(FrameSearchMode.get)(varName);
		if( res.parent.isUndef ) {
			loger.error("Cannot find variable with name: " ~ varName );
		}
		return res.node;
	}

	bool canFindValue(string varName) {
		return !this.findValue!(FrameSearchMode.tryGet)(varName).parent.isUndef;
	}

	IvyDataType getDataNodeType(string varName) {
		return this.getValue(varName).type;
	}

	// Basic method used to search symbols in context
	// This method searches inside current frame without taking _moduleFrame into account
	FrameSearchResult findLocalValue(FrameSearchMode mode)(string varName)
	{
		import std.conv: text;
		import std.range: empty, front, popFront;
		import std.algorithm: canFind;
		import std.array: split;

		loger.write(`Start searching for variable with name: `, varName);

		if( varName.empty )
			loger.error( "Variable name cannot be empty" );

		string[] nameSplitted = varName.split('.');
		FrameSearchResult res;
		res.node = this._dataDict;
		size_t partIdx = 0;
		for( ; partIdx < nameSplitted.length; ++partIdx )
		{
			string namePart = nameSplitted[partIdx]; // Get current part of var name
			IvyData parent = res.node; // Extract new parent
			res = FrameSearchResult(); // Erase result at the start

			switch( parent.type )
			{
				case IvyDataType.AssocArray:
				{
					if( IvyData* nodePtr = namePart in parent ) {
						// If node exists in assoc array then push it as next parent node (or as a result if it's the last)
						res = FrameSearchResult(parent, *nodePtr);
					}
					else
					{
						static if( mode == FrameSearchMode.setWithParents ) {
							// In setWithParents mode we create parent nodes as assoc array if they are not exist
							IvyData newDict = ["__mentalModuleMagic_0451__": 451]; // Allocating dict
							newDict.assocArray.remove("__mentalModuleMagic_0451__");
							parent[namePart] = newDict;
							res = FrameSearchResult(parent, newDict);
						} else static if( mode == FrameSearchMode.set ) {
							// To be able to set new property (that not exist for now) of object we must return it's parent
							res = FrameSearchResult(parent);
						}
					}
					break;
				}
				case IvyDataType.ExecutionFrame:
				{
					loger.write(`Searching for node: `, namePart, ` in execution frame`);
					loger.internalAssert(
						parent.execFrame !is null,
						`Cannot find node, because execution frame is null!!!`);
					loger.internalAssert(
						parent.execFrame._dataDict.type != IvyDataType.AssocArray,
						`Cannot find node, because execution frame is null!!!`);

					if( IvyData* nodePtr = namePart in parent.execFrame._dataDict ) {
						res = FrameSearchResult(parent, *nodePtr);
					} else {
						static if( [FrameSearchMode.setWithParents, FrameSearchMode.set].canFind(mode) ) {
							loger.error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ namePart
								~ ` not exists or cannot set value in foreign execution frame!`
							);
						}
					}
					break;
				}
				case IvyDataType.ClassNode:
				{
					if( !parent.classNode )
					{
						static if( mode == FrameSearchMode.tryGet ) {
							break;
						} else {
							loger.error(`Cannot find node, because class node is null!!!`);
						}
					}

					// If there is class nodes in the path to target path, so it's property this way
					// No matter if it's set or get mode. The last node setting is handled by code at the start of loop
					IvyData tmpNode = parent.classNode.__getAttr__(namePart);
					if( !tmpNode.isUndef ) {
						res = FrameSearchResult(parent, tmpNode);
					} else {
						static if( [FrameSearchMode.setWithParents, FrameSearchMode.set].canFind(mode) ) {
							loger.error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ namePart
								~ `not exist or cannot add new attribute to class node!`
							);
						}
					}
					break;
				}
				default: break;
			}
			static if( mode == FrameSearchMode.get )
			{
				if( nameSplitted.length > 1 && (nameSplitted.length - partIdx) == 1 && res.parent.isUndef ) {
					// If this name part is a property of object (not a stand alone var) then return that we found "undefined" value
					// For this we should put parent on it's place
					res.parent = parent;
				}
			}
		}
		return res;
	}

	FrameSearchResult findValue(FrameSearchMode mode)(string varName)
	{
		loger.write(`Searching for node with full path: `, varName);

		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		FrameSearchResult res = this.findLocalValue!(mode)(varName);
		loger.write(`Current level exec frame is noscope. So search only in connected _moduleFrame`);

		if( !res.parent.isUndef ) {
			return res;
		}

		loger.write(`Node: `, varName, ` NOT found in exec frame. Try to find in module frame`);

		FrameSearchResult modResult;
		if( _moduleFrame ) {
			modResult = _moduleFrame.findLocalValue!(mode)(varName);
		} else {
			loger.write(`Cannot find: `, varName, ` in module exec frame. Module frame is null!`);
		}

		if( !modResult.parent.isUndef ) {
			return modResult;
		}
		return res;
	}

	private void _assignNodeAttribute(ref IvyData parent, ref IvyData value, string varName)
	{
		import std.array: split;
		import std.range: back;
		string attrName = varName.split.back;
		switch( parent.type )
		{
			case IvyDataType.AssocArray:
				parent.assocArray[attrName] = value;
				break;
			case IvyDataType.ClassNode:
				if( !parent.classNode ) {
					loger.error(`Cannot assign attribute, because class node is null`);
				}
				parent.classNode.__setAttr__(value, attrName);
				break;
			default:
				loger.error(`Cannot assign atribute of node with type: `, parent.type);
		}
	}

	void setValue(string varName, IvyData value)
	{
		loger.write(`Attempt to set node with full path: `, varName, ` with value: `, value);
		FrameSearchResult res = findValue!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(res.parent, value, varName);
	}

	void setValueWithParents(string varName, IvyData value)
	{
		loger.write(`Call ExecutionFrame.setValueWithParents with varName: `, varName, ` and value: `, value);
		FrameSearchResult res = findValue!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(res.parent, value, varName);
	}

	bool hasOwnScope() @property
	{
		return !_isNoscope;
	}

	CallableKind callableKind() @property
	{
		return _callableObj._kind;
	}

	override string toString()
	{
		return `<Exec frame for dir object "` ~ _callableObj._name ~ `">`;
	}

}