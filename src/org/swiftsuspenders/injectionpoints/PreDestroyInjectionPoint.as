/*
* Copyright (c) 2009-2011 the original author or authors
* 
* Permission is hereby granted to use, modify, and distribute this file 
* in accordance with the terms of the license agreement accompanying it.
*/

package org.swiftsuspenders.injectionpoints
{
	public class PreDestroyInjectionPoint extends OrderedInjectionPoint
	{
		//----------------------               Public Methods               ----------------------//
		public function PreDestroyInjectionPoint(methodName : String, order : int)
		{
			_methodName = methodName;
			_orderValue = order;
		}

	}
}