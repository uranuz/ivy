module ivy.types.data.not_impl_class_node;

import ivy.types.data.iface.class_node: IClassNode;

class NotImplClassNode: IClassNode
{
	import ivy.types.data.iface.range: IvyDataRange;
	import ivy.types.data: IvyData;
protected:
	string _getClassName() {
		return typeid(this).name;
	}
	enum string notImplMixin = `throw new PropertyNotImplException(_getClassName(), __FUNCTION__);`;

public:
	override {
		IvyDataRange opSlice() {
			mixin(notImplMixin);
		}
		IClassNode opSlice(size_t, size_t) {
			mixin(notImplMixin);
		}
		IvyData opIndex(IvyData) {
			mixin(notImplMixin);
		}
		IvyData __getAttr__(string) {
			mixin(notImplMixin);
		}
		void __setAttr__(IvyData, string) {
			mixin(notImplMixin);
		}
		IvyData __serialize__() {
			mixin(notImplMixin);
		}
		size_t length() @property {
			//mixin(notImplMixin);
			return 0; // Add trivial implementation
		}
	}
}