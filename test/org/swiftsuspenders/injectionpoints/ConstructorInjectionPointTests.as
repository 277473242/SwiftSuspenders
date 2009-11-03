package  org.swiftsuspenders.injectionpoints
{
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import org.flexunit.Assert;
	import org.swiftsuspenders.InjectionConfig;
	import org.swiftsuspenders.Injector;
	import org.swiftsuspenders.injectionpoints.ConstructorInjectionPoint;
	import org.swiftsuspenders.support.injectees.TwoParametersConstructorInjectee;
	import org.swiftsuspenders.support.nodes.InjectionNodes;
	import org.swiftsuspenders.support.types.Clazz;
	import org.swiftsuspenders.support.types.Interface;
	
	public class ConstructorInjectionPointTests
	{
		public static const STRING_REFERENCE:String = "stringReference";
		
		[Test]
		public function injectionOfTwoUnnamedPropertiesIntoConstructor():void
		{
			var injectee:TwoParametersConstructorInjectee = applyConstructorInjectionToTwoUnamedParameterInjectee()
			
			Assert.assertTrue("dependency 1 should be Clazz instance", injectee.getDependency() is Clazz);		
			Assert.assertTrue("dependency 2 should be 'stringReference'", injectee.getDependency2() == STRING_REFERENCE);	
		}
		
		private function applyConstructorInjectionToTwoUnamedParameterInjectee():TwoParametersConstructorInjectee
		{
			var injector:Injector = new Injector();
			var injectionPoint:ConstructorInjectionPoint = createTwoPropertySingletonClazzAndInterfaceConstructorInjectionPoint();
			var singletons:Dictionary = new Dictionary();
			var injectee:TwoParametersConstructorInjectee = 
					injectionPoint.applyInjection(TwoParametersConstructorInjectee, injector, singletons) as TwoParametersConstructorInjectee;
			
			return injectee;
		}
		
		private function createTwoPropertySingletonClazzAndInterfaceConstructorInjectionPoint():ConstructorInjectionPoint
		{
			var node:XML = XML(InjectionNodes.CONSTRUCTOR_INJECTION_NODE_TWO_ARGUMENT.constructor);
			var mappings:Dictionary = createUnamedTwoPropertyPropertySingletonInjectionConfigDictionary();
			var injectionPoint:ConstructorInjectionPoint = new ConstructorInjectionPoint(node, mappings, TwoParametersConstructorInjectee);
			return injectionPoint;
		}
		
		private function createUnamedTwoPropertyPropertySingletonInjectionConfigDictionary():Dictionary
		{
			var configDictionary:Dictionary = new Dictionary();
			var config_clazz : InjectionConfig = new InjectionConfig(
				Clazz, Clazz, InjectionConfig.INJECTION_TYPE_SINGLETON, "");
			var string_reference : InjectionConfig = new InjectionConfig(
				String, STRING_REFERENCE, InjectionConfig.INJECTION_TYPE_VALUE, "");
			var fqcn_clazz:String = getQualifiedClassName(Clazz);
			var fqcn_string:String = getQualifiedClassName(String);
			
			configDictionary[fqcn_clazz] = config_clazz;
			configDictionary[fqcn_string] = string_reference;
			
			return configDictionary;
		}
	}
}