module ivy.interpreter.execution_frame;

import ivy.common;
import ivy.interpreter.data_node;
import ivy.interpreter.data_node_types;

enum FrameSearchMode { get, tryGet, set, setWithParents };

class IvyExecutionFrameException: IvyException
{
public:
	@nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
	{
		super(msg, file, line, next);
	}
}

class ExecutionFrame
{
	alias LogerMethod = void delegate(LogInfo);
	alias TDataNode = DataNode!string;
//private:
	CallableObject _callableObj;

	/*
		Type of _dataDict should be Undef or Null if directive call or something that represented
		by this ExecutionFrame haven't it's own data scope and uses parent scope for data.
		In other cases _dataDict should be of AssocArray type for storing local variables
	*/
	TDataNode _dataDict;

	ExecutionFrame _moduleFrame;

	// Loger method for used to send error and debug messages
	LogerMethod _logerMethod;

public:
	this(CallableObject callableObj, ExecutionFrame modFrame, TDataNode dataDict, LogerMethod logerMethod)
	{
		_callableObj = callableObj;
		_moduleFrame = modFrame;
		_dataDict = dataDict;
		_logerMethod = logerMethod;
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

	TDataNode getValue(string varName)
	{
		SearchResult result = findValue!(FrameSearchMode.get)(varName);
		if( result.node.isUndef && !result.allowUndef )
			loger.error("Cannot find variable with name: " ~ varName );
		return result.node;
	}

	bool canFindValue(string varName) {
		return !findValue!(FrameSearchMode.tryGet)(varName).node.isUndef;
	}

	DataNodeType getDataNodeType(string varName)
	{
		SearchResult result = findValue!(FrameSearchMode.get)(varName);
		if( result.node.isUndef  )
			loger.error("Cannot find variable with name: " ~ varName);
		return result.node.type;
	}

	import std.typecons: Tuple;
	alias SearchResult = Tuple!(bool, "allowUndef", TDataNode, "node");

	// Basic method used to search symbols in context
	// This method searches inside current frame without taking _moduleFrame into account
	SearchResult findLocalValue(FrameSearchMode mode)(string varName)
	{
		import std.conv: text;
		import std.range: empty, front, popFront;
		import std.algorithm: canFind;
		import std.array: split;

		loger.write(`Start searching for variable with name: `, varName);

		if( varName.empty )
			loger.error( "Variable name cannot be empty" );

		if( _dataDict.type != DataNodeType.AssocArray )
		{
			static if( mode == FrameSearchMode.tryGet ) {
				return SearchResult(false, TDataNode.makeUndef());
			} else {
				loger.error("Cannot find variable: " ~ varName ~ " in execution frame, because callable doesn't have it's on scope!");
			}
		}
		TDataNode node = _dataDict;

		string[] nameSplitted = varName.split('.');
		size_t namePartsCount = nameSplitted.length;
		bool allowUndef = false;
		while( !nameSplitted.empty )
		{
			// Determines if in get mode we can return undef without error
			allowUndef = nameSplitted.length == 1 && namePartsCount > 1;

			static if( mode == FrameSearchMode.set || mode == FrameSearchMode.setWithParents )
			{
				// In set mode we return parent node instead of target node when getting the last node in the path
				if( nameSplitted.length == 1 ) {
					return SearchResult(false, node);
				}
			}

			switch( node.type )
			{
				case DataNodeType.AssocArray:
				{
					loger.write(`Searching for node: `, nameSplitted.front, ` in assoc array`);
					if( TDataNode* nodePtr = nameSplitted.front in node.assocArray )
					{
						// If node exists in assoc array then push it as next parent node (or as a result if it's the last)
						loger.write(`Node: `, nameSplitted.front, ` found in assoc array`);
						node = *nodePtr;
					}
					else
					{
						loger.write(`Node: `, nameSplitted.front, ` is NOT found in assoc array`);
						static if( mode == FrameSearchMode.setWithParents ) {
							// In setWithParents mode we create parent nodes as assoc array if they are not exist
							loger.write(`Creating node: `, nameSplitted.front, `, because mode is: `, mode);
							TDataNode parentDict;
							parentDict["__mentalModuleMagic_0451__"] = 451; // Allocating dict
							parentDict.assocArray.remove("__mentalModuleMagic_0451__");
							node.assocArray[nameSplitted.front] = parentDict;
							node = node.assocArray[nameSplitted.front];
						} else static if( mode == FrameSearchMode.set ) {
							// Only parent node should get there. And if it's not exists then issue an error in the set mode
							loger.error(`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ nameSplitted.front.text ~ ` not exist!`);
						} else {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						}
					}
					break;
				}
				case DataNodeType.ExecutionFrame:
				{
					loger.write(`Searching for node: `, nameSplitted.front, ` in execution frame`);
					if( !node.execFrame )
					{
						static if( mode == FrameSearchMode.tryGet ) {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						} else {
							loger.error(`Cannot find node, because execution frame is null!!!`);
						}
					}

					if( node.execFrame._dataDict.type != DataNodeType.AssocArray )
					{
						static if( mode == FrameSearchMode.tryGet ) {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						} else {
							loger.error(`Cannot find node, because execution frame data dict is not of assoc array type!!!`);
						}
					}

					if( TDataNode* nodePtr = nameSplitted.front in node.execFrame._dataDict.assocArray ) {
						loger.write(`Node: `, nameSplitted.front, ` found in execution frame`);
						node = *nodePtr;
					} else {
						loger.write(`Node: `, nameSplitted.front, ` is NOT found in execution frame`);
						static if( mode == FrameSearchMode.setWithParents || mode == FrameSearchMode.set ) {
							loger.error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ nameSplitted.front.text
								~ ` not exists or cannot set value in foreign execution frame!`
							);
						} else {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						}
					}
					break;
				}
				case DataNodeType.ClassNode:
				{
					loger.write(`Searching for node: `, nameSplitted.front, ` in class node`);
					if( !node.classNode )
					{
						static if( mode == FrameSearchMode.tryGet ) {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						} else {
							loger.error(`Cannot find node, because class node is null!!!`);
						}
					}

					// If there is class nodes in the path to target path, so it's property this way
					// No matter if it's set or get mode. The last node setting is handled by code at the start of loop
					TDataNode tmpNode = node.classNode.__getAttr__(nameSplitted.front);
					if( !node.isUndef )  {
						node = tmpNode;
					} else {
						static if( mode == FrameSearchMode.setWithParents || mode == FrameSearchMode.set ) {
							loger.error(
								`Cannot set node with name: ` ~ varName ~ `, because parent node: ` ~ nameSplitted.front.text
								~ `not exist or cannot add new attribute to class node!`
							);
						} else {
							return SearchResult(allowUndef, TDataNode.makeUndef());
						}
					}
					break;
				}
				default:
				{
					loger.write(`Attempt to search: `, nameSplitted.front, `, but current node is not of dict-like type`);
					return SearchResult(false, TDataNode.makeUndef());
				}
			}

			nameSplitted.popFront();// Advance to the next section in the path
		}

		return SearchResult(allowUndef || node.isUndef, node);
	}

	SearchResult findValue(FrameSearchMode mode)(string varName)
	{
		loger.write(`Searching for node with full path: `, varName);

		// If current frame has it's own scope then try to find in it.
		// If it is noscope then search into it's _moduleFrame, because we could still have some symbols there
		if( this.hasOwnScope )
		{
			SearchResult result = findLocalValue!(mode)(varName);
			if( !result.node.isUndef || (result.node.isUndef && result.allowUndef) )
				return result;
		} else {
			loger.write(`Current level exec frame is noscope. So search only in connected _moduleFrame`);
		}

		loger.write(`Node: `, varName, ` NOT foind in exec frame. Try to find in module frame`);

		if( _moduleFrame )
			return _moduleFrame.findLocalValue!(mode)(varName);

		loger.write(`Cannot find: `, varName, ` in module exec frame. Module frame is null!`);
		return SearchResult(false, TDataNode.makeUndef());
	}

	private void _assignNodeAttribute(ref TDataNode parent, ref TDataNode value, string varName)
	{
		import std.array: split;
		import std.range: back;
		string attrName = varName.split.back;
		switch( parent.type )
		{
			case DataNodeType.AssocArray:
				parent.assocArray[attrName] = value;
				break;
			case DataNodeType.ClassNode:
				if( !parent.classNode ) {
					loger.error(`Cannot assign attribute, because class node is null`);
				}
				parent.classNode.__setAttr__(value, attrName);
				break;
			default:
				loger.error(`Cannot assign atribute of node with type: `, parent.type);
		}
	}

	void setValue(string varName, TDataNode value)
	{
		loger.write(`Attempt to set node with full path: `, varName, ` with value: `, value);
		SearchResult result = findValue!(FrameSearchMode.set)(varName);
		_assignNodeAttribute(result.node, value, varName);
	}

	void setValueWithParents(string varName, TDataNode value)
	{
		loger.write(`Call ExecutionFrame.setValueWithParents with varName: `, varName, ` and value: `, value);
		SearchResult result = findValue!(FrameSearchMode.setWithParents)(varName);
		_assignNodeAttribute(result.node, value, varName);
	}

	bool hasOwnScope() @property
	{
		return _dataDict.type == DataNodeType.AssocArray;
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