(function() {
	function notPrintable() {
		throw "Not Printable!";
	}
	// Only pretty print JavaScript properties that are backed by Objective-C properties or are whitelisted on bridged Objective-C objects
	var whitelistedProperties = ["class", "frame", "bounds", "center", "transform", "alpha", "backgroundColor", "contentStretch", "autoresizingMask", "contentMode", "contentStretch", "hidden", "alpha", "opaque", "clipsToBounds", "clearsContextBeforeDrawing", "multipleTouchEnabled", "exclusiveTouch", "superview", "subviews", "window", "autoresizesSubviews", "translatesAutoresizingMaskIntoConstraints", "constraints", "intrinsicContentSize", "alignmentRectInsets", "viewForBaselineLayout", "hasAmbiguousLayout", "contentScaleFactor", "gestureRecognizers", "tag", "restorationIdentifier"];
	var whitelistedClassProperties = ["superclass", "pointer", "metaMethods", "methods", "properties", "protocols", "layerClass", "requiresConstraintBasedLayout", "areAnimationsEnabled"];
	Instance.prototype.__prettyPrintableOfProperty = function(prop) {
		var propName = prop.match(/^is[A-Z]/) ? prop.substring(2, 3).toLowerCase() + prop.substring(3) : prop;
		var thisClass = object_getClass(this);
		if (class_isMetaClass(thisClass)) {
			if (whitelistedClassProperties.indexOf(propName) != -1) {
				if (propName == "superclass" && class_getName(this) == "NSObject") {
					return null;
				}
				return this[prop];
			}
		} else {
			if (class_getProperty(thisClass, propName) && propName != "pointer") {
				return this[prop];
			}
			if (whitelistedProperties.indexOf(propName) != -1) {
				return this[prop];
			}
		}
		notPrintable();
	};
	// Make instances only show their object name
	Instance.prototype.__prettyPrintable = function() {
		if (class_isMetaClass(object_getClass(this))) {
			return class_getName(this);
		}
		return this.toString();
	};
	// Blacklist some properties and hide all classes
	Object.getPrototypeOf(this).__prettyPrintableOfProperty = function(prop) {
		if (prop == "__prettyPrintableOfProperty" || prop == "_" || prop == "$cy" || prop == "$cyq") {
			notPrintable();
		}
		var result = this[prop];
		if (result instanceof Instance && class_isMetaClass(object_getClass(this))) {
			notPrintable();
		}
		return result;
	}
	// Fix UIAccessibilitySafeCategory__NSObject workaround
	ObjectiveC.classes.__prettyPrintableOfProperty = function(prop) {
		if (prop == "UIAccessibilitySafeCategory__NSObject") {
			return prop;
		}
		return this[prop];
	}
	// Make structs loggable, if possible
	var tempStruct = [new UIView init].frame;
	Object.getPrototypeOf(tempStruct).__prettyPrintable = function() {
		try {
			return JSON.stringify(this);
		} catch (e) {
			return this.toString();
		}
	}
	// Hide extra functions tagged onto structs
	Object.getPrototypeOf(tempStruct).__prettyPrintableOfProperty = function(prop) {
		if (prop == "__prettyPrintable" || prop == "__prettyPrintableOfProperty") {
			notPrintable();
		}
		return this[prop];
	}
})();
