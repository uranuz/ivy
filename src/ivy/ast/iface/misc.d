module ivy.ast.iface.misc;

interface IIdentifier
{
	@property {
		string name();
	}
}

class Identifier: IIdentifier
{
private:
	string _fullName;


public:
	this( string fullName )
	{
		_fullName = fullName;
	}

	override @property {
		string name()
		{
			return _fullName;
		}
	}
}
