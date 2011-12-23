/*
 * Copyright (c) 2011 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders
{
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;

	import org.swiftsuspenders.typedescriptions.ConstructorInjectionPoint;
	import org.swiftsuspenders.typedescriptions.MethodInjectionPoint;
	import org.swiftsuspenders.typedescriptions.NoParamsConstructorInjectionPoint;
	import org.swiftsuspenders.typedescriptions.PostConstructInjectionPoint;
	import org.swiftsuspenders.typedescriptions.PreDestroyInjectionPoint;
	import org.swiftsuspenders.typedescriptions.PropertyInjectionPoint;
	import org.swiftsuspenders.typedescriptions.TypeDescription;

	public class DescribeTypeReflector extends ReflectorBase implements Reflector
	{
		//----------------------       Private / Protected Properties       ----------------------//
		private var _currentFactoryXML : XML;

		//----------------------               Public Methods               ----------------------//
		public function typeImplements(type : Class, superType : Class) : Boolean
		{
            if (type == superType)
            {
	            return true;
            }

            var factoryDescription : XML = describeType(type).factory[0];

			return (factoryDescription.children().(
            	name() == "implementsInterface" || name() == "extendsClass").(
            	attribute("type") == getQualifiedClassName(superType)).length() > 0);
		}

		public function describeInjections(type : Class) : TypeDescription
		{
			_currentFactoryXML = describeType(type).factory[0];
			const description : TypeDescription = new TypeDescription();
			addCtorInjectionPoint(description, type);
			addFieldInjectionPoints(description);
			addMethodInjectionPoints(description);
			addPostConstructMethodPoints(description);
			addPreDestroyMethodPoints(description);
			_currentFactoryXML = null;
			return description;
		}

		//----------------------         Private / Protected Methods        ----------------------//
		private function addCtorInjectionPoint(description : TypeDescription, type : Class) : void
		{
			const node : XML = _currentFactoryXML.constructor[0];
			if (!node)
			{
				if (_currentFactoryXML.parent().@name == 'Object'
						|| _currentFactoryXML.extendsClass.length() > 0)
				{
					description.ctor = new NoParamsConstructorInjectionPoint();
				}
				return;
			}
			var nameArgs : XMLList = node.parent().metadata.arg.(@key == 'name');
			/*
			 In many cases, the flash player doesn't give us type information for constructors until
			 the class has been instantiated at least once. Therefore, we do just that if we don't get
			 type information for at least one parameter.
			 */
			if (node.parameter.(@type == '*').length() == node.parameter.@type.length())
			{
				createDummyInstance(node, type);
			}
			const parameters : Array = gatherMethodParameters(node.parameter, nameArgs);
			const requiredParameters : uint = parameters.required;
			delete parameters.required;
			description.ctor = new ConstructorInjectionPoint(parameters, requiredParameters);
		}

		private function addFieldInjectionPoints(description : TypeDescription) : void
		{
			for each (var node : XML in _currentFactoryXML.*.
					(name() == 'variable' || name() == 'accessor').metadata.(@name == 'Inject'))
			{
				var mappingId : String =
						node.parent().@type + '|' + node.arg.(@key == 'name').attribute('value');
				var propertyName : String = node.parent().@name;
				var injectionPoint : PropertyInjectionPoint = new PropertyInjectionPoint(mappingId,
						propertyName, getOptionalFlagFromXMLNode(node));
				description.addInjectionPoint(injectionPoint);
			}
		}

		private function addMethodInjectionPoints(description : TypeDescription) : void
		{
			for each (var node : XML in _currentFactoryXML.method.metadata.(@name == 'Inject'))
			{
				const nameArgs : XMLList = node.arg.(@key == 'name');
				const parameters : Array =
						gatherMethodParameters(node.parent().parameter, nameArgs);
				const requiredParameters : uint = parameters.required;
				delete parameters.required;
				var injectionPoint : MethodInjectionPoint =
						new MethodInjectionPoint(node.parent().@name, parameters,
								requiredParameters, getOptionalFlagFromXMLNode(node));
				description.addInjectionPoint(injectionPoint);
			}
		}

		private function addPostConstructMethodPoints(description : TypeDescription) : void
		{
			var injectionPoints : Array = gatherOrderedInjectionPointsForTag(
				PostConstructInjectionPoint, 'PostConstruct');
			for (var i : int = 0, length : int = injectionPoints.length; i < length; i++)
			{
				description.addInjectionPoint(injectionPoints[i]);
			}
		}

		private function addPreDestroyMethodPoints(description : TypeDescription) : void
		{
			var injectionPoints : Array = gatherOrderedInjectionPointsForTag(
				PreDestroyInjectionPoint, 'PreDestroy');
			if (!injectionPoints.length)
			{
				return;
			}
			description.preDestroyMethods = injectionPoints[0];
			description.preDestroyMethods.last = injectionPoints[0];
			for (var i : int = 1, length : int = injectionPoints.length; i < length; i++)
			{
				description.preDestroyMethods.last.next = injectionPoints[i];
				description.preDestroyMethods.last = injectionPoints[i];
			}
		}

		private function getOptionalFlagFromXMLNode(node : XML) : Boolean
		{
			return node.arg.(@key == 'optional' && @value == 'true').length() != 0;
		}

		private function gatherMethodParameters(
				parameterNodes : XMLList, nameArgs : XMLList) : Array
		{
			var requiredParameters : uint = 0;
			const length : uint = parameterNodes.length();
			const parameters : Array = new Array(length);
			for (var i : int = 0; i < length; i++)
			{
				var parameter : XML = parameterNodes[i];
				var injectionName : String = '';
				if (nameArgs[i])
				{
					injectionName = nameArgs[i].@value;
				}
				var parameterTypeName : String = parameter.@type;
				var optional : Boolean = parameter.@optional == 'true';
				if (parameterTypeName == '*')
				{
					if (!optional)
					{
						//TODO: Find a way to trace name of affected class here
						throw new InjectorError('Error in method definition of injectee. ' +
								'Required parameters can\'t have type "*".');
					}
					else
					{
						parameterTypeName = null;
					}
				}
				if (!optional)
				{
					requiredParameters++;
				}
				parameters[i] = parameterTypeName + '|' + injectionName;
			}
			parameters.required = requiredParameters;
			return parameters;
		}

		private function gatherOrderedInjectionPointsForTag(
				injectionPointType : Class, tag : String) : Array
		{
			const injectionPoints : Array = [];
			for each (var node : XML in
				_currentFactoryXML.method.metadata.(@name == tag))
			{
				var order : Number = parseInt(node.arg.(@key == 'order').@value);
				injectionPoints.push(new injectionPointType(
					node.parent().@name, isNaN(order) ? int.MAX_VALUE : order));
			}
			if (injectionPoints.length > 0)
			{
				injectionPoints.sortOn('order', Array.NUMERIC);
			}
			return injectionPoints;
		}

		private function createDummyInstance(constructorNode : XML, clazz : Class) : void
		{
			try
			{
				switch (constructorNode.children().length())
				{
					case 0 :(new clazz());break;
					case 1 :(new clazz(null));break;
					case 2 :(new clazz(null, null));break;
					case 3 :(new clazz(null, null, null));break;
					case 4 :(new clazz(null, null, null, null));break;
					case 5 :(new clazz(null, null, null, null, null));break;
					case 6 :(new clazz(null, null, null, null, null, null));break;
					case 7 :(new clazz(null, null, null, null, null, null, null));break;
					case 8 :(new clazz(null, null, null, null, null, null, null, null));break;
					case 9 :(new clazz(null, null, null, null, null, null, null, null, null));break;
					case 10 :
						(new clazz(null, null, null, null, null, null, null, null, null, null));
						break;
				}
			}
			catch (error : Error)
			{
				trace('Exception caught while trying to create dummy instance for constructor ' +
						'injection. It\'s almost certainly ok to ignore this exception, but you ' +
						'might want to restructure your constructor to prevent errors from ' +
						'happening. See the Swiftsuspenders documentation for more details. ' +
						'The caught exception was:\n' + error);
			}
			constructorNode.setChildren(describeType(clazz).factory.constructor[0].children());
		}
	}
}